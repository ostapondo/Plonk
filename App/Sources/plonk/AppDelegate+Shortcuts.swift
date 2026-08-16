import AppKit

// The keys, and what the shortcuts pages read. Moved out of AppDelegate,
// which is over the line limit and may only shrink.

extension AppDelegate {
    func setupHotkeys() {
        hotkeys.onAction = { [weak self] action in self?.perform(action) }
        hotkeys.onActionUp = { [weak self] action in
            guard action == .voice else { return }
            self?.voice.finishCapture()
        }
        hotkeys.bindings = store.config.resolvedHotkeys
        if store.config.hotkeysEnabled { hotkeys.setEnabled(true) }
        refreshHotkeyModel()
        reconcileRectangleURLs()
    }

    func refreshHotkeyModel() {
        let bindings = store.config.resolvedHotkeys
        model.hotkeyDisplays = HotkeyAction.allCases.reduce(into: [:]) { result, action in
            result[action.rawValue] = bindings[action]?.display
                ?? String(localized: .shortcutUnbound)
        }
        model.hotkeyParts = HotkeyAction.allCases.reduce(into: [:]) { result, action in
            result[action.rawValue] = bindings[action]?.parts ?? []
        }
        model.unavailableHotkeys = hotkeys.unavailable.map(\.rawValue)
    }

    /// Make what macOS does about `rectangle://` match what the setting says,
    /// once, at launch.
    ///
    /// It can drift either way while the app is not running: LaunchServices
    /// hands the scheme over on install without being asked, and hands it back
    /// when Rectangle is reinstalled or the database is rebuilt. Neither is
    /// something the app is told about, so the only reliable moment to check is
    /// the next start.
    ///
    /// Off the main queue because asking costs a round trip to `lsd`, and
    /// nothing on the launch path may wait on another process.
    private func reconcileRectangleURLs() {
        let wanted = store.config.handleRectangleURLs
        DispatchQueue.global(qos: .utility).async {
            RectangleURLs.setHandled(wanted) { [weak self] holding in
                self?.model.handleRectangleURLs = holding
            }
        }
    }
}
