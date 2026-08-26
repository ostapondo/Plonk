import AppKit

// The keys, and what the shortcuts pages read.

extension AppDelegate {
    func setupHotkeys() {
        hotkeys.onAction = { [weak self] action in
            // The key going down puts the zones up; the key coming back up,
            // below, lets them linger. Everything else is the same from a key
            // as from a URL or the palette.
            if action == .showZones {
                self?.beginZonePick()
            } else {
                self?.perform(action)
            }
        }
        hotkeys.onActionUp = { [weak self] action in
            switch action {
            case .voice: self?.voice.finishCapture()
            case .showZones: self?.dragSnap.endPick()
            default: break
            }
        }
        hotkeys.apply(store.config)
        noticeRectangle()
    }

    /// How the bindings read on the shortcuts pages, off what the manager
    /// holds: the resolved set, so nothing is parsed a second time.
    func refreshHotkeyModel() {
        let bindings = hotkeys.bindings
        model.hotkeyDisplays = HotkeyAction.allCases.reduce(into: [:]) { result, action in
            result[action.rawValue] = bindings[action]?.display
                ?? String(localized: .shortcutUnbound)
        }
        model.hotkeyParts = HotkeyAction.allCases.reduce(into: [:]) { result, action in
            result[action.rawValue] = bindings[action]?.parts ?? []
        }
        model.unavailableHotkeys = hotkeys.unavailable.map(\.rawValue)
    }

    func perform(_ action: HotkeyAction) {
        switch action {
        case .showZones:
            // From a URL or the palette there is no key to hold, so the zones
            // come up and linger the way they do after a key is let go.
            beginZonePick()
            dragSnap.endPick()
        case .captureRegion:
            runCapture(.region, openEditor: true)
        case .captureText:
            captureText()
        case .voice:
            voice.beginCapture()
        case .unsnap:
            commands.unsnap()
        case .cycleZone:
            commands.cycleZone(backwards: false)
        case .cycleZoneBack:
            commands.cycleZone(backwards: true)
        case .findCursor:
            mouse.flashSpotlight()
        case .jumpCursor:
            if !mouse.jumpToNextScreen() { HUD.shared.show(.hudOneScreenOnly) }
        case .cropLive:
            pinCrop(live: true)
        case .cropStill:
            pinCrop(live: false)
        case .ruler:
            startRuler()
        case .shortcutGuide:
            toggleShortcutGuide()
        case .commandPalette:
            openCommandPalette()
        case .zoneSetPalette:
            openZoneSetPalette()
        default:
            if let number = action.zoneNumber {
                commands.snap(toZone: number)
                // Pressed while the zones were up to be clicked, the digit
                // was the pick.
                dragSnap.cancelPick()
            } else if let number = action.layoutNumber {
                commands.applyZoneSet(number: number, named: model.zoneSetNames) { [weak self] name, screen in
                    self?.assignZoneSet(name, toScreen: screen)
                }
            } else if let direction = action.focusDirection {
                commands.moveFocus(direction)
            } else if let preset = action.preset {
                commands.apply(preset)
            }
        }
    }

    /// ⌃⌥Z went down: the zones, up to be clicked, for the window that is in
    /// front now. An excluded app, or nothing in front, gets the plain flash.
    func beginZonePick() {
        let target = NSWorkspace.shared.frontmostApplication.flatMap { app in
            isExcluded(app) ? nil : windows.focusedWindow(of: app)
        }
        dragSnap.beginPick(target: target)
    }

    /// Reads the front app's menus and floats them. Pressing the key again
    /// closes it, which is how a reference panel should behave.
    func toggleShortcutGuide() {
        if let panel = guidePanel {
            panel.close()
            return
        }
        // Reading a big app's menus takes a moment; a second press inside that
        // window would build a second panel and orphan the first.
        guard !guideLoading else { return }
        guard windows.isTrusted else {
            HUD.shared.show(.hudGuideNeedsAccessibility)
            return
        }
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let name = app.localizedName ?? String(localized: .guideThisApp)
        guideLoading = true
        ShortcutGuide.read(for: app) { [weak self] items in
            guard let self else { return }
            guideLoading = false
            // The guide describes whatever was in front when it was asked for,
            // so a slow app cannot end up labelled with the wrong name.
            let panel = ShortcutGuidePanel(appName: name, items: items)
            panel.onClose = { [weak self] in self?.guidePanel = nil }
            guidePanel = panel
            panel.orderFrontRegardless()
        }
    }
}
