import AppKit

// Wiring for the menu bar item: what its dropdown asks the app for, and what
// each entry in it does. One module, one file beside AppDelegate; see
// AGENTS.md.

extension AppDelegate {
    func setupStatusMenu() {
        statusMenu = StatusMenuController()
        statusMenu.isAwakeRequested = { [weak self] in self?.awake.requested ?? false }
        // The grid at the top of the menu is the set the main screen is running
        // now, and clicking a rectangle is the same call ⌃⌥<number> makes.
        statusMenu.zonesOnMainScreen = { [weak self] in
            guard let self else { return [] }
            return store.config.zones(forKeys: ScreenIdentity.keys(forIndex: 0))
        }
        statusMenu.setSummary = { [weak self] in self?.zoneSetSummary() ?? "" }
        statusMenu.onSnapZone = { [weak self] number in self?.commands.snap(toZone: number) }
        statusMenu.onOpenWindow = { [weak self] in self?.openMainWindow() }
        statusMenu.onCaptureRegion = { [weak self] in self?.runCapture(.region, openEditor: true) }
        statusMenu.onToggleAwake = { [weak self] in self?.awake.toggle() }
        statusMenu.onLaunchWorkspace = { [weak self] name in self?.launchWorkspace(named: name, onScreen: nil) }
        statusMenu.onReportBug = { [weak self] in self?.reportBug() }
        statusMenu.agentEntries = { [weak self] in
            guard let self else { return [] }
            var names = agents.onlineNames()
            for adapter in store.config.agentAdapters where !names.contains(adapter.name) {
                names.append(adapter.name)
            }
            if let selected = store.config.selectedAgent, !names.contains(selected) {
                names.append(selected)
            }
            return names.map { ($0, $0 == self.store.config.selectedAgent) }
        }
        statusMenu.isExclusive = { [weak self] in self?.store.config.agentExclusive ?? false }
        statusMenu.hasSelection = { [weak self] in self?.store.config.selectedAgent != nil }
        statusMenu.onSelectAgent = { [weak self] name in self?.update(\.selectedAgent, to: name) }
        statusMenu.onToggleExclusive = { [weak self] in
            guard let self else { return }
            update(\.agentExclusive, to: !store.config.agentExclusive)
        }
        refreshStatusMenu()
    }
}
