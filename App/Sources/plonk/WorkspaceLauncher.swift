import AppKit

// Launches the apps a workspace is missing, then waits for their windows before
// placing them. Waiting polls another process over AX, which must never happen
// on the main thread, so everything after the launch call runs on `queue`.

struct LaunchStatus: Identifiable {
    enum State: Equatable {
        case pending
        case launching
        case waiting
        case placed
        case skipped(String)
        case failed(String)
    }

    let id: Int
    let app: String
    let bundlePath: String?
    var state: State = .pending

    var isFailure: Bool {
        if case .failed = state { return true }
        return false
    }

    var isSettled: Bool {
        switch state {
        case .pending, .launching, .waiting: return false
        case .placed, .skipped, .failed: return true
        }
    }

    var asDict: [String: Any] {
        var result: [String: Any] = ["app": app]
        switch state {
        case .placed:
            result["ok"] = true
        case .skipped(let why):
            result["ok"] = true
            result["skipped"] = why
        case .failed(let why):
            result["ok"] = false
            result["error"] = why
        case .pending, .launching, .waiting:
            result["ok"] = false
            result["error"] = "launch did not finish"
        }
        return result
    }
}

final class WorkspaceLauncher {
    private static let windowTimeout: TimeInterval = 20
    private static let pollInterval: TimeInterval = 0.3

    private let windows: WindowManager
    private let queue = DispatchQueue(label: "app.plonk.workspace-launch")
    /// Launch callbacks land on the main queue, the waiting loop on `queue`.
    private let lock = NSLock()

    private var statuses: [LaunchStatus] = []
    private var cancelled = false
    private var running = false
    private var screenOverride: Int?
    /// Reopened once each, so a stubborn app is not relaunched in a loop.
    private var nudged: Set<String> = []

    var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return running
    }

    /// Both fire on the main queue.
    var onProgress: ((String, [LaunchStatus]) -> Void)?
    var onFinished: ((String, [LaunchStatus]) -> Void)?

    init(windows: WindowManager) {
        self.windows = windows
    }

    // MARK: - Launching

    /// Call on the main queue. `completion` reports one entry per item.
    /// Items go back to the display they were captured on; `screen` overrides
    /// that and pulls the whole workspace onto one monitor.
    func launch(_ workspace: Workspace, named name: String, onScreen screen: Int? = nil,
                completion: (([[String: Any]]) -> Void)? = nil) {
        guard !workspace.items.isEmpty else {
            completion?([["ok": false, "error": "workspace \"\(name)\" has no windows"]])
            return
        }
        lock.lock()
        guard !running else {
            lock.unlock()
            completion?([["ok": false, "error": "another workspace is still launching"]])
            return
        }
        running = true
        cancelled = false
        nudged = []
        screenOverride = screen
        statuses = workspace.items.enumerated().map { index, item in
            LaunchStatus(id: index, app: item.app, bundlePath: item.bundlePath)
        }
        let initial = statuses
        lock.unlock()
        onProgress?(name, initial)

        for group in WorkspacePlan.groups(for: workspace) {
            start(group, moveExisting: workspace.moveExisting, workspace: name)
        }
        waitAndPlace(workspace, named: name, completion: completion)
    }

    /// Ignored when nothing is launching, so a stale panel cannot cancel the
    /// next run.
    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        // `running`, not `isRunning`: NSLock is not recursive.
        if running { cancelled = true }
    }

    private func start(_ group: LaunchGroup, moveExisting: Bool, workspace: String) {
        if windows.findApp(bundleID: group.bundleID, named: group.app) != nil {
            guard moveExisting else {
                set(group.itemIndices, to: .skipped("already open"), workspace: workspace)
                return
            }
            // Its windows are moved as they are: opening the saved files again
            // would spawn windows the workspace has no position for.
            set(group.itemIndices, to: .waiting, workspace: workspace)
            return
        }
        guard let url = applicationURL(for: group) else {
            set(group.itemIndices, to: .failed("\(group.app) is not installed"), workspace: workspace)
            return
        }
        set(group.itemIndices, to: .launching, workspace: workspace)

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        if !group.args.isEmpty { configuration.arguments = group.args }

        let handler: (NSRunningApplication?, Error?) -> Void = { [weak self] _, error in
            guard let self else { return }
            DispatchQueue.main.async {
                if let error {
                    self.set(group.itemIndices, to: .failed(error.localizedDescription), workspace: workspace)
                } else {
                    self.set(group.itemIndices, to: .waiting, workspace: workspace)
                }
            }
        }

        let documents = group.urls.compactMap(Self.fileOrWebURL)
        if documents.isEmpty {
            NSWorkspace.shared.openApplication(at: url, configuration: configuration, completionHandler: handler)
        } else {
            NSWorkspace.shared.open(documents, withApplicationAt: url,
                                    configuration: configuration, completionHandler: handler)
        }
    }

    private func applicationURL(for group: LaunchGroup) -> URL? {
        if let path = group.bundlePath, FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        if let bundleID = group.bundleID,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return url
        }
        return nil
    }

    /// Tildes and bare paths are common in a hand-edited config, so both are
    /// accepted alongside real URLs.
    static func fileOrWebURL(_ string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
            return URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
        }
        guard let url = URL(string: trimmed), url.scheme != nil else { return nil }
        return url
    }

    // MARK: - Waiting

    private func waitAndPlace(_ workspace: Workspace, named name: String,
                              completion: (([[String: Any]]) -> Void)?) {
        let deadline = Date().addingTimeInterval(Self.windowTimeout)
        queue.async { [weak self] in
            guard let self else { return }
            while true {
                let unsettled = self.pass(workspace, named: name)
                if unsettled.isEmpty { break }
                if self.isCancelled {
                    self.set(unsettled, to: .failed("cancelled"), workspace: name)
                    break
                }
                if Date() >= deadline {
                    self.set(unsettled, to: .failed("no window appeared within \(Int(Self.windowTimeout))s"),
                             workspace: name)
                    break
                }
                Thread.sleep(forTimeInterval: Self.pollInterval)
            }
            let final = self.snapshot()
            self.lock.lock()
            self.running = false
            self.lock.unlock()
            DispatchQueue.main.async {
                self.onFinished?(name, final)
                completion?(final.map(\.asDict))
            }
        }
    }

    /// One sweep over everything still unplaced. Returns what is still pending.
    private func pass(_ workspace: Workspace, named name: String) -> [Int] {
        var remaining: [Int] = []
        let current = snapshot()
        lock.lock()
        let override = screenOverride
        lock.unlock()
        for (index, item) in workspace.items.enumerated() {
            guard current.indices.contains(index), !current[index].isSettled else { continue }
            guard current[index].state != .launching else {
                remaining.append(index)
                continue
            }
            let needed = (item.windowIndex ?? 0) + 1
            guard windows.windowCount(bundleID: item.bundleID, named: item.app) >= needed else {
                nudge(item)
                remaining.append(index)
                continue
            }
            let error = windows.place(
                app: item.app,
                bundleID: item.bundleID,
                titleContains: item.title,
                windowIndex: item.windowIndex,
                screen: override ?? Self.screenIndex(for: item),
                frac: FracRect(item.x, item.y, item.w, item.h),
                minimize: item.minimized ?? false,
                activate: false
            )
            set([index], to: error.map { .failed($0) } ?? .placed, workspace: name)
        }
        return remaining
    }

    /// An app can sit in the Dock with every window closed, and then no amount
    /// of waiting produces one. Opening it again is what a Dock click does.
    private func nudge(_ item: WorkspaceItem) {
        guard let app = windows.findApp(bundleID: item.bundleID, named: item.app),
              let url = app.bundleURL else { return }
        lock.lock()
        let alreadyNudged = !nudged.insert(item.launchKey).inserted
        lock.unlock()
        guard !alreadyNudged else { return }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        DispatchQueue.main.async {
            NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        }
    }

    /// The display UUID wins: indices shift when a monitor is unplugged. A saved
    /// index for a display that is gone yields nil, leaving the window where it is.
    static func screenIndex(for item: WorkspaceItem) -> Int? {
        if let uuid = item.screenUUID, let index = ScreenIdentity.index(forUUID: uuid) { return index }
        guard let screen = item.screen, NSScreen.screens.indices.contains(screen) else { return nil }
        return screen
    }

    // MARK: - Status

    private var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    private func snapshot() -> [LaunchStatus] {
        lock.lock()
        defer { lock.unlock() }
        return statuses
    }

    private func set(_ indices: [Int], to state: LaunchStatus.State, workspace: String) {
        lock.lock()
        for index in indices where statuses.indices.contains(index) {
            guard !statuses[index].isSettled else { continue }
            statuses[index].state = state
        }
        let updated = statuses
        lock.unlock()

        if Thread.isMainThread {
            onProgress?(workspace, updated)
        } else {
            DispatchQueue.main.async { self.onProgress?(workspace, updated) }
        }
    }
}
