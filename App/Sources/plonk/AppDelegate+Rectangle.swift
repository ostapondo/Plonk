import AppKit

// The two ways a Rectangle setup reaches this app: its shortcuts, read once,
// and its URLs, answered as they arrive.
//
// One module, one file beside AppDelegate; see AGENTS.md, "Layout".

extension AppDelegate {
    // MARK: - Shortcuts

    /// Take the bindings that mean the same thing here.
    ///
    /// Reading means a round trip to `cfprefsd` for another app's preferences
    /// and possibly a file off disk, neither of which may happen on the main
    /// queue. Only the applying comes back.
    func importFromRectangle() {
        DispatchQueue.global(qos: .userInitiated).async {
            let found = Self.readRectangleSetup()
            OnMain.run { [weak self] in self?.applyRectangleSetup(found) }
        }
    }

    /// Whether to offer the import on Home, answered once at launch.
    ///
    /// The same read the button does, and just as much off the main queue. Only
    /// asked while the offer is still open, so a Mac that has already answered
    /// does not pay for the round trip at all.
    func noticeRectangle() {
        guard !store.config.rectangleOfferSettled else { return }
        DispatchQueue.global(qos: .utility).async {
            let found = Self.readRectangleSetup()
            let worth = found.map { !$0.bindings.isEmpty || !$0.unmapped.isEmpty } ?? false
            OnMain.run { [weak self] in self?.model.rectangleFound = worth }
        }
    }

    /// Turned down. Settled the same way taking it is, so it is asked once.
    func dismissRectangleOffer() {
        store.update { $0.rectangleOfferSettled = true }
        model.rectangleFound = false
    }

    private func applyRectangleSetup(_ found: RectangleImport.Found?) {
        guard let found, !found.isEmpty else {
            HUD.shared.show(.hudRectangleNothing)
            return
        }
        var displaced: [HotkeyAction] = []
        store.update { config in
            displaced = RectangleImport.apply(found, to: &config)
            // Asked and answered, wherever the button was pressed.
            config.rectangleOfferSettled = true
        }
        model.rectangleFound = false
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
        let left = ListFormatter.localizedString(byJoining: found.unmapped.map(Self.readable))
        if found.bindings.isEmpty {
            // An empty list satisfies every test, so ask whether there is one
            // before asking what is in it: a setup holding nothing but a gap
            // would otherwise be reported as having been all thirds.
            guard !found.unmapped.isEmpty else { return .hudRectangleImported }
            return found.unmapped.allSatisfy(RectangleImport.isFixedGrid)
                ? .hudRectangleGridOnly
                : .hudRectangleNoneMatched(left)
        }
        let taken = ListFormatter.localizedString(
            byJoining: displaced.map { String(localized: $0.title) }
        )
        switch (displaced.isEmpty, found.unmapped.isEmpty) {
        case (true, true): return .hudRectangleImported
        case (true, false): return .hudRectangleLeftBehind(left)
        case (false, true): return .hudRectangleTook(taken)
        // Both, in one sentence: a key that stopped working is the more urgent
        // half, and the page promises the other half is named too.
        case (false, false): return .hudRectangleTookAndLeft(taken, left)
        }
    }

    /// Rectangle's own key for an action, as words. The config stores
    /// `firstThird`, and that is not what anybody calls it.
    private static func readable(_ name: String) -> String {
        name.reduce(into: "") { text, character in
            if character.isUppercase, !text.isEmpty { text.append(" ") }
            text.append(Character(character.lowercased()))
        }
    }

    /// Rectangle's own domain, not the search list `UserDefaults(suiteName:)`
    /// would merge: that folds in this app's preferences and the globals, and
    /// anything in them shaped like a shortcut would be read as Rectangle's.
    private static func readRectangleSetup() -> RectangleImport.Found? {
        if let domain = UserDefaults.standard.persistentDomain(
            forName: RectangleImport.defaultsSuite
        ) {
            // Bindings, not merely something: an installed Rectangle whose only
            // stored value is a gap should not shadow an export with the keys.
            let found = RectangleImport.read(defaults: domain)
            if !found.bindings.isEmpty || !found.unmapped.isEmpty { return found }
        }
        guard let url = RectangleImport.exportedConfigURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return RectangleImport.read(exportedJSON: data)
    }

    // MARK: - URLs

    /// Make what macOS does about `rectangle://` match `config.handleRectangleURLs`.
    ///
    /// Asked when the setting moves and once at launch, not on every write:
    /// asking costs a round trip to `lsd`, and nothing on the launch path may
    /// wait on another process, so it goes off the main queue and the answer
    /// comes back on it. Launch matters because it can drift either way while
    /// the app is not running: LaunchServices hands the scheme over on install
    /// without being asked, and hands it back when Rectangle is reinstalled or
    /// the database is rebuilt. Neither is something the app is told about.
    func applyRectangleURLs(_ config: Config, previous: Config?) {
        let wanted = config.handleRectangleURLs
        guard previous?.handleRectangleURLs != wanted else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            RectangleURLs.setHandled(wanted) { [weak self] holding in
                self?.model.holdsRectangleURLs = holding
            }
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
        // The setting decides whether this app answers, not merely whether it
        // asked for the scheme. Holding one it was handed by accident is not a
        // reason to act on it, and with no Rectangle installed there is nobody
        // to hand it back to — so refusing here is the only thing that makes
        // the switch mean what it says.
        if url.scheme?.lowercased() == RectangleURLs.scheme, !store.config.handleRectangleURLs {
            returnRectangleURLs()
            HUD.shared.show(.hudRectangleUrlsOff)
            return
        }
        switch URLCommand.parse(url) {
        case .success(.action(let action)):
            perform(action)
        case .failure(.fixedGridAction(let name)):
            HUD.shared.show(.hudUrlZoneSet(name))
        case .failure(.heldDownAction(let name)):
            HUD.shared.show(.hudUrlHeldDown(name))
        case .failure(.unknownAction(let name)):
            HUD.shared.show(.hudUrlUnknown(name))
        case .failure(.missingName), .failure(.unknownHost), .failure(.unknownScheme):
            HUD.shared.show(.hudUrlUnreadable)
        }
    }

    /// Declaring a scheme is enough to be handed it, so a `rectangle://` URL
    /// arriving while the setting is off means this app is holding one nobody
    /// asked for. Give it back if there is a Rectangle to take it.
    private func returnRectangleURLs() {
        DispatchQueue.global(qos: .utility).async {
            RectangleURLs.setHandled(false) { [weak self] holding in
                self?.model.holdsRectangleURLs = holding
            }
        }
    }
}
