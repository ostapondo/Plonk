import AppKit

// Menu bar tidy wiring: config in, the item list and the chevron's state out.

extension AppDelegate {
    func setupMenuBar() {
        menuBar.apply(store.config)
        // A click on the chevron is the user deciding, so it outlives a
        // relaunch the same way keep-awake does.
        menuBar.onToggle = { [weak self] collapsed in
            guard let self, store.config.menuBarCollapsed != collapsed else { return }
            store.update { $0.menuBarCollapsed = collapsed }
        }
    }

    /// Re-read over Accessibility. Only ever on demand: the page opening or
    /// the user asking.
    func refreshMenuBarModel() {
        model.menuBarItems = menuBar.enabled ? menuBar.items() : []
    }
}
