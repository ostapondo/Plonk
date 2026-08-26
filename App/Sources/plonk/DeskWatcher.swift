import AppKit
import ApplicationServices

// Notes where every window sits and puts the desk back when a set of displays
// that has been seen before is attached again. The noting is one AX walk at a
// time on its own queue, and only when the window server says something has
// moved since the last note: AX blocks on every app it asks, so the cheap
// question is asked every tick and the expensive one seldom. Putting back is
// in DeskWatcher+Restore.

final class DeskWatcher {
    /// How often the desk is checked while nothing is happening, and how soon
    /// after a placement. A check is one call to the window server; a walk
    /// only follows when the answer has changed.
    static let interval: TimeInterval = 30
    static let afterPlacement: TimeInterval = 3

    let windows: WindowManager
    let memory = DeskMemory()
    /// Walks and restores each run in order on a queue of their own: a
    /// restore must not wait behind a walk a display change has made stale.
    private let walkQueue = DispatchQueue(label: "app.plonk.desk.walk")
    let restoreQueue = DispatchQueue(label: "app.plonk.desk.restore")
    private var timer: Timer?
    /// Bumped by every display change and by switching off, so work that
    /// began before either records or moves nothing. A restore reads it
    /// between moves, off the main queue, hence the lock.
    private let lock = NSLock()
    private var counter = 0
    /// What the window server last said about each desk, so an unchanged
    /// desk is not walked again.
    private var signatures: [Set<String>: Int] = [:]
    private var walking = false
    private var walkAgain = false
    /// True from a display coming or going until its windows have been put
    /// back, so nothing notes the desk while it is scrambled.
    var settling = false
    private(set) var enabled = false

    /// Apps the user told Plonk to keep its hands off.
    var isExcluded: ((NSRunningApplication) -> Bool)?

    init(windows: WindowManager) {
        self.windows = windows
    }

    deinit {
        timer?.invalidate()
    }

    var generation: Int {
        lock.withLock { counter }
    }

    private func advance() {
        lock.withLock { counter += 1 }
    }

    /// Take the settings as they now stand. Off means the timer stops and
    /// the desks are forgotten, so switching back on starts clean; a walk
    /// still out when that happens lands on nothing.
    func apply(_ config: Config) {
        let on = config.restoresDeskOnScreenChange
        guard on != enabled else { return }
        enabled = on
        if on {
            let timer = Timer.common(every: Self.interval) { [weak self] in self?.snapshot() }
            timer.tolerance = 5
            self.timer = timer
            snapshot()
        } else {
            timer?.invalidate()
            timer = nil
            advance()
            signatures = [:]
            memory.clear()
        }
    }

    /// A display came or went: whatever is mid-walk or mid-restore is stale,
    /// and nothing is noted until the windows have been put back.
    func displaysChanged() {
        advance()
        settling = true
    }

    /// The next check soon rather than at the next tick; several placements
    /// in a row are one check.
    func scheduleSnapshot() {
        timer?.fireDate = Date(timeIntervalSinceNow: Self.afterPlacement)
    }

    /// A window Plonk has just put somewhere is noted at once, against the
    /// displays attached now, so a display change in the next few seconds
    /// finds the desk already current for it.
    func placed(_ window: AXUIElement, at frame: CGRect) {
        guard enabled, !settling,
              let entry = Self.entries(of: [(window, frame)], screens: Self.identified(windows.screens())).first
        else { return }
        memory.note(entry, for: ScreenIdentity.attachedDisplays())
        scheduleSnapshot()
    }

    /// Notes where every window is, if anything has moved since the last
    /// note and the desk is not mid-change. Everything the walk needs from
    /// the settings and the screens is read here, on the main queue; the
    /// walk itself only asks the apps. Its result lands back here, against
    /// the displays that were attached when it started, or not at all.
    func snapshot() {
        guard enabled, windows.isTrusted, !settling else { return }
        let displays = ScreenIdentity.attachedDisplays()
        guard !displays.isEmpty else { return }
        if walking {
            walkAgain = true
            return
        }
        let signature = DeskSignature.current()
        guard signature != signatures[displays] else { return }
        let generation = self.generation
        let screens = Self.identified(windows.screens())
        let excluded = isExcluded ?? { _ in false }
        let apps = windows.runningApps().filter { !excluded($0) }
        // An app excluded since it was noted, or quit, drops out here; the
        // walk asks nothing of either.
        let known = memory.entries(for: displays).filter { entry in
            windows.app(ofWindow: entry.window).map { !excluded($0) } ?? false
        }
        walking = true
        walkQueue.async { [weak self] in
            guard let self else { return }
            let seen = windows.allWindows(of: apps).map { (window: $0.window, frame: $0.frame) }
            let merged = DeskMemory.merged(known, with: Self.entries(of: seen, screens: screens)) {
                !WindowAccess.isGone($0)
            }
            DispatchQueue.main.async {
                self.walking = false
                defer {
                    if self.walkAgain {
                        self.walkAgain = false
                        self.scheduleSnapshot()
                    }
                }
                // The live set as well as the generation: the window server
                // can have scrambled the desk before the notification saying
                // so has reached the main queue.
                guard self.enabled, !self.settling, self.generation == generation,
                      ScreenIdentity.attachedDisplays() == displays else { return }
                self.memory.record(merged, for: displays)
                self.signatures[displays] = signature
            }
        }
    }
}
