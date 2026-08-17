import AppKit

// What the windows read, and how a config change reaches everything that cares.
//
// applyConfig is the whole of it: ConfigStore fires after every write, whoever
// made it, and each manager is handed the config rather than the field that
// moved. Nothing here pushes a single setting at anybody.

extension AppDelegate {
    /// Bundle version; empty when running unbundled through `swift run`.
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    /// The whole model, for a window about to open. Everything config decides
    /// goes through applyConfig; what is left is fixed for the run or comes
    /// from macOS.
    func refreshModel() {
        model.appVersion = appVersion
        model.configWarning = store.loadFailure
        model.supportedTextLanguages = TextExtractor.supportedLanguages
        model.settingsGroups = SettingsPages.groups
        model.settingsPages = SettingsPages.all
        refreshPermissions()
        applyConfig()
    }

    /// Everything a config change has to reach, in one place, run after every
    /// write whoever made it: a settings row, an agent over the API, a
    /// Rectangle setup being imported, a hotkey being rebound.
    ///
    /// Each manager takes the whole config rather than the field that moved,
    /// so none of them has to be told which setting it cares about. That costs
    /// a few assignments per change and buys the guarantee that a saved
    /// setting is an applied one.
    func applyConfig() {
        let config = store.config
        model.config = config

        applyAppearance()
        hotkeys.setEnabled(config.hotkeysEnabled)
        hotkeys.bindings = config.resolvedHotkeys
        applyDragSnapSettings()
        applyGrabMoveSettings()
        applyMouseSettings()
        awake.apply(config)
        active.apply(config)
        newWindows.enabled = config.placeNewWindows
        updates.automatic = config.updateCheckAutomatically

        // What the config implies rather than states: the names in it, sorted
        // for the lists, and what each manager makes of its new settings.
        refreshAwakeModel()
        refreshActiveModel()
        refreshWorkspaceModel()
        refreshZoneModel()
        refreshHotkeyModel()
        refreshAgentModel()
        refreshUpdateModel()
    }

    /// Preflight does not prompt, so it is safe to poll whenever a window opens.
    func refreshPermissions() {
        model.accessibilityGranted = windows.isTrusted
        model.screenRecordingGranted = CGPreflightScreenCaptureAccess()
    }

    func refreshAgentModel() {
        model.connectedAgents = agents.onlineNames()
        if !model.connectedAgents.isEmpty {
            markGettingStarted { $0.sawFirstAgent = true }
        }
    }

    /// Tick a Getting Started step, at most once. Config is written to disk on
    /// every update, and both of these fire from paths that run constantly —
    /// every placement, every agent poll — so the guard is the point.
    func markGettingStarted(_ change: @escaping (inout Config) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            var updated = self.store.config
            change(&updated)
            guard updated.sawFirstSnap != self.store.config.sawFirstSnap
                || updated.sawFirstAgent != self.store.config.sawFirstAgent else { return }
            self.store.update(change)
        }
    }

    func refreshWorkspaceModel() {
        model.workspaceNames = store.config.workspaces.keys.sorted()
        statusMenu.workspaceNames = model.workspaceNames
    }

    func refreshZoneModel() {
        let custom = store.config.zoneSets.keys.sorted()
        model.customZoneSetNames = custom
        model.zoneSetNames = custom + BuiltinZoneSets.all.keys.sorted().filter { !custom.contains($0) }
        model.zoneSets = BuiltinZoneSets.all.merging(store.config.zoneSets) { _, user in user }
        model.screenCount = NSScreen.screens.count
        model.screenDescriptions = NSScreen.screens.map { "\(Int($0.frame.width)) × \(Int($0.frame.height))" }
        model.screenAssignments = NSScreen.screens.indices.reduce(into: [:]) { result, index in
            result[index] = store.config.zoneAssignment(forKeys: ScreenIdentity.keys(forIndex: index))
        }
    }

    func refreshStatusMenu() {
        statusMenu.refresh(
            icon: awake.isOn ? StatusIcon.awake : StatusIcon.idle,
            tooltip: String(localized: .menuTooltip(String(localized: awake.statusText))),
            dimmed: awake.requested && !awake.isOn
        )
    }

    func clearPreview() {
        dragSnap.hidePreviews()
        model.previewedZoneSet = nil
    }
}
