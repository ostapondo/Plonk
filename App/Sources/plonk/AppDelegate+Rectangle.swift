import AppKit

// The two ways a Rectangle setup reaches this app: its shortcuts, read once
// and kept, and its URLs, answered every time one arrives.
//
// Split out of AppDelegate, which is over the line limit and may only shrink.

extension AppDelegate {
    // MARK: - Shortcuts

    /// Read whatever Rectangle setup this Mac has and take the bindings that
    /// mean the same thing here.
    ///
    /// The live preferences of an installed copy come first, since those are
    /// what the user is actually pressing. A `RectangleConfig.json` is the
    /// fallback, so this still works for someone who exported their settings
    /// on the old machine and has not installed Rectangle on this one.
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
        // Naming the first casualty rather than counting them: the number is
        // no use without knowing which, and one is the usual answer.
        if let taken = displaced.first {
            HUD.shared.show(.hudRectangleTook(String(localized: taken.title)))
        } else {
            HUD.shared.show(.hudRectangleImported)
        }
    }

    private func readRectangleSetup() -> RectangleImport.Found? {
        if let domain = UserDefaults(suiteName: RectangleImport.defaultsSuite)?
            .dictionaryRepresentation() {
            let found = RectangleImport.read(defaults: domain)
            if !found.isEmpty { return found }
        }
        guard let url = RectangleImport.exportedConfigURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return RectangleImport.read(exportedJSON: data)
    }

    // MARK: - URLs

    /// Ask macOS to send `rectangle://` here too, or hand it back.
    func setRectangleURLs(_ on: Bool) {
        store.update { $0.handleRectangleURLs = on }
        RectangleURLs.setHandled(on)
        // Read the answer back rather than assuming it: the switch should show
        // what macOS did, not what was asked of it.
        model.handleRectangleURLs = RectangleURLs.isHandler
    }

    /// `open -g "plonk://execute-action?name=left-half"`, which is how a
    /// Raycast script, an Alfred workflow or a Stream Deck button drives this.
    ///
    /// A URL that names nothing gets a HUD rather than silence: the caller is
    /// a script with nowhere to put an error, so the screen is the only place
    /// left to say that the key did nothing.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            returnRectangleURLsIfUnwanted(url)
            switch URLCommand.parse(url) {
            case .success(.action(let action)):
                perform(action)
            case .failure(.fixedGridAction(let name)):
                HUD.shared.show(.hudUrlZoneSet(name))
            case .failure(.unknownAction(let name)):
                HUD.shared.show(.hudUrlUnknown(name))
            case .failure(.missingName), .failure(.unknownHost), .failure(.unknownScheme):
                HUD.shared.show(.hudUrlUnreadable)
            }
        }
    }

    /// A `rectangle://` URL arriving while the setting is off means the scheme
    /// was won by accident — declaring it is enough for LaunchServices to hand
    /// it over on install. Give it back, and still run this one, since dropping
    /// it would help nobody.
    ///
    /// This is the only moment the mistake can matter, so it is the only place
    /// that has to check.
    private func returnRectangleURLsIfUnwanted(_ url: URL) {
        guard url.scheme?.lowercased() == RectangleURLs.scheme,
              !store.config.handleRectangleURLs else { return }
        RectangleURLs.setHandled(false)
        model.handleRectangleURLs = RectangleURLs.isHandler
    }
}
