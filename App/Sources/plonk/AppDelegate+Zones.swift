import AppKit

// Everything the app does to a zone set: which screen wears it, what is in it,
// and the two windows that edit it. One module, one file beside AppDelegate;
// see AGENTS.md.

extension AppDelegate {
    func assignZoneSet(_ name: String?, toScreen index: Int) {
        store.update { $0.assignZoneSet(name, forKeys: ScreenIdentity.keys(forIndex: index)) }
        commands.relayout(screenIndex: index)
    }

    func updateZoneSet(_ name: String, zones: [ZoneRect], gap: Double?) {
        store.update {
            $0.zoneSets[name] = zones
            $0.zoneSetGaps[name] = gap
        }
        for index in NSScreen.screens.indices
        where store.config.zoneAssignment(forKeys: ScreenIdentity.keys(forIndex: index)) == name {
            commands.relayout(screenIndex: index)
        }
        if !presenter.isFullscreenEditorVisible {
            dragSnap.previewZones()
        }
    }

    func renameZoneSet(_ old: String, to new: String) -> Bool {
        guard old != new else { return true }
        guard store.config.zoneSets[old] != nil, store.config.zoneSets[new] == nil else { return false }
        store.update {
            guard let zones = $0.zoneSets.removeValue(forKey: old) else { return }
            $0.zoneSets[new] = zones
            $0.zoneSetGaps[new] = $0.zoneSetGaps.removeValue(forKey: old)
            $0.screenZoneSets = $0.screenZoneSets.mapValues { $0 == old ? new : $0 }
        }
        return true
    }

    func deleteZoneSet(_ name: String) {
        store.update { $0.forgetZoneSet(named: name) }
    }

    func togglePreview(zoneSet name: String, onScreen index: Int) {
        previewToken += 1
        guard model.previewedZoneSet != name else {
            clearPreview()
            return
        }
        guard let zones = store.config.zoneSets[name] ?? BuiltinZoneSets.all[name] else { return }
        dragSnap.showPreview(zones: zones, screenIndex: index,
                             gap: CGFloat(store.config.zoneGap(forSet: name)))
        // Which monitor the set just landed on, said on the monitors. Showing
        // a preview is the one moment the numbers are wanted; nothing else
        // puts them up any more.
        identifyScreens(selected: index)
        model.previewedZoneSet = name

        let token = previewToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self, previewToken == token else { return }
            clearPreview()
        }
    }

    func openZonePicker() {
        presenter.showZonePicker()
    }

    /// The list on top of whatever is on screen, for the screen the cursor is
    /// on: the same screen the ⌃⌥⇧-digit swaps act on, so the two agree about
    /// which monitor "this one" means.
    func openZoneSetPalette() {
        presenter.showZoneSetPalette(screenIndex: ScreenIdentity.indexUnderCursor)
    }

    func editZoneSet(_ name: String, seed: [ZoneRect]?, onScreen index: Int) {
        presenter.showFullscreenEditor(set: name, seed: seed, screenIndex: index)
    }
}
