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
        // The same key closes it. Reopening instead would rebuild the window
        // with an empty field, throwing away a half-typed sentence for anyone
        // who pressed it twice wondering whether it had registered.
        if presenter.isCommandPaletteOpen {
            presenter.closeCommandPalette()
            return
        }
        presenter.showCommandPalette(commands: paletteCommands(),
                                     agent: store.config.selectedAgent) { [weak self] prompt in
            self?.askAgent(prompt)
        }
    }

    /// Runs a CLI adapter for a prompt, and says on screen how it went.
    ///
    /// The process can take the better part of a minute, so "it started" and
    /// "it worked" are different pieces of news and both have to be delivered.
    /// Before this only the first one was, for two seconds, and a failure was
    /// an NSLog nobody reads — which from the palette looked exactly like a
    /// window closing and nothing happening.
    func launchAdapter(_ adapter: AgentAdapter, prompt: String) {
        let invocation = AgentAdapter.invocation(command: adapter.command, prompt: prompt)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", invocation.command]
        process.environment = ProcessInfo.processInfo.environment
            .merging(invocation.environment) { _, prompt in prompt }

        // A file, not a pipe. A pipe nobody is reading fills at about 64 KB and
        // the adapter blocks on the write for ever — and `claude -p` printing
        // its answer clears that easily, so attaching one and reading it only
        // after exit produces exactly the hang this is supposed to report.
        // Draining it concurrently would work and needs a lock and a reader;
        // a file cannot block, and the tail is all the HUD ever shows.
        let errorLog = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("plonk-adapter-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: errorLog.path, contents: nil)
        let errors = try? FileHandle(forWritingTo: errorLog)
        process.standardError = errors ?? FileHandle.nullDevice
        // Discarded outright: nothing reads it, and that is the same trap.
        process.standardOutput = FileHandle.nullDevice

        // A ticking HUD for as long as it runs. The agent takes tens of seconds
        // and moves nothing until it has decided what to move, so without this
        // the whole middle of the job looks identical to nothing happening —
        // which is exactly what it was mistaken for. The count is what makes it
        // readable as progress rather than as a stuck label.
        let started = Date()
        var ticks = 0
        var progress: Timer?
        // Belt and braces. Both halves are queued on the main thread and the
        // start is queued first, so FIFO already orders them; this is here so
        // that stays true if either one ever moves.
        var done = false
        let beat = {
            ticks += 1
            let dots = String(repeating: "·", count: 1 + ticks % 3)
            let seconds = Int(Date().timeIntervalSince(started).rounded())
            // Longer than the interval, so the panel never blinks out between
            // beats, and short enough to clear itself if this stops ticking.
            HUD.shared.show("\(adapter.name) is working \(dots)  \(seconds)s", duration: 3)
        }
        let stop = {
            done = true
            progress?.invalidate()
            progress = nil
        }

        DispatchQueue.main.async {
            guard !done else { return }
            beat()
            progress = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in beat() }
        }

        process.terminationHandler = { finished in
            try? errors?.close()
            let complaint = (try? String(contentsOf: errorLog, encoding: .utf8)) ?? ""
            try? FileManager.default.removeItem(at: errorLog)
            let last = complaint.split(separator: "\n").last.map(String.init) ?? ""
            let seconds = Int(Date().timeIntervalSince(started).rounded())
            DispatchQueue.main.async {
                stop()
                if finished.terminationStatus == 0 {
                    HUD.shared.show("✓ \(adapter.name) finished in \(seconds)s")
                } else {
                    HUD.shared.show("✗ \(adapter.name) failed (\(finished.terminationStatus))"
                                    + (last.isEmpty ? "" : ": \(last.prefix(70))"))
                }
            }
        }

        // Adapters may run for minutes, so they never touch the main thread.
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
            } catch {
                // terminationHandler never runs for a process that never ran,
                // so the ticking has to be stopped from here or it ticks for ever.
                DispatchQueue.main.async {
                    stop()
                    HUD.shared.show("\(adapter.name) would not start: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Whatever was typed into the palette that was not a command. It takes the
    /// same call the voice path makes, so a sentence typed and a sentence spoken
    /// reach the agent by one road and fail in one way.
    func askAgent(_ prompt: String) {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let response = router.dispatch(prompt: text)
        let agent = (response.json["agent"] as? String) ?? "agent"
        if response.json["error"] != nil {
            // Router answers an API caller, and tells it to pass an "agent"
            // field. There is no field here — there is a menu.
            HUD.shared.show(store.config.selectedAgent == nil
                            ? "No active agent. Pick one from the menu bar first."
                            : (response.json["error"] as? String ?? "That did not go anywhere"))
        } else if let note = response.json["note"] as? String {
            // Queued for a session that has never connected. Saying "→ agent"
            // here would be the silent success this was meant to stop.
            HUD.shared.show("Waiting for \(agent) to connect: \(note)")
        } else {
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

        // Every action but the one that opened this. Running it would hide the
        // window to reach the front app and then reopen the palette on top of
        // nothing, which is a loop with a side effect.
        for action in HotkeyAction.allCases where action != .commandPalette {
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

        result.append(PlonkCommand(id: "app.zoneSetPalette",
                                   title: "Pick a zone set for this screen…",
                                   group: "Zone sets") { [weak self] in
            self?.openZoneSetPalette()
        })
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
