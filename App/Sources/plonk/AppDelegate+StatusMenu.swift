import AppKit

// Wiring for the menu bar item: what its dropdown asks the app for, and what
// each entry in it does. One module, one file beside AppDelegate; see
// AGENTS.md.

extension AppDelegate {
    func setupStatusMenu() {
        statusMenu = StatusMenuController()
        statusMenu.isAwakeRequested = { [weak self] in self?.awake.requested ?? false }
        statusMenu.isFeatureEnabled = { [weak self] feature in self?.store.config.isEnabled(feature) ?? true }
        statusMenu.onToggleFeature = { [weak self] feature, on in
            self?.store.update { $0.setEnabled(feature, on) }
        }
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
