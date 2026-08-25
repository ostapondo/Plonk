import AppKit

// The collaborators AppDelegate hands to each manager at launch: what they may
// ask the app for, and what they report back. Settings are not here; those are
// applied in AppDelegate+Model.

extension AppDelegate {
    /// One place decides what Plonk will not touch, and everything that moves
    /// a window on its own asks it.
    func isExcluded(_ app: NSRunningApplication) -> Bool {
        AppExclusions.matches(name: app.localizedName ?? "", bundleID: app.bundleIdentifier,
                              patterns: store.config.excludedApps)
    }

    /// The same check as a closure, for the managers that hold one.
    var exclusionCheck: (NSRunningApplication) -> Bool {
        { [weak self] app in self?.isExcluded(app) ?? false }
    }

    func zones(onScreen index: Int) -> [ZoneRect] {
        store.config.zones(forKeys: ScreenIdentity.keys(forIndex: index))
    }

    /// The gap on a screen is the gap of the set it wears, or the default.
    func zoneGapPoints(onScreen index: Int) -> CGFloat {
        CGFloat(store.config.zoneGap(forKeys: ScreenIdentity.keys(forIndex: index)))
    }

    func setupCommands() {
        commands.zonesForScreen = { [weak self] index in self?.zones(onScreen: index) ?? [] }
        commands.isExcluded = exclusionCheck
        commands.announce = { HUD.shared.show($0) }
        commands.zoneGap = { [weak self] index in self?.zoneGapPoints(onScreen: index) ?? 0 }
    }

    func setupPresenter() {
        presenter.shotFolder = { [weak self] in self?.store.config.shotFolder ?? "~/Desktop" }
        presenter.onShotFinished = { [weak self] copied, path in self?.finishShot(copied: copied, path: path) }
        presenter.onCancelWorkspaceLaunch = { [weak self] in self?.launcher.cancel() }
        presenter.onZonePickerClosed = { [weak self] in self?.clearPreview() }
        presenter.onFullscreenEditorClosed = { [weak self] in self?.clearPreview() }
    }

    func setupLauncher() {
        launcher.onProgress = { [weak self] name, statuses in
            guard let self else { return }
            // The launcher is placing these windows itself; the new-window
            // watcher would only fight it, so it stands down until the last
            // window has settled.
            newWindows.suspended = true
            model.launchingWorkspace = name
            model.launchStatuses = statuses
            presenter.showWorkspaceLaunch()
        }
        launcher.onFinished = { [weak self] _, statuses in
            guard let self else { return }
            model.launchStatuses = statuses
            model.launchingWorkspace = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self, model.launchingWorkspace == nil else { return }
                newWindows.suspended = false
            }
            // Anything that failed stays up until the user has read it.
            guard statuses.allSatisfy({ $0.state != .pending && !$0.isFailure }) else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                guard self?.model.launchingWorkspace == nil else { return }
                self?.presenter.closeWorkspaceLaunch()
            }
        }
    }

    func setupVoice() {
        voice.onPartial = { text in
            HUD.shared.show(text.isEmpty ? String(localized: .hudListening) : text)
        }
        voice.onError = { message in HUD.shared.show(message) }
        voice.onTranscript = { [weak self] text in
            guard let self else { return }
            // The dozen things people say most run here, with no agent, no
            // round trip and no network. Everything else takes the long road.
            if store.config.voiceLocalCommands,
               let command = VoiceCommand.parse(text, workspaces: model.workspaceNames) {
                run(command)
                HUD.shared.show(.hudRan(String(localized: command.announcement)))
                return
            }
            let response = router.dispatch(prompt: text)
            if let error = response.json["error"] as? String {
                HUD.shared.show(error)
            } else {
                let agent = (response.json["agent"] as? String) ?? "agent"
                HUD.shared.show(.hudSentTo(agent, text))
            }
        }
    }

    func openPage(_ id: String) {
        model.selectedPage = id
        openMainWindow()
    }
}
