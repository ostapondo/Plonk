import AppKit
import ApplicationServices

// Puts a newly opened window where that app's windows keep going.
//
// A zone is a habit: the editor lives on the left, chat lives in the rail. The
// habit survives the window, so the second window of an app that has already
// been put somewhere goes there too, and reopening the app after a restart
// lands it in the same place rather than wherever macOS remembers.
//
// AX has no system-wide "a window appeared" notification, so an observer is
// attached per application — added when an app launches, dropped when it
// quits. Each observer costs one Mach port and nothing while idle.

final class NewWindowWatcher {
    /// A window is asked about once, shortly after it appears: apps commonly
    /// create a window and then size it themselves a beat later, and placing
    /// into that race just loses.
    private static let settleDelay: TimeInterval = 0.35

    private let windows: WindowManager
    private var observers: [pid_t: AXObserver] = [:]
    private var workspaceTokens: [NSObjectProtocol] = []

    var enabled = false
    var isExcluded: ((NSRunningApplication) -> Bool)?
    /// Where this app's windows have been going, if anywhere: a fraction and
    /// the display it was on.
    var placement: ((NSRunningApplication) -> (frac: FracRect, screenIndex: Int)?)?
    /// Called after a new window has been placed, so it can be remembered like
    /// any other move.
    var onPlaced: ((NSRunningApplication, AXUIElement, CGRect, FracRect, Int) -> Void)?
    var zoneGap: (() -> CGFloat)?

    init(windows: WindowManager) {
        self.windows = windows
    }

    /// Safe to call again: watching an app twice is a no-op, and a second call
    /// is how apps that were already running pick up an observer once
    /// Accessibility is finally granted.
    func start() {
        guard workspaceTokens.isEmpty else {
            attachToRunningApps()
            return
        }
        let center = NSWorkspace.shared.notificationCenter
        workspaceTokens.append(center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.watch(app)
        })
        workspaceTokens.append(center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.unwatch(app.processIdentifier)
        })
        attachToRunningApps()
    }

    private func attachToRunningApps() {
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            watch(app)
        }
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceTokens.forEach(center.removeObserver)
        workspaceTokens = []
        observers.keys.forEach(unwatch)
    }

    // MARK: - Observers

    private func watch(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard app.activationPolicy == .regular, observers[pid] == nil, windows.isTrusted,
              pid != ProcessInfo.processInfo.processIdentifier else { return }

        var observer: AXObserver?
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard AXObserverCreate(pid, { _, element, _, context in
            guard let context else { return }
            Unmanaged<NewWindowWatcher>.fromOpaque(context).takeUnretainedValue().windowAppeared(element)
        }, &observer) == .success, let observer else { return }

        let element = AXUIElementCreateApplication(pid)
        guard AXObserverAddNotification(observer, element, kAXWindowCreatedNotification as CFString,
                                        context) == .success else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        observers[pid] = observer
    }

    private func unwatch(_ pid: pid_t) {
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
    }

    private func windowAppeared(_ window: AXUIElement) {
        guard enabled else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleDelay) { [weak self] in
            self?.place(window)
        }
    }

    private func place(_ window: AXUIElement) {
        guard enabled,
              let app = windows.app(ofWindow: window),
              isExcluded?(app) != true,
              let before = windows.frame(ofWindow: window),
              let target = placement?(app) else { return }
        windows.apply(frac: target.frac, toWindow: window, screenIndex: target.screenIndex,
                      gap: zoneGap?() ?? 0)
        onPlaced?(app, window, before, target.frac, target.screenIndex)
    }
}
