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
        // Named rather than counted: which key went is the useful half.
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
        // Read back rather than assume: the switch shows what macOS did.
        model.handleRectangleURLs = RectangleURLs.isHandler
    }

    /// `open -g "plonk://execute-action?name=left-half"`.
    ///
    /// A URL that names nothing gets a HUD rather than silence. The caller is a
    /// script with nowhere to receive an error, so the screen is the only place
    /// left to report one.
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
    /// was won by accident, which declaring it is enough to do. Hand it back,
    /// and still run this one rather than drop it.
    ///
    /// The only moment that mistake is observable, so the only place to check.
    private func returnRectangleURLsIfUnwanted(_ url: URL) {
        guard url.scheme?.lowercased() == RectangleURLs.scheme,
              !store.config.handleRectangleURLs else { return }
        RectangleURLs.setHandled(false)
        model.handleRectangleURLs = RectangleURLs.isHandler
    }
}
