import AppKit

// The shell around the modules: how the app looks, how a command is run, and
// what happens when someone opens an app that is already running.
//
// None of it is a module in the sense AGENTS.md means, so none of it gets an
// HTTP route or an MCP tool. An agent that wants to change the theme is asking
// the wrong question.

extension AppDelegate {
    /// Opening an app that is already running means "show me your window" —
    /// that is what a Dock click does, and what double-clicking the bundle in
    /// Finder should do. Without this, a menu bar app looks broken: it is
    /// running, and nothing happens.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openMainWindow()
        return true
    }

    func openMainWindow() {
        refreshPermissions()
        presenter.showMainWindow()
    }

    func setTheme(_ name: String) {
        store.update { $0.appearance.theme = name }
        applyAppearance()
        refreshModel()
    }

    func setAccent(_ hex: String?) {
        store.update { $0.appearance.accentHex = hex }
        refreshModel()
        // The overlay and the pointer tools both tint themselves with the accent
        // unless they were given a colour of their own, so a new accent has to
        // reach whatever is on screen now.
        applyMouseSettings()
        flashZones()
    }

    func applyAppearance() {
        store.config.appearance.apply(to: NSApp)
    }

    /// A spoken command, run through the same calls the hotkeys use — so a
    /// sentence cannot reach anything a key could not.
    func run(_ command: VoiceCommand) {
        switch command {
        case .preset(let preset): commands.apply(preset)
        case .zone(let number): commands.snap(toZone: number)
        case .putBack: commands.unsnap()
        case .focus(let direction): commands.moveFocus(direction)
        case .cycleZone: commands.cycleZone(backwards: false)
        case .showZones: dragSnap.previewZones()
        case .awake(let minutes):
            setAwakeTimeout(minutes: minutes ?? 0)
            setAwake(true)
        case .awakeOff: setAwake(false)
        case .capture(let mode): runCapture(mode, openEditor: false)
        case .launchWorkspace(let name): launchWorkspace(named: name, onScreen: nil)
        }
    }

    func openCommandPalette() {
        presenter.showCommandPalette(commands: paletteCommands(),
                                     agent: store.config.selectedAgent) { [weak self] prompt in
            self?.askAgent(prompt)
        }
    }

    /// Whatever was typed into the palette that was not a command. It takes the
    /// same call the voice path makes, so a sentence typed and a sentence spoken
    /// reach the agent by one road and fail in one way.
    func askAgent(_ prompt: String) {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let response = router.dispatch(prompt: text)
        if let error = response.json["error"] as? String {
            HUD.shared.show(error)
        } else {
            let agent = (response.json["agent"] as? String) ?? "agent"
            HUD.shared.show("→ \(agent): \(text)")
        }
    }

    /// Every shortcut acts on whatever window is in front, and while the palette
    /// is up that is Plonk's own. Hiding first hands the front back to the app
    /// the user was actually looking at; the delay is for macOS to finish the
    /// switch, because the accessibility API answers with the old front window
    /// for a beat after `hide` returns.
    private func runOnTheFrontWindow(_ body: @escaping () -> Void) {
        NSApp.hide(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: body)
    }

    /// Everything ⌘K can run, grouped the way the palette shows it.
    ///
    /// Built from the same lists the rest of the app uses — the hotkey actions,
    /// the saved workspaces, the zone sets, the settings pages — so a command
    /// cannot fall out of step with what the app can actually do.
    func paletteCommands() -> [PlonkCommand] {
        var result: [PlonkCommand] = []

        for action in HotkeyAction.allCases {
            result.append(PlonkCommand(id: "hotkey.\(action.rawValue)",
                                       title: action.title,
                                       group: action.group,
                                       keys: model.hotkeyParts[action.rawValue] ?? []) { [weak self] in
                self?.runOnTheFrontWindow { self?.perform(action) }
            })
        }

        for name in model.workspaceNames {
            result.append(PlonkCommand(id: "workspace.\(name)",
                                       title: "Launch workspace “\(name)”",
                                       group: "Workspaces") { [weak self] in
                self?.launchWorkspace(named: name, onScreen: nil)
            })
        }

        for name in model.zoneSetNames {
            // The main screen, said out loud: the palette has no cursor to read
            // a screen from the way the shortcut does.
            result.append(PlonkCommand(id: "zoneset.\(name)",
                                       title: "Use zone set “\(name)” on the main screen",
                                       group: "Zone sets") { [weak self] in
                self?.assignZoneSet(name, toScreen: 0)
            })
        }

        result.append(PlonkCommand(id: "app.editZones", title: "Edit zone sets…",
                                   group: "Zone sets") { [weak self] in
            self?.openZonePicker()
        })
        result.append(PlonkCommand(id: "app.awake",
                                   title: awake.requested ? "Stop keeping the Mac awake"
                                                          : "Keep the Mac awake",
                                   group: "Gadgets") { [weak self] in
            guard let self else { return }
            setAwake(!awake.requested)
        })
        result.append(PlonkCommand(id: "app.update", title: "Check for updates",
                                   group: "Gadgets") { [weak self] in
            self?.checkForUpdates()
        })

        for page in SettingsPages.all {
            result.append(PlonkCommand(id: "page.\(page.id)",
                                       title: "Open \(page.title)",
                                       group: "Settings") { [weak self] in
                self?.openPage(page.id)
            })
        }

        return result
    }
}
