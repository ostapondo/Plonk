import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let issuesURL = "https://github.com/ostapondo/plonk/issues/new"

    // Split across the AppDelegate+* files, one per module, so nothing here is
    // private: Swift only lets an extension in the same file see that. What is
    // listed here is the whole of what the app is made of.
    let store = ConfigStore()
    let windows = WindowManager()
    let awake = AwakeManager()
    let lidSleep = LidSleep()
    let agents = AgentRegistry()
    let eventBroadcaster = EventBroadcaster()
    let voice = VoiceManager()
    let hotkeys = HotkeyManager()
    let updates = UpdateManager()
    let model = AppModel()
    let snapMemory = SnapMemory()
    lazy var desk = DeskWatcher(windows: windows)
    lazy var commands = WindowCommands(windows: windows, memory: snapMemory)
    lazy var launcher = WorkspaceLauncher(windows: windows)
    lazy var presenter = WindowPresenter(model: model)
    var statusMenu: StatusMenuController!
    var dragSnap: DragSnapManager!
    var grabMove: GrabMove!
    var newWindows: NewWindowWatcher!
    /// The window being placed right now, so the empty-zone search can leave
    /// it out; see AppDelegate+NewWindows.
    var placing: (pid: pid_t, frame: CGRect)?
    let mouse = MouseTools()
    let crops = CropAndLock()
    let screenTags = ScreenTags()
    var guidePanel: ShortcutGuidePanel?
    var guideLoading = false
    /// How many captures are in flight; see hideOwnWindows.
    var captureDepth = 0
    var router: Router!
    var server: ControlServer?
    var previewToken = 0
    var screenSettleWork: DispatchWorkItem?
    /// Display UUIDs seen at the last screen-parameter change, so a Dock
    /// resize can be told apart from a monitor being plugged in.
    var knownDisplays: Set<String> = []
    /// What applyConfig last handed out, so the few settings whose apply
    /// costs a round trip to macOS run only when they moved.
    var appliedConfig: Config?
    var applyingConfig = false
    var configApplyPending = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Before anything is on screen: a second copy would add its own menu bar
        // icon and hotkeys, and lose the race for the control server's port.
        if let existing = Self.otherRunningInstance() {
            existing.activate()
            NSApp.terminate(nil)
            return
        }
        store.load()
        applyAppearance()
        windows.promptForTrust()

        model.actions = self
        setupCommands()
        setupPresenter()
        setupStatusMenu()
        setupAwake()
        setupLidSleep()
        setupLauncher()
        setupHotkeys()
        setupVoice()
        setupDragSnap()
        setupGrabMove()
        setupNewWindows()
        setupRuler()
        setupServer()
        setupDesk()
        setupUpdates()
        watchConfig()
        refreshModel()

        knownDisplays = ScreenIdentity.attachedDisplays()
        watchForAccessibility()
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
    }

    /// Another copy of this bundle, if one is already up. Nil when running
    /// unbundled through `swift run`, where there is no identifier to match on;
    /// the control server's port check is the backstop there.
    static func otherRunningInstance() -> NSRunningApplication? {
        guard let id = Bundle.main.bundleIdentifier else { return nil }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .first { $0.processIdentifier != ownPID && !$0.isTerminated }
    }
}
