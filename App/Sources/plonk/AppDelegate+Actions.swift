import AppKit

// Everything the UI can ask the app to do. Commands only: a setting needs
// nothing here, because `update` writes any field of Config and applyConfig
// hands the result to every manager. See AppModel for the protocol.

extension AppDelegate: AppActions {

    /// The one path a setting takes from the UI to disk. `ConfigStore` clamps
    /// and saves it, `applyConfig` hands it to whoever needs it. A new setting
    /// therefore adds nothing here, and cannot be saved but left unapplied,
    /// which is the mistake a method per setting made easy to make.
    func update<Value>(_ path: WritableKeyPath<Config, Value>, to value: Value) {
        store.update { $0[keyPath: path] = value }
    }

    /// Keep-awake is held by its manager, not by a stored flag: a hold made by
    /// hand outlives the schedule that would otherwise decide.
    func setAwake(_ on: Bool) { awake.set(on) }

    func setHotkey(_ action: HotkeyAction, to hotkey: Hotkey) {
        // Taking a combination frees it wherever it was, possibly on a page
        // the user is not looking at. Config.bind is where that rule lives.
        var stolen: [HotkeyAction] = []
        store.update { stolen = $0.bind(action, to: hotkey) }
        if let taken = stolen.first {
            HUD.shared.show(.hudHotkeyTaken(hotkey.display, String(localized: taken.title)))
        }
    }

    func clearHotkey(_ action: HotkeyAction) {
        update(\.hotkeys[action.rawValue], to: "")
    }

    func resetHotkeys() {
        update(\.hotkeys, to: [:])
    }

    func capture(_ mode: CaptureMode) {
        runCapture(mode, openEditor: true)
    }

    func flashZones() {
        dragSnap.previewZones()
    }

    func reportBug() {
        guard let url = URL(string: Self.issuesURL) else { return }
        NSWorkspace.shared.open(url)
    }

    func launchWorkspace(named name: String, onScreen screen: Int?) {
        guard let workspace = store.config.workspaces[name] else { return }
        launcher.launch(workspace, named: name, onScreen: screen)
    }

    func deleteWorkspace(named name: String) {
        store.update { $0.workspaces.removeValue(forKey: name) }
    }

    func renameWorkspace(_ old: String, to new: String) -> Bool {
        guard old != new else { return true }
        guard store.config.workspaces[old] != nil, store.config.workspaces[new] == nil else { return false }
        store.update {
            guard let workspace = $0.workspaces.removeValue(forKey: old) else { return }
            $0.workspaces[new] = workspace
        }
        return true
    }

    func saveCurrentWorkspace(named name: String) {
        let items = router.snapshotWorkspace()
        guard !items.isEmpty else { return }
        let moveExisting = store.config.workspaces[name]?.moveExisting ?? true
        store.update { $0.workspaces[name] = Workspace(items: items, moveExisting: moveExisting) }
    }

    func setWorkspaceMoveExisting(_ on: Bool, for name: String) {
        store.update { $0.workspaces[name]?.moveExisting = on }
    }

    func updateWorkspaceItem(_ index: Int, in name: String, urls: [String], args: [String]) {
        store.update {
            guard $0.workspaces[name]?.items.indices.contains(index) == true else { return }
            $0.workspaces[name]?.items[index].urls = urls.isEmpty ? nil : urls
            $0.workspaces[name]?.items[index].args = args.isEmpty ? nil : args
        }
    }

    func removeWorkspaceItem(_ index: Int, from name: String) {
        store.update {
            guard $0.workspaces[name]?.items.indices.contains(index) == true else { return }
            $0.workspaces[name]?.items.remove(at: index)
        }
    }

    func checkForUpdates() {
        updates.check()
    }

    func installUpdate() {
        updates.install()
    }

    func openReleasePage() {
        NSWorkspace.shared.open(updates.available?.pageURL ?? Release.releasesPageURL)
    }
}
