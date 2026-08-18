import AppKit

// What the windows read, and how a config change reaches everything that cares.
//
// applyConfig is the whole of it: ConfigStore fires after every write, whoever
// made it, and each manager is handed the config rather than the field that
// moved. Nothing here pushes a single setting at anybody.

extension AppDelegate {
    /// Bundle version; empty when running unbundled through `swift run`.
    var appVersion: String { UpdateManager.bundleVersion ?? "" }

    /// The whole model, once, at launch. Everything config decides goes
    /// through applyConfig; what is left is fixed for the run or comes from
    /// macOS.
    func refreshModel() {
        model.appVersion = appVersion
        model.configWarning = store.loadFailure
        model.supportedTextLanguages = TextExtractor.supportedLanguages
        model.settingsGroups = SettingsPages.groups
        model.settingsPages = SettingsPages.all
        refreshPermissions()
        refreshScreenModel()
        applyConfig()
    }

    /// Hang applyConfig off the store. Its own step in the launch order, after
    /// every manager it reaches exists and independent of the HTTP server, so
    /// nothing about which writes get applied rides on where setupServer sits.
    func watchConfig() {
        store.didMutate = { [weak self] in
            guard let self else { return }
            applyConfig()
            router.changes.bump("config")
        }
    }

    /// Everything a config change has to reach, in one place, run after every
    /// write whoever made it: a settings row, an agent over the API, a
    /// Rectangle setup being imported, a hotkey being rebound.
    ///
    /// Each manager takes the whole config rather than the field that moved,
    /// so none of them has to be told which setting it cares about. That costs
    /// a few assignments per change and buys the guarantee that a saved
    /// setting is an applied one.
    ///
    /// A manager's apply can write config itself (keep-awake persisting a
    /// session it just ended), which lands back here mid-run. That inner call
    /// is deferred until this one has finished, so every manager sees the
    /// newest config in order rather than a stale snapshot after a newer one.
    func applyConfig() {
        guard !applyingConfig else {
            configApplyPending = true
            return
        }
        applyingConfig = true
        defer {
            applyingConfig = false
            if configApplyPending {
                configApplyPending = false
                applyConfig()
            }
        }

        let config = store.config
        let previous = appliedConfig
        model.config = config

        applyAppearance()
        hotkeys.apply(config)
        dragSnap.apply(config)
        grabMove.apply(config)
        mouse.apply(config)
        awake.apply(config)
        active.apply(config)
        newWindows.apply(config)
        updates.apply(config)
        applyLoginItem(config, previous: previous)
        applyRectangleURLs(config, previous: previous)
        appliedConfig = config

        // What the config implies rather than states, and what each manager
        // makes of its new settings. The zone and workspace lists are computed
        // off model.config; only what also depends on the screens is refreshed
        // here, and only when the part of config it reads has moved.
        statusMenu.workspaceNames = model.workspaceNames
        if previous?.screenZoneSets != config.screenZoneSets {
            refreshScreenAssignments()
        }
        refreshAwakeModel()
        refreshActiveModel()
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
        // Checked here first: markGettingStarted copies the whole config to
        // find out, and this runs on every write.
        if !model.connectedAgents.isEmpty, !store.config.sawFirstAgent {
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

    /// What the displays are, which config has no say in: at launch and when
    /// a screen comes or goes.
    func refreshScreenModel() {
        model.screenCount = NSScreen.screens.count
        model.screenDescriptions = NSScreen.screens.map { "\(Int($0.frame.width)) × \(Int($0.frame.height))" }
        model.screenSizes = NSScreen.screens.map(\.visibleFrame.size)
        refreshScreenAssignments()
    }

    /// Which set each screen wears: config keyed by display UUID, resolved
    /// against the screens attached now.
    func refreshScreenAssignments() {
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
