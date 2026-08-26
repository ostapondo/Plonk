import AppKit
import ApplicationServices

// Puts a newly opened window where it is meant to go.
//
// A zone is a habit: the editor lives on the left, chat lives in the rail. The
// habit survives the window, so the second window of an app that has already
// been put somewhere goes there too, and reopening the app after a restart
// lands it in the same place rather than wherever macOS remembers. A rule is
// the same thing written down, and an empty zone is where a window with
// neither can go; which of the three applies is the delegate's to say.
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
    /// True while a workspace is being launched: the launcher is placing
    /// those windows itself, and a second opinion a third of a second later
    /// would fight it.
    var suspended = false
    var isExcluded: ((NSRunningApplication) -> Bool)?
    /// Whether any of the three placements has anything to say about this
    /// app, answered from config alone so a window of an app nobody has a
    /// rule or habit for costs no round trip into it.
    var wants: ((NSRunningApplication) -> Bool)?

    /// Take the settings as they now stand.
    func apply(_ config: Config) {
        enabled = config.isEnabled(.zones)
            && (config.placeNewWindows || config.autoFillZones || !config.appRules.isEmpty)
    }
    /// Where a window of this app that has just opened should go, given
    /// where it is now: a fraction, the display it belongs on, and the zone
    /// it is when it is one. Nil leaves it where the app put it.
    var placement: ((NSRunningApplication, CGRect) -> NewWindowPlacement.Answer?)?
    /// Called after a new window has been placed, so it can be remembered like
    /// any other move.
    var onPlaced: ((AXUIElement, CGRect, NewWindowPlacement.Answer) -> Void)?
    /// The gap for a screen: that of the set it wears.
    var zoneGap: ((Int) -> CGFloat)?

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
        // .commonModes, not .defaultMode: a notification that arrives during a
        // menu or a window drag would otherwise be held until that ends, long
        // past the moment the new window could still be placed unnoticed.
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        observers[pid] = observer
    }

    private func unwatch(_ pid: pid_t) {
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }

    private func windowAppeared(_ window: AXUIElement) {
        // A window that opened during a launch is the launcher's, however
        // long the launch goes on after it.
        guard enabled, !suspended else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleDelay) { [weak self] in
            self?.place(window)
        }
    }

    private func place(_ window: AXUIElement) {
        // The app first, from config alone; then the window, which costs a
        // round trip into the app per question. Only a window in the ordinary
        // sense: a save panel or a floating palette opens where its app wants
        // it, and belongs in no zone.
        guard enabled, !suspended,
              let app = windows.app(ofWindow: window),
              isExcluded?(app) != true,
              wants?(app) != false,
              WindowAccess.isStandard(window),
              let before = windows.frame(ofWindow: window),
              let target = placement?(app, before) else { return }
        windows.apply(frac: target.frac, toWindow: window, screenIndex: target.screen,
                      gap: zoneGap?(target.screen) ?? 0)
        onPlaced?(window, before, target)
    }
}
