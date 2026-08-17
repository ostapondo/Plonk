import AppKit

// The keys, and what the shortcuts pages read.

extension AppDelegate {
    func setupHotkeys() {
        hotkeys.onAction = { [weak self] action in self?.perform(action) }
        hotkeys.onActionUp = { [weak self] action in
            guard action == .voice else { return }
            self?.voice.finishCapture()
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
            dragSnap.previewZones()
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
