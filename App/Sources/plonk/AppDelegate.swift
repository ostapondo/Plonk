import AppKit
import CoreGraphics
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let issuesURL = "https://github.com/ostapondo/plonk/issues/new"

    private let store = ConfigStore()
    private let windows = WindowManager()
    private let awake = AwakeManager()
    private let hotkeys = HotkeyManager()
    private let model = AppModel()
    private lazy var launcher = WorkspaceLauncher(windows: windows)
    private lazy var presenter = WindowPresenter(model: model)
    private var statusMenu: StatusMenuController!
    private var dragSnap: DragSnapManager!
    private var router: Router!
    private var server: ControlServer?
    private var previewToken = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.load()
        windows.promptForTrust()

        model.actions = self
        setupPresenter()
        setupStatusMenu()
        setupAwake()
        setupLauncher()
        setupHotkeys()
        setupDragSnap()
        setupServer()
        refreshModel()

        applyLaunchAtLogin(store.config.launchAtLogin)
        model.launchAtLogin = isLaunchAtLoginEnabled

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
    }

    // MARK: - Wiring

    private func setupPresenter() {
        presenter.shotFolder = { [weak self] in self?.store.config.shotFolder ?? "~/Desktop" }
        presenter.onShotFinished = { [weak self] copied, path in self?.finishShot(copied: copied, path: path) }
        presenter.onCancelWorkspaceLaunch = { [weak self] in self?.launcher.cancel() }
        presenter.onZonePickerClosed = { [weak self] in self?.clearPreview() }
        presenter.onFullscreenEditorClosed = { [weak self] in self?.clearPreview() }
    }

    private func setupStatusMenu() {
        statusMenu = StatusMenuController()
        statusMenu.isAwakeRequested = { [weak self] in self?.awake.requested ?? false }
        statusMenu.onOpenWindow = { [weak self] in self?.openMainWindow() }
        statusMenu.onCaptureRegion = { [weak self] in self?.runCapture(.region, openEditor: true) }
        statusMenu.onToggleAwake = { [weak self] in self?.awake.toggle() }
        statusMenu.onLaunchWorkspace = { [weak self] name in self?.launchWorkspace(named: name, onScreen: nil) }
        statusMenu.onReportBug = { [weak self] in self?.reportBug() }
        refreshStatusMenu()
    }

    private func setupAwake() {
        awake.allowOnBattery = store.config.awakeAllowOnBattery
        awake.autoWhileCharging = store.config.awakeAutoWhileCharging
        awake.keepDisplayOn = store.config.awakeKeepDisplayOn
        awake.timeoutMinutes = store.config.awakeTimeoutMinutes
        awake.onChange = { [weak self] in
            guard let self else { return }
            model.awakeOn = awake.isOn
            model.awakeRequested = awake.requested
            refreshStatusMenu()
            persistAwakeSession()
        }
        awake.startObservingPowerSource()
        if store.config.awakeRequested {
            awake.restore(sessionEnd: store.config.awakeSessionEnd.map(Date.init(timeIntervalSince1970:)))
        }
        awake.reevaluate()
    }

    private func setupLauncher() {
        launcher.onProgress = { [weak self] name, statuses in
            guard let self else { return }
            model.launchingWorkspace = name
            model.launchStatuses = statuses
            presenter.showWorkspaceLaunch()
        }
        launcher.onFinished = { [weak self] _, statuses in
            guard let self else { return }
            model.launchStatuses = statuses
            model.launchingWorkspace = nil
            // Anything that failed stays up until the user has read it.
            guard statuses.allSatisfy({ $0.state != .pending && !$0.isFailure }) else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                guard self?.model.launchingWorkspace == nil else { return }
                self?.presenter.closeWorkspaceLaunch()
            }
        }
    }

    private func setupHotkeys() {
        hotkeys.onAction = { [weak self] action in self?.perform(action) }
        hotkeys.bindings = store.config.resolvedHotkeys
        if store.config.hotkeysEnabled { hotkeys.setEnabled(true) }
        refreshHotkeyModel()
    }

    private func perform(_ action: HotkeyAction) {
        switch action {
        case .showZones:
            dragSnap.previewZones()
        case .captureRegion:
            runCapture(.region, openEditor: true)
        default:
            guard let preset = action.preset else { return }
            windows.applyPreset(preset, to: NSWorkspace.shared.frontmostApplication)
        }
    }

    private func refreshHotkeyModel() {
        let bindings = store.config.resolvedHotkeys
        model.hotkeyDisplays = HotkeyAction.allCases.reduce(into: [:]) { result, action in
            result[action.rawValue] = bindings[action]?.display ?? "None"
        }
        model.hotkeyParts = HotkeyAction.allCases.reduce(into: [:]) { result, action in
            result[action.rawValue] = bindings[action]?.parts ?? []
        }
        model.unavailableHotkeys = hotkeys.unavailable.map(\.rawValue)
    }

    private func setupDragSnap() {
        dragSnap = DragSnapManager(windows: windows)
        dragSnap.enabled = store.config.dragSnapEnabled
        dragSnap.requireModifier = store.config.zonesRequireShift
        dragSnap.modifierFlag = Self.modifierFlag(store.config.zonesModifier)
        dragSnap.zonesForScreen = { [weak self] index in
            guard let self else { return [] }
            return store.config.zones(forKeys: ScreenIdentity.keys(forIndex: index))
        }
        dragSnap.start()
    }

    private func setupServer() {
        router = Router(store: store, windows: windows, awake: awake)
        router.didChangeLayouts = { [weak self] in self?.refreshWorkspaceModel() }
        router.didChangeZones = { [weak self] in
            self?.refreshZoneModel()
            self?.dragSnap.previewZones()
        }
        router.didSaveShot = { [weak self] path in self?.model.shotStatus = "Saved to \(path)" }
        router.announce = { text, path in
            HUD.shared.show(text, image: path.flatMap { NSImage(contentsOfFile: $0) })
        }
        router.capture = { [weak self] mode, annotate, done in
            guard let self else { return done(nil) }
            runCapture(mode, openEditor: annotate, completion: done)
        }
        router.launchWorkspace = { [weak self] name, workspace, screen, done in
            guard let self else { return done([["ok": false, "error": "shutting down"]]) }
            launcher.launch(workspace, named: name, onScreen: screen, completion: done)
        }

        let server = ControlServer { [weak self] request, respond in
            guard let self else { return respond(.failed("shutting down")) }
            router.handle(request, respond: respond)
        }
        server.onUnavailable = { [weak self] message in self?.model.apiWarning = message }
        do {
            try server.start()
        } catch {
            NSLog("Plonk: failed to start control server: \(error)")
            model.apiWarning = "The local API could not start, so the MCP tools cannot reach this app."
        }
        self.server = server
    }

    /// Keep-awake is a user decision, not a session detail, so it has to
    /// outlive a relaunch. Written only when it actually changed, since
    /// onChange also fires on every power-source event.
    private func persistAwakeSession() {
        let end = awake.sessionEnd?.timeIntervalSince1970
        guard store.config.awakeRequested != awake.requested || store.config.awakeSessionEnd != end else { return }
        store.update {
            $0.awakeRequested = awake.requested
            $0.awakeSessionEnd = end
        }
    }

    // MARK: - Model

    /// Bundle version; empty when running unbundled through `swift run`.
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    private func refreshModel() {
        model.appVersion = appVersion
        model.configWarning = store.loadFailure
        refreshPermissions()
        model.awakeOn = awake.isOn
        model.awakeRequested = awake.requested
        model.awakeAllowOnBattery = store.config.awakeAllowOnBattery
        model.awakeAutoWhileCharging = store.config.awakeAutoWhileCharging
        model.awakeKeepDisplayOn = store.config.awakeKeepDisplayOn
        model.awakeTimeoutMinutes = store.config.awakeTimeoutMinutes
        model.hotkeysEnabled = store.config.hotkeysEnabled
        model.dragSnapEnabled = store.config.dragSnapEnabled
        model.shotFolder = store.config.shotFolder
        model.shotCopyToClipboard = store.config.shotCopyToClipboard
        model.settingsPages = [
            SettingsPage(id: "home", title: "Home", icon: "house") { AnyView(HomePage(model: $0)) },
            SettingsPage(id: "shortcuts", title: "Shortcuts", icon: "keyboard") { AnyView(ShortcutsPage(model: $0)) },
            SettingsPage(id: "workspaces", title: "Workspaces", icon: "rectangle.3.group", section: "Windows") { AnyView(WorkspacesPage(model: $0)) },
            SettingsPage(id: "zones", title: "Zones", icon: "square.grid.2x2", section: "Windows") { AnyView(ZonesPage(model: $0)) },
            SettingsPage(id: "awake", title: "Keep Awake", icon: "cup.and.saucer", section: "Gadgets") { AnyView(AwakePage(model: $0)) },
            SettingsPage(id: "shot", title: "Screenshot", icon: "camera.viewfinder", section: "Gadgets") { AnyView(ShotPage(model: $0)) },
            SettingsPage(id: "ai", title: "AI · MCP", icon: "sparkles", section: "Setup") { _ in AnyView(AIPage()) },
        ]
        refreshWorkspaceModel()
        refreshZoneModel()
        refreshHotkeyModel()
    }

    /// Preflight does not prompt, so it is safe to poll whenever a window opens.
    private func refreshPermissions() {
        model.accessibilityGranted = windows.isTrusted
        model.screenRecordingGranted = CGPreflightScreenCaptureAccess()
    }

    private func refreshWorkspaceModel() {
        model.workspaces = store.config.workspaces
        model.workspaceNames = store.config.workspaces.keys.sorted()
        statusMenu.workspaceNames = model.workspaceNames
    }

    private func refreshZoneModel() {
        let custom = store.config.zoneSets.keys.sorted()
        model.customZoneSetNames = custom
        model.zoneSetNames = custom + BuiltinZoneSets.all.keys.sorted().filter { !custom.contains($0) }
        model.zoneSets = BuiltinZoneSets.all.merging(store.config.zoneSets) { _, user in user }
        model.screenCount = NSScreen.screens.count
        model.screenDescriptions = NSScreen.screens.map { "\(Int($0.frame.width)) × \(Int($0.frame.height))" }
        model.screenAssignments = NSScreen.screens.indices.reduce(into: [:]) { result, index in
            result[index] = store.config.zoneAssignment(forKeys: ScreenIdentity.keys(forIndex: index))
        }
        model.zonesRequireModifier = store.config.zonesRequireShift
        model.zonesModifier = store.config.zonesModifier
    }

    private func refreshStatusMenu() {
        statusMenu.refresh(
            icon: awake.isOn ? StatusIcon.awake : StatusIcon.idle,
            tooltip: "Plonk — keep-awake: \(awake.statusText)",
            dimmed: awake.requested && !awake.isOn
        )
    }

    private func clearPreview() {
        dragSnap.hidePreviews()
        model.previewedZoneSet = nil
    }

    @objc private func screensChanged() {
        dragSnap.screensChanged()
        model.previewedZoneSet = nil
        refreshZoneModel()
    }

    private static func modifierFlag(_ name: String) -> NSEvent.ModifierFlags {
        switch name {
        case "option": return .option
        case "control": return .control
        default: return .shift
        }
    }

    // MARK: - Launch at login

    private var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registers the app bundle as a login item. Fails silently when the app
    /// runs unbundled (swift run), where there is nothing to register.
    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Plonk: login item update failed: \(error)")
        }
    }

    // MARK: - Screenshot

    private func runCapture(_ mode: CaptureMode, openEditor: Bool,
                            completion: @escaping (NSImage?) -> Void = { _ in }) {
        // Hide our own windows so they do not end up in the shot.
        let hidden = presenter.visible
        hidden.forEach { $0.orderOut(nil) }
        ScreenshotManager.capture(mode) { [weak self] image in
            hidden.forEach { $0.orderFront(nil) }
            if let image, openEditor { self?.presenter.showShotEditor(image: image) }
            completion(image)
        }
    }

    private func finishShot(copied: Bool, path: String?) {
        if let path, store.config.shotCopyToClipboard, !copied,
           let saved = NSImage(contentsOfFile: path) {
            ScreenshotManager.copyToClipboard(saved)
        }
        model.shotStatus = path.map { "Saved to \($0)" } ?? "Copied to clipboard"
    }

    private func openMainWindow() {
        refreshPermissions()
        presenter.showMainWindow()
    }
}

// MARK: - AppActions

extension AppDelegate: AppActions {

    func setAwake(_ on: Bool) { awake.set(on) }

    func setAwakeAllowOnBattery(_ on: Bool) {
        store.update { $0.awakeAllowOnBattery = on }
        model.awakeAllowOnBattery = on
        awake.allowOnBattery = on
    }

    func setAwakeAutoWhileCharging(_ on: Bool) {
        store.update { $0.awakeAutoWhileCharging = on }
        model.awakeAutoWhileCharging = on
        awake.autoWhileCharging = on
    }

    func setAwakeKeepDisplayOn(_ on: Bool) {
        store.update { $0.awakeKeepDisplayOn = on }
        model.awakeKeepDisplayOn = on
        awake.keepDisplayOn = on
    }

    func setAwakeTimeout(minutes: Int) {
        store.update { $0.awakeTimeoutMinutes = minutes }
        model.awakeTimeoutMinutes = minutes
        awake.timeoutMinutes = minutes
    }

    func setHotkeys(_ on: Bool) {
        hotkeys.setEnabled(on)
        store.update { $0.hotkeysEnabled = on }
        model.hotkeysEnabled = on
        refreshHotkeyModel()
    }

    func setHotkey(_ action: HotkeyAction, to hotkey: Hotkey) {
        // A combination can only drive one action, so taking it frees it
        // wherever it was, possibly on a page the user is not looking at.
        let stolen = HotkeyAction.allCases.filter {
            $0 != action && store.config.resolvedHotkeys[$0] == hotkey
        }
        store.update { config in
            for other in stolen { config.hotkeys[other.rawValue] = "" }
            config.hotkeys[action.rawValue] = hotkey.spec
        }
        if let taken = stolen.first {
            HUD.shared.show("\(hotkey.display) taken from \(taken.title)")
        }
        hotkeys.bindings = store.config.resolvedHotkeys
        refreshHotkeyModel()
    }

    func clearHotkey(_ action: HotkeyAction) {
        store.update { $0.hotkeys[action.rawValue] = "" }
        hotkeys.bindings = store.config.resolvedHotkeys
        refreshHotkeyModel()
    }

    func resetHotkeys() {
        store.update { $0.hotkeys = [:] }
        hotkeys.bindings = store.config.resolvedHotkeys
        refreshHotkeyModel()
    }

    func setDragSnap(_ on: Bool) {
        dragSnap.enabled = on
        store.update { $0.dragSnapEnabled = on }
        model.dragSnapEnabled = on
    }

    func setZonesRequireModifier(_ on: Bool) {
        dragSnap.requireModifier = on
        store.update { $0.zonesRequireShift = on }
        model.zonesRequireModifier = on
    }

    func setZonesModifier(_ name: String) {
        dragSnap.modifierFlag = Self.modifierFlag(name)
        store.update { $0.zonesModifier = name }
        model.zonesModifier = name
    }

    func setLaunchAtLogin(_ on: Bool) {
        applyLaunchAtLogin(on)
        store.update { $0.launchAtLogin = on }
        model.launchAtLogin = isLaunchAtLoginEnabled
    }

    func setShotFolder(_ folder: String) {
        store.update { $0.shotFolder = folder }
        model.shotFolder = folder
    }

    func setShotCopyToClipboard(_ on: Bool) {
        store.update { $0.shotCopyToClipboard = on }
        model.shotCopyToClipboard = on
    }

    func capture(_ mode: CaptureMode) {
        runCapture(mode, openEditor: true)
    }

    func flashZones() {
        dragSnap.previewZones()
    }

    func reportBug() {
        guard let url = URL(string: Self.issuesURL) else { return }
        NSWorkspace.shared.open(url)
    }

    func assignZoneSet(_ name: String?, toScreen index: Int) {
        store.update { $0.assignZoneSet(name, forKeys: ScreenIdentity.keys(forIndex: index)) }
        refreshZoneModel()
    }

    func updateZoneSet(_ name: String, zones: [ZoneRect]) {
        store.update { $0.zoneSets[name] = zones }
        refreshZoneModel()
        if !presenter.isFullscreenEditorVisible {
            dragSnap.previewZones()
        }
    }

    func renameZoneSet(_ old: String, to new: String) -> Bool {
        guard old != new else { return true }
        guard store.config.zoneSets[old] != nil, store.config.zoneSets[new] == nil else { return false }
        store.update {
            guard let zones = $0.zoneSets.removeValue(forKey: old) else { return }
            $0.zoneSets[new] = zones
            $0.screenZoneSets = $0.screenZoneSets.mapValues { $0 == old ? new : $0 }
        }
        refreshZoneModel()
        return true
    }

    func deleteZoneSet(_ name: String) {
        store.update { $0.forgetZoneSet(named: name) }
        refreshZoneModel()
    }

    func togglePreview(zoneSet name: String, onScreen index: Int) {
        previewToken += 1
        guard model.previewedZoneSet != name else {
            clearPreview()
            return
        }
        guard let zones = store.config.zoneSets[name] ?? BuiltinZoneSets.all[name] else { return }
        dragSnap.showPreview(zones: zones, screenIndex: index)
        model.previewedZoneSet = name

        let token = previewToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self, previewToken == token else { return }
            clearPreview()
        }
    }

    func openZonePicker() {
        presenter.showZonePicker()
    }

    func editZoneSet(_ name: String, seed: [ZoneRect]?, onScreen index: Int) {
        presenter.showFullscreenEditor(set: name, seed: seed, screenIndex: index)
    }

    func launchWorkspace(named name: String, onScreen screen: Int?) {
        guard let workspace = store.config.workspaces[name] else { return }
        launcher.launch(workspace, named: name, onScreen: screen)
    }

    func deleteWorkspace(named name: String) {
        store.update { $0.workspaces.removeValue(forKey: name) }
        refreshWorkspaceModel()
    }

    func saveCurrentWorkspace(named name: String) {
        let items = router.snapshotWorkspace()
        guard !items.isEmpty else { return }
        let moveExisting = store.config.workspaces[name]?.moveExisting ?? true
        store.update { $0.workspaces[name] = Workspace(items: items, moveExisting: moveExisting) }
        refreshWorkspaceModel()
    }

    func setWorkspaceMoveExisting(_ on: Bool, for name: String) {
        store.update { $0.workspaces[name]?.moveExisting = on }
        refreshWorkspaceModel()
    }

    func updateWorkspaceItem(_ index: Int, in name: String, urls: [String], args: [String]) {
        store.update {
            guard $0.workspaces[name]?.items.indices.contains(index) == true else { return }
            $0.workspaces[name]?.items[index].urls = urls.isEmpty ? nil : urls
            $0.workspaces[name]?.items[index].args = args.isEmpty ? nil : args
        }
        refreshWorkspaceModel()
    }

    func removeWorkspaceItem(_ index: Int, from name: String) {
        store.update {
            guard $0.workspaces[name]?.items.indices.contains(index) == true else { return }
            $0.workspaces[name]?.items.remove(at: index)
        }
        refreshWorkspaceModel()
    }

    func cancelWorkspaceLaunch() {
        launcher.cancel()
    }
}
