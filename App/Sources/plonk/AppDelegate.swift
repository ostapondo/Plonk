import AppKit
import CoreGraphics
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let issuesURL = "https://github.com/ostapondo/plonk/issues/new"

    private let store = ConfigStore()
    private let windows = WindowManager()
    private let awake = AwakeManager()
    private let agents = AgentRegistry()
    private let eventBroadcaster = EventBroadcaster()
    private let voice = VoiceManager()
    private let hotkeys = HotkeyManager()
    private let updates = UpdateManager()
    private let model = AppModel()
    private let snapMemory = SnapMemory()
    private lazy var commands = WindowCommands(windows: windows, memory: snapMemory)
    private lazy var launcher = WorkspaceLauncher(windows: windows)
    private lazy var presenter = WindowPresenter(model: model)
    private var statusMenu: StatusMenuController!
    private var dragSnap: DragSnapManager!
    private var grabMove: GrabMove!
    private var newWindows: NewWindowWatcher!
    private let mouse = MouseTools()
    private let crops = CropAndLock()
    private var guidePanel: ShortcutGuidePanel?
    private var guideLoading = false
    /// How many captures are in flight; see hideOwnWindows.
    private var captureDepth = 0
    private var router: Router!
    private var server: ControlServer?
    private var previewToken = 0
    private var screenSettleWork: DispatchWorkItem?
    /// Display UUIDs seen at the last screen-parameter change, so a Dock
    /// resize can be told apart from a monitor being plugged in.
    private var knownDisplays: Set<String> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Before anything is on screen: a second copy would add its own menu bar
        // icon and hotkeys, and lose the race for the control server's port.
        if let existing = Self.otherRunningInstance() {
            existing.activate()
            NSApp.terminate(nil)
            return
        }
        store.load()
        windows.promptForTrust()

        model.actions = self
        setupCommands()
        setupPresenter()
        setupStatusMenu()
        setupAwake()
        setupLauncher()
        setupHotkeys()
        setupVoice()
        setupDragSnap()
        setupGrabMove()
        setupNewWindows()
        setupMouseTools()
        setupServer()
        setupUpdates()
        refreshModel()

        applyLaunchAtLogin(store.config.launchAtLogin)
        model.launchAtLogin = isLaunchAtLoginEnabled

        knownDisplays = Self.attachedDisplays()
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

    // MARK: - Wiring

    /// One place decides what Plonk will not touch, and everything that moves
    /// a window on its own asks it.
    private func isExcluded(_ app: NSRunningApplication) -> Bool {
        AppExclusions.matches(name: app.localizedName ?? "", bundleID: app.bundleIdentifier,
                              patterns: store.config.excludedApps)
    }

    private func setupCommands() {
        commands.zonesForScreen = { [weak self] index in
            guard let self else { return [] }
            return store.config.zones(forKeys: ScreenIdentity.keys(forIndex: index))
        }
        commands.isExcluded = { [weak self] app in self?.isExcluded(app) ?? false }
        commands.announce = { HUD.shared.show($0) }
        commands.zoneGap = { [weak self] in CGFloat(self?.store.config.zoneGap ?? 0) }
    }

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
        statusMenu.agentEntries = { [weak self] in
            guard let self else { return [] }
            var names = agents.onlineNames()
            for adapter in store.config.agentAdapters where !names.contains(adapter.name) {
                names.append(adapter.name)
            }
            if let selected = store.config.selectedAgent, !names.contains(selected) {
                names.append(selected)
            }
            return names.map { ($0, $0 == self.store.config.selectedAgent) }
        }
        statusMenu.isExclusive = { [weak self] in self?.store.config.agentExclusive ?? false }
        statusMenu.hasSelection = { [weak self] in self?.store.config.selectedAgent != nil }
        statusMenu.onSelectAgent = { [weak self] name in self?.selectAgent(name) }
        statusMenu.onToggleExclusive = { [weak self] in
            guard let self else { return }
            setAgentExclusive(!store.config.agentExclusive)
        }
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
            // Also fires when the power source or a timeout flips it, which
            // writes no config and would otherwise never reach a listener.
            router?.changes.bump("awake")
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
        hotkeys.onActionUp = { [weak self] action in
            guard action == .voice else { return }
            self?.voice.finishCapture()
        }
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
        case .captureText:
            captureText()
        case .voice:
            voice.beginCapture()
        case .unsnap:
            commands.unsnap()
        case .cycleZone:
            commands.cycleZone(backwards: false)
        case .cycleZoneBack:
            commands.cycleZone(backwards: true)
        case .findCursor:
            mouse.flashSpotlight()
        case .jumpCursor:
            if !mouse.jumpToNextScreen() { HUD.shared.show("Only one screen to jump between") }
        case .cropLive:
            pinCrop(live: true)
        case .cropStill:
            pinCrop(live: false)
        case .shortcutGuide:
            toggleShortcutGuide()
        default:
            if let number = action.zoneNumber {
                commands.snap(toZone: number)
            } else if let number = action.layoutNumber {
                commands.applyZoneSet(number: number, named: model.zoneSetNames) { [weak self] name, screen in
                    self?.assignZoneSet(name, toScreen: screen)
                }
            } else if let direction = action.focusDirection {
                commands.moveFocus(direction)
            } else if let preset = action.preset {
                commands.apply(preset)
            }
        }
    }

    /// Region capture straight into recognition: the text lands on the
    /// clipboard, and the HUD shows what was read so a bad crop is obvious
    /// without pasting it somewhere first.
    private func captureText() {
        runCapture(.region, openEditor: false) { [weak self] image in
            guard let self, let image else { return }
            TextExtractor.recognize(in: image, languages: store.config.textLanguages) { result in
                switch result {
                case .failure(let error):
                    HUD.shared.show(error.localizedDescription)
                case .success(let lines):
                    let text = TextExtractor.joined(lines)
                    guard !text.isEmpty else {
                        HUD.shared.show("No text found there")
                        return
                    }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    HUD.shared.show("Copied: \(text.prefix(80))\(text.count > 80 ? "…" : "")")
                }
            }
        }
    }

    private func setupVoice() {
        voice.onPartial = { text in
            HUD.shared.show(text.isEmpty ? "Listening…" : text)
        }
        voice.onError = { message in HUD.shared.show(message) }
        voice.onTranscript = { [weak self] text in
            guard let self else { return }
            let response = router.dispatch(prompt: text)
            if let error = response.json["error"] as? String {
                HUD.shared.show(error)
            } else {
                let agent = (response.json["agent"] as? String) ?? "agent"
                HUD.shared.show("→ \(agent): \(text)")
            }
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
        dragSnap.appearance = { [weak self] in self?.zoneAppearance ?? ZoneAppearance() }
        dragSnap.showOnAllMonitors = store.config.zonesOnAllMonitors
        dragSnap.edgeSpanPoints = store.config.zoneEdgeSpanPoints
        dragSnap.isExcluded = { [weak self] app in self?.isExcluded(app) ?? false }
        dragSnap.onSnap = { [weak self] window, before, frac, screenIndex in
            guard let self else { return }
            snapMemory.record(window, wasAt: before, placedAt: frac,
                              screenUUID: ScreenIdentity.uuid(forIndex: screenIndex),
                              zoneIndex: zoneIndex(of: frac, onScreen: screenIndex),
                              appKey: windows.app(ofWindow: window)?.bundleIdentifier)
        }
        dragSnap.start()
    }

    private var zoneAppearance: ZoneAppearance {
        ZoneAppearance(gap: CGFloat(store.config.zoneGap),
                       opacity: CGFloat(store.config.zoneOpacity),
                       color: ZoneAppearance.color(fromHex: store.config.zoneColorHex),
                       showNumbers: store.config.zoneNumbersVisible)
    }

    private func setupGrabMove() {
        grabMove = GrabMove(windows: windows)
        grabMove.isExcluded = { [weak self] app in self?.isExcluded(app) ?? false }
        // A grab is a drag as far as zones are concerned, so it goes through
        // the same overlay and the same drop rules.
        grabMove.onGrabBegan = { [weak self] window, frame in
            self?.dragSnap.beginExternalDrag(window: window, startFrame: frame)
        }
        grabMove.onGrabMoved = { [weak self] in self?.dragSnap.updateExternalDrag() }
        grabMove.onGrabResized = { [weak self] window, startFrame in
            guard let self, let placed = windows.fraction(ofWindow: window) else { return }
            snapMemory.record(window, wasAt: startFrame, placedAt: placed.frac,
                              screenUUID: ScreenIdentity.uuid(forIndex: placed.screenIndex),
                              appKey: windows.app(ofWindow: window)?.bundleIdentifier)
            router?.changes.bump("windows")
        }
        grabMove.onGrabEnded = { [weak self] window, startFrame in
            guard let self else { return }
            // A grab that landed in a zone is recorded by the zone drop. One
            // that did not is still a move Plonk made, so it is remembered
            // too — otherwise the shortcut that puts a window back would have
            // nothing to put back after a free drag.
            if !dragSnap.endExternalDrag(), let placed = windows.fraction(ofWindow: window) {
                snapMemory.record(window, wasAt: startFrame, placedAt: placed.frac,
                                  screenUUID: ScreenIdentity.uuid(forIndex: placed.screenIndex))
            }
            router?.changes.bump("windows")
        }
        applyGrabMoveSettings()
    }

    /// An event tap that can swallow clicks has no business existing while the
    /// feature is off, so the tap follows the setting rather than the launch.
    private func applyGrabMoveSettings() {
        grabMove.enabled = store.config.grabMoveEnabled
        grabMove.modifierFlag = Self.modifierFlag(store.config.grabMoveModifier)
        grabMove.allowResize = store.config.grabMoveResize
        grabMove.showGeometry = store.config.grabMoveShowGeometry
        if store.config.grabMoveEnabled {
            grabMove.start()
        } else {
            grabMove.stop()
        }
    }

    /// Which numbered zone a dropped fraction corresponds to, so editing the
    /// set later can move the window with its number. Nil for a span or an
    /// edge snap, which match no single zone.
    private func zoneIndex(of frac: FracRect, onScreen index: Int) -> Int? {
        let zones = store.config.zones(forKeys: ScreenIdentity.keys(forIndex: index))
        return zones.firstIndex {
            abs($0.x - frac.x) < 0.001 && abs($0.y - frac.y) < 0.001
                && abs($0.w - frac.w) < 0.001 && abs($0.h - frac.h) < 0.001
        }
    }

    private func setupNewWindows() {
        newWindows = NewWindowWatcher(windows: windows)
        newWindows.enabled = store.config.placeNewWindows
        newWindows.isExcluded = { [weak self] app in self?.isExcluded(app) ?? false }
        newWindows.zoneGap = { [weak self] in CGFloat(self?.store.config.zoneGap ?? 0) }
        newWindows.placement = { [weak self] app in
            guard let self, let key = app.bundleIdentifier,
                  let habit = snapMemory.habit(ofApp: key) else { return nil }
            // The display is named by UUID, so a habit formed on a monitor that
            // has since been unplugged simply does not apply.
            guard let uuid = habit.screenUUID, let index = ScreenIdentity.index(forUUID: uuid) else { return nil }
            // A numbered zone is followed by number, so the habit survives the
            // set being edited; anything else falls back to the raw fraction.
            let zones = store.config.zones(forKeys: ScreenIdentity.keys(forIndex: index))
            if let zone = habit.zoneIndex, zones.indices.contains(zone) {
                return (zones[zone].frac, index)
            }
            return (habit.frac, index)
        }
        newWindows.onPlaced = { [weak self] app, window, before, frac, screenIndex in
            guard let self else { return }
            snapMemory.record(window, wasAt: before, placedAt: frac,
                              screenUUID: ScreenIdentity.uuid(forIndex: screenIndex),
                              zoneIndex: zoneIndex(of: frac, onScreen: screenIndex),
                              appKey: app.bundleIdentifier)
            router?.changes.bump("windows")
        }
        newWindows.start()
    }

    /// Reads the front app's menus and floats them. Pressing the key again
    /// closes it, which is how a reference panel should behave.
    private func toggleShortcutGuide() {
        if let panel = guidePanel {
            panel.close()
            return
        }
        // Reading a big app's menus takes a moment; a second press inside that
        // window would build a second panel and orphan the first.
        guard !guideLoading else { return }
        guard windows.isTrusted else {
            HUD.shared.show("The shortcut guide needs Accessibility")
            return
        }
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let name = app.localizedName ?? "This app"
        guideLoading = true
        ShortcutGuide.read(for: app) { [weak self] items in
            guard let self else { return }
            guideLoading = false
            // The guide describes whatever was in front when it was asked for,
            // so a slow app cannot end up labelled with the wrong name.
            let panel = ShortcutGuidePanel(appName: name, items: items)
            panel.onClose = { [weak self] in self?.guidePanel = nil }
            guidePanel = panel
            panel.orderFrontRegardless()
        }
    }

    /// Drag out a region and float it above everything, live or frozen.
    private func pinCrop(live: Bool) {
        let report: (Result<String, Error>) -> Void = { result in
            if case .failure(let error) = result {
                HUD.shared.show(error.localizedDescription)
            }
        }
        // Plonk's own windows would otherwise be in the shot, and the picker
        // has to be the only thing on top.
        let hidden = hideOwnWindows()
        let finish: (Result<String, Error>) -> Void = { [weak self] result in
            self?.showOwnWindows(hidden)
            report(result)
        }
        if live {
            crops.createLive(completion: finish)
        } else {
            crops.createStill(completion: finish)
        }
    }

    private func setupMouseTools() {
        applyMouseSettings()
    }

    /// Same rule as grab-and-move: no tap unless something needs one. Finding
    /// the pointer is a shortcut and draws without watching anything.
    private func applyMouseSettings() {
        mouse.highlightEnabled = store.config.highlightClicksEnabled
        mouse.crosshairsEnabled = store.config.crosshairsEnabled
        mouse.tint = ZoneAppearance.color(fromHex: store.config.zoneColorHex) ?? .controlAccentColor
        if store.config.highlightClicksEnabled || store.config.crosshairsEnabled {
            mouse.start()
        } else {
            mouse.stop()
        }
    }

    private func setupUpdates() {
        updates.onChange = { [weak self] in
            guard let self else { return }
            refreshUpdateModel()
            refreshStatusMenu()
            router?.changes.bump("update")
        }
        // Progress moves the bar and nothing else: agents are told about an
        // update starting and finishing, not about every chunk of it.
        updates.onProgress = { [weak self] in
            self?.model.updateProgress = self?.updates.progress ?? 0
        }
        updates.automatic = store.config.updateCheckAutomatically
        statusMenu.updateVersion = { [weak self] in self?.updates.available?.version.text }
        statusMenu.onOpenUpdate = { [weak self] in self?.openPage("update") }

        router.updateState = { [weak self] in
            guard let self else { return [:] }
            var state: [String: Any] = [
                "installed": UpdateManager.currentVersionText,
                "available": updates.available != nil,
                "phase": updates.phase.rawValue,
                "status": updates.status,
                "automatic": store.config.updateCheckAutomatically,
            ]
            if let release = updates.available {
                state["latest"] = release.version.text
                state["notes"] = release.notes
                state["page"] = release.pageURL.absoluteString
            }
            return state
        }
        router.checkForUpdates = { [weak self] in self?.updates.check() }
        router.installUpdate = { [weak self] in
            // The reply has to reach the caller before the process goes away.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self?.updates.install() }
        }
        updates.start()
    }

    private func setupServer() {
        router = Router(store: store, windows: windows, awake: awake, agents: agents)
        router.changes.onEvent = { [weak self] rev, what in
            self?.eventBroadcaster.broadcast(rev: rev, what: what)
        }
        router.attachEvents = { [weak self] conn, rev in
            self?.eventBroadcaster.attach(conn, rev: rev)
        }
        // Every source of change funnels into the bus at its own choke point,
        // so no caller has to remember to announce itself.
        store.didMutate = { [weak self] in self?.router.changes.bump("config") }
        windows.onDidPlace = { [weak self] in
            self?.router.changes.bump("windows")
            self?.markGettingStarted { $0.sawFirstSnap = true }
        }
        agents.onChange = { [weak self] in
            self?.refreshAgentModel()
            self?.router.changes.bump("agents")
        }
        router.didChangeAgents = { [weak self] in self?.refreshAgentModel() }
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
        // Adapters may run for minutes, so they never touch the main thread.
        router.runAdapter = { adapter, prompt in
            DispatchQueue.global(qos: .userInitiated).async {
                let invocation = AgentAdapter.invocation(command: adapter.command, prompt: prompt)
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-lc", invocation.command]
                process.environment = ProcessInfo.processInfo.environment
                    .merging(invocation.environment) { _, prompt in prompt }
                do {
                    try process.run()
                } catch {
                    NSLog("Plonk: adapter \(adapter.name) failed to start: \(error)")
                }
            }
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
        // A pid means nothing after a relaunch — the process it named may be
        // gone, or worse, reused — so those sessions are recorded as off and
        // simply end when the app does.
        let requested = awake.boundPID == nil && awake.requested
        let end = awake.sessionEnd?.timeIntervalSince1970
        guard store.config.awakeRequested != requested || store.config.awakeSessionEnd != end else { return }
        store.update {
            $0.awakeRequested = requested
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
        model.zoneGap = store.config.zoneGap
        model.zoneOpacity = store.config.zoneOpacity
        model.zoneColorHex = store.config.zoneColorHex
        model.zoneNumbersVisible = store.config.zoneNumbersVisible
        model.zonesOnAllMonitors = store.config.zonesOnAllMonitors
        model.zoneEdgeSpan = store.config.zoneEdgeSpanPoints
        model.grabMoveEnabled = store.config.grabMoveEnabled
        model.grabMoveModifier = store.config.grabMoveModifier
        model.grabMoveResize = store.config.grabMoveResize
        model.grabMoveShowGeometry = store.config.grabMoveShowGeometry
        model.highlightClicksEnabled = store.config.highlightClicksEnabled
        model.crosshairsEnabled = store.config.crosshairsEnabled
        model.excludedApps = store.config.excludedApps
        model.restoreZonesOnScreenChange = store.config.restoreZonesOnScreenChange
        model.placeNewWindows = store.config.placeNewWindows
        model.textLanguages = store.config.textLanguages
        model.supportedTextLanguages = TextExtractor.supportedLanguages
        model.shotFolder = store.config.shotFolder
        model.shotCopyToClipboard = store.config.shotCopyToClipboard
        model.sawFirstSnap = store.config.sawFirstSnap
        model.sawFirstAgent = store.config.sawFirstAgent
        model.gettingStartedHidden = store.config.gettingStartedHidden
        model.settingsPages = [
            SettingsPage(id: "home", title: "Home", icon: "house") { AnyView(HomePage(model: $0)) },
            SettingsPage(id: "shortcuts", title: "Shortcuts", icon: "keyboard") { AnyView(ShortcutsPage(model: $0)) },
            SettingsPage(id: "workspaces", title: "Workspaces", icon: "rectangle.3.group", section: "Windows") { AnyView(WorkspacesPage(model: $0)) },
            SettingsPage(id: "zones", title: "Zones", icon: "square.grid.2x2", section: "Windows") { AnyView(ZonesPage(model: $0)) },
            SettingsPage(id: "voice", title: "Voice", icon: "mic", section: "Gadgets") { AnyView(VoicePage(model: $0)) },
            SettingsPage(id: "awake", title: "Keep Awake", icon: "cup.and.saucer", section: "Gadgets") { AnyView(AwakePage(model: $0)) },
            SettingsPage(id: "shot", title: "Screenshot", icon: "camera.viewfinder", section: "Gadgets") { AnyView(ShotPage(model: $0)) },
            SettingsPage(id: "mouse", title: "Pointer", icon: "cursorarrow.rays", section: "Gadgets") { AnyView(MousePage(model: $0)) },
            SettingsPage(id: "ai", title: "AI · MCP", icon: "sparkles", section: "Setup") { AnyView(AIPage(model: $0)) },
            SettingsPage(id: "update", title: "Updates", icon: "arrow.down.circle", section: "Setup") { AnyView(UpdatePage(model: $0)) },
        ]
        refreshWorkspaceModel()
        refreshZoneModel()
        refreshHotkeyModel()
        refreshAgentModel()
        refreshUpdateModel()
    }

    /// Preflight does not prompt, so it is safe to poll whenever a window opens.
    private func refreshPermissions() {
        model.accessibilityGranted = windows.isTrusted
        model.screenRecordingGranted = CGPreflightScreenCaptureAccess()
    }

    private func refreshUpdateModel() {
        model.updateCheckAutomatically = store.config.updateCheckAutomatically
        model.updateAvailableVersion = updates.available?.version.text ?? ""
        model.updateNotes = updates.available?.notes ?? ""
        model.updateStatus = updates.status
        model.updatePhase = updates.phase.rawValue
        model.updateProgress = updates.progress
    }

    private func refreshAgentModel() {
        model.connectedAgents = agents.onlineNames()
        model.selectedAgent = store.config.selectedAgent
        model.agentExclusive = store.config.agentExclusive
        if !model.connectedAgents.isEmpty {
            markGettingStarted { $0.sawFirstAgent = true }
        }
    }

    /// Tick a Getting Started step, at most once. Config is written to disk on
    /// every update, and both of these fire from paths that run constantly —
    /// every placement, every agent poll — so the guard is the point.
    private func markGettingStarted(_ change: @escaping (inout Config) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            var updated = self.store.config
            change(&updated)
            guard updated.sawFirstSnap != self.store.config.sawFirstSnap
                || updated.sawFirstAgent != self.store.config.sawFirstAgent else { return }
            self.store.update(change)
            self.model.sawFirstSnap = self.store.config.sawFirstSnap
            self.model.sawFirstAgent = self.store.config.sawFirstAgent
        }
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

        // This notification also fires for a resolution change, a display
        // waking, and the Dock being resized or auto-hidden. Only a display
        // actually arriving or leaving should move anybody's windows.
        let displays = Self.attachedDisplays()
        defer { knownDisplays = displays }
        guard store.config.restoreZonesOnScreenChange, displays != knownDisplays else { return }

        // macOS sends this before the apps behind those windows have caught up,
        // and several times while a display wakes. Settling first, then placing
        // once, is the difference between windows landing and windows fighting.
        screenSettleWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.commands.restorePlacements() }
        screenSettleWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    /// Grab-and-move, the pointer tools and the new-window watcher all need
    /// Accessibility to arm, and on a first run it has just been asked for and
    /// not yet given. Rather than making each of them dead until the next
    /// launch, this waits for the grant and starts them then. Drag snapping
    /// does not need it because it re-checks on every event.
    private func watchForAccessibility() {
        guard !windows.isTrusted else { return }
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            guard windows.isTrusted else { return }
            timer.invalidate()
            applyGrabMoveSettings()
            applyMouseSettings()
            newWindows.start()
            refreshPermissions()
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    private static func attachedDisplays() -> Set<String> {
        Set(NSScreen.screens.indices.compactMap { ScreenIdentity.uuid(forIndex: $0) })
    }

    private static func modifierFlag(_ name: String) -> NSEvent.ModifierFlags {
        switch name {
        case "option": return .option
        case "control": return .control
        case "command": return .command
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
        let hidden = hideOwnWindows()
        ScreenshotManager.capture(mode) { [weak self] image in
            self?.showOwnWindows(hidden)
            if let image, openEditor { self?.presenter.showShotEditor(image: image) }
            completion(image)
        }
    }

    /// Everything Plonk has on screen, ordered out so it cannot end up in a
    /// capture: settings and editors, but also the crosshairs and any pinned
    /// crop, which are floating over exactly the area being photographed.
    private func hideOwnWindows() -> [NSWindow] {
        // Counted, because a capture can start while a pinned crop is still
        // choosing its region: the first one to finish must not put the
        // overlays back into the other one's photograph.
        captureDepth += 1
        mouse.suspend()
        let hidden = (presenter.visible + crops.visibleWindows + [guidePanel].compactMap { $0 })
            .filter { $0.isVisible }
        hidden.forEach { $0.orderOut(nil) }
        return hidden
    }

    private func showOwnWindows(_ hidden: [NSWindow]) {
        captureDepth = max(0, captureDepth - 1)
        hidden.forEach { $0.orderFront(nil) }
        guard captureDepth == 0 else { return }
        mouse.resume()
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

    private func openPage(_ id: String) {
        model.selectedPage = id
        openMainWindow()
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

    func setZoneGap(_ points: Double) {
        store.update { $0.zoneGap = max(0, min(points, 40)) }
        model.zoneGap = store.config.zoneGap
    }

    func setZoneOpacity(_ value: Double) {
        store.update { $0.zoneOpacity = max(0.1, min(value, 1)) }
        model.zoneOpacity = store.config.zoneOpacity
    }

    func setZoneColor(_ hex: String?) {
        store.update { $0.zoneColorHex = hex }
        model.zoneColorHex = hex
        // The pointer tools share the tint, so the desk stays one colour.
        applyMouseSettings()
    }

    func setZoneNumbersVisible(_ on: Bool) {
        store.update { $0.zoneNumbersVisible = on }
        model.zoneNumbersVisible = on
    }

    func setZonesOnAllMonitors(_ on: Bool) {
        store.update { $0.zonesOnAllMonitors = on }
        model.zonesOnAllMonitors = on
        dragSnap.showOnAllMonitors = on
    }

    func setZoneEdgeSpan(_ points: Double) {
        store.update { $0.zoneEdgeSpanPoints = max(0, min(points, 60)) }
        model.zoneEdgeSpan = store.config.zoneEdgeSpanPoints
        dragSnap.edgeSpanPoints = store.config.zoneEdgeSpanPoints
    }

    func setGrabMove(_ on: Bool) {
        store.update { $0.grabMoveEnabled = on }
        model.grabMoveEnabled = on
        applyGrabMoveSettings()
    }

    func setGrabMoveModifier(_ name: String) {
        store.update { $0.grabMoveModifier = name }
        model.grabMoveModifier = name
        applyGrabMoveSettings()
    }

    func setGrabMoveResize(_ on: Bool) {
        store.update { $0.grabMoveResize = on }
        model.grabMoveResize = on
        applyGrabMoveSettings()
    }

    func setGrabMoveShowGeometry(_ on: Bool) {
        store.update { $0.grabMoveShowGeometry = on }
        model.grabMoveShowGeometry = on
        applyGrabMoveSettings()
    }

    func setHighlightClicks(_ on: Bool) {
        store.update { $0.highlightClicksEnabled = on }
        model.highlightClicksEnabled = on
        applyMouseSettings()
    }

    func setCrosshairs(_ on: Bool) {
        store.update { $0.crosshairsEnabled = on }
        model.crosshairsEnabled = on
        applyMouseSettings()
    }

    func setExcludedApps(_ patterns: [String]) {
        store.update { $0.excludedApps = patterns }
        model.excludedApps = patterns
    }

    func setPlaceNewWindows(_ on: Bool) {
        store.update { $0.placeNewWindows = on }
        model.placeNewWindows = on
        newWindows.enabled = on
    }

    func setRestoreZonesOnScreenChange(_ on: Bool) {
        store.update { $0.restoreZonesOnScreenChange = on }
        model.restoreZonesOnScreenChange = on
    }

    func setTextLanguages(_ tags: [String]) {
        let allowed = tags.filter { TextExtractor.supportedLanguages.contains($0) }
        store.update { $0.textLanguages = allowed }
        model.textLanguages = allowed
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
        commands.relayout(screenIndex: index)
    }

    func updateZoneSet(_ name: String, zones: [ZoneRect]) {
        store.update { $0.zoneSets[name] = zones }
        refreshZoneModel()
        for index in NSScreen.screens.indices
        where store.config.zoneAssignment(forKeys: ScreenIdentity.keys(forIndex: index)) == name {
            commands.relayout(screenIndex: index)
        }
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

    func renameWorkspace(_ old: String, to new: String) -> Bool {
        guard old != new else { return true }
        guard store.config.workspaces[old] != nil, store.config.workspaces[new] == nil else { return false }
        store.update {
            guard let workspace = $0.workspaces.removeValue(forKey: old) else { return }
            $0.workspaces[new] = workspace
        }
        refreshWorkspaceModel()
        return true
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

    func selectAgent(_ name: String?) {
        store.update { $0.selectedAgent = name }
        refreshAgentModel()
    }

    func setAgentExclusive(_ on: Bool) {
        store.update { $0.agentExclusive = on }
        refreshAgentModel()
    }

    func hideGettingStarted() {
        store.update { $0.gettingStartedHidden = true }
        model.gettingStartedHidden = true
    }

    func setUpdateCheckAutomatically(_ on: Bool) {
        store.update { $0.updateCheckAutomatically = on }
        updates.automatic = on
        refreshUpdateModel()
    }

    func checkForUpdates() {
        updates.check()
    }

    func installUpdate() {
        updates.install()
    }

    func openReleasePage() {
        NSWorkspace.shared.open(updates.available?.pageURL ?? Release.releasesPageURL)
    }
}
