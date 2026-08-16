import AppKit

// The two ways a Rectangle setup reaches this app: its shortcuts, read once,
// and its URLs, answered as they arrive.
//
// Split out of AppDelegate, which is over the line limit and may only shrink.

extension AppDelegate {
    // MARK: - Shortcuts

    /// Take the bindings that mean the same thing here.
    ///
    /// Live preferences first, since those are what the user is pressing. A
    /// `RectangleConfig.json` is the fallback, which covers someone who
    /// exported on an old machine and never installed Rectangle on this one.
    func importFromRectangle() {
        guard let found = readRectangleSetup(), !found.isEmpty else {
            HUD.shared.show(.hudRectangleNothing)
            return
        }
        var displaced: [HotkeyAction] = []
        store.update { config in
            displaced = RectangleImport.apply(found, to: &config)
        }
        hotkeys.bindings = store.config.resolvedHotkeys
        model.zoneGap = store.config.zoneGap
        refreshHotkeyModel()
        HUD.shared.show(outcome(of: found, displaced: displaced))
    }

    /// What to say about an import that has already happened.
    ///
    /// A setup can be found and still bind nothing here — everything in it is
    /// one of the fixed-grid actions, or on a key this app has no name for.
    /// That is not the same as finding nothing, and saying so would send the
    /// user looking for a Rectangle they still have.
    private func outcome(
        of found: RectangleImport.Found, displaced: [HotkeyAction]
    ) -> LocalizedStringResource {
        if found.bindings.isEmpty { return .hudRectangleGridOnly }
        guard !displaced.isEmpty else { return .hudRectangleImported }
        // All of them, not the first: every one of these is a key that has
        // stopped working, and the page promises none go quietly.
        let names = displaced.map { String(localized: $0.title) }
        return .hudRectangleTook(ListFormatter.localizedString(byJoining: names))
    }

    private func readRectangleSetup() -> RectangleImport.Found? {
        // Bindings, not merely something: an installed Rectangle whose only
        // stored value is a gap should not shadow an export that has the keys.
        if let domain = UserDefaults(suiteName: RectangleImport.defaultsSuite)?
            .dictionaryRepresentation() {
            let found = RectangleImport.read(defaults: domain)
            if !found.bindings.isEmpty || !found.unmapped.isEmpty { return found }
        }
        guard let url = RectangleImport.exportedConfigURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return RectangleImport.read(exportedJSON: data)
    }

    // MARK: - URLs

    /// Ask macOS to send `rectangle://` here too, or hand it back.
    ///
    /// The switch shows what macOS settled on rather than what was asked of it,
    /// which is why the model is written from the callback and not from `on`.
    func setRectangleURLs(_ on: Bool) {
        store.update { $0.handleRectangleURLs = on }
        RectangleURLs.setHandled(on) { [weak self] holding in
            self?.model.handleRectangleURLs = holding
        }
    }

    /// `open -g "plonk://execute-action?name=left-half"`.
    ///
    /// A URL that names nothing gets a HUD rather than silence. The caller is a
    /// script with nowhere to receive an error, so the screen is the only place
    /// left to report one.
    func application(_ application: NSApplication, open urls: [URL]) {
        // A URL that launched the app can arrive before applicationDidFinish-
        // Launching has read the config or built the managers these actions go
        // through. One hop puts it after both.
        DispatchQueue.main.async { [weak self] in urls.forEach { self?.open($0) } }
    }

    private func open(_ url: URL) {
        returnRectangleURLsIfUnwanted(url)
        switch URLCommand.parse(url) {
        case .success(.action(let action)):
            perform(action)
        case .failure(.fixedGridAction(let name)):
            HUD.shared.show(.hudUrlZoneSet(name))
        case .failure(.unknownAction(let name)):
            HUD.shared.show(.hudUrlUnknown(name))
        case .failure(.heldDownAction(let name)):
            HUD.shared.show(.hudUrlHeldDown(name))
        case .failure(.missingName), .failure(.unknownHost), .failure(.unknownScheme):
            HUD.shared.show(.hudUrlUnreadable)
        }
    }

    /// A `rectangle://` URL arriving while the setting is off means the scheme
    /// was won by accident, which declaring it is enough to do. Hand it back,
    /// and still run this one rather than drop it.
    ///
    /// The only moment that mistake is observable, so the only place to check.
    private func returnRectangleURLsIfUnwanted(_ url: URL) {
        guard url.scheme?.lowercased() == RectangleURLs.scheme,
              !store.config.handleRectangleURLs else { return }
        DispatchQueue.global(qos: .utility).async {
            RectangleURLs.setHandled(false) { [weak self] holding in
                self?.model.handleRectangleURLs = holding
            }
        }
    }
}
