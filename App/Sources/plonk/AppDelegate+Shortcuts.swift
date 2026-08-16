import AppKit

// What the shortcuts pages read. Moved out of AppDelegate, which is over the
// line limit and may only shrink.

extension AppDelegate {
    func refreshHotkeyModel() {
        let bindings = store.config.resolvedHotkeys
        model.hotkeyDisplays = HotkeyAction.allCases.reduce(into: [:]) { result, action in
            result[action.rawValue] = bindings[action]?.display ?? "None"
        }
        model.hotkeyParts = HotkeyAction.allCases.reduce(into: [:]) { result, action in
            result[action.rawValue] = bindings[action]?.parts ?? []
        }
        model.unavailableHotkeys = hotkeys.unavailable.map(\.rawValue)
        // Read back from macOS rather than from config: the setting says what
        // was asked for, and this says what is actually true, which is the
        // thing worth showing next to a switch. See RectangleURLs.
        model.handleRectangleURLs = RectangleURLs.isHandler
    }
}
