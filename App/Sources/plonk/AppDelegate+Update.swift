import AppKit

// Checking for a newer release and installing it. The only thing in the app
// that opens an outbound connection; see Config.updateCheckAutomatically.

extension AppDelegate {
    func setupUpdates() {
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
        updates.apply(store.config)
        statusMenu.updateVersion = { [weak self] in self?.updates.available?.version.text }
        statusMenu.onOpenUpdate = { [weak self] in self?.openPage("update") }

        router.updateState = { [weak self] in
            guard let self else { return [:] }
            var state: [String: Any] = [
                "installed": UpdateManager.currentVersionText,
                "available": updates.available != nil,
                "phase": updates.phase.rawValue,
                "status": String(localized: updates.status),
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

    func refreshUpdateModel() {
        model.updateAvailableVersion = updates.available?.version.text ?? ""
        model.updateNotes = updates.available?.notes ?? ""
        model.updateStatus = String(localized: updates.status)
        model.updatePhase = updates.phase.rawValue
        model.updateProgress = updates.progress
    }
}
