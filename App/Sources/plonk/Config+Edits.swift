import Foundation

// Two rules about changing a config that more than one caller needs, kept
// here rather than at each call site. The settings page, an agent and the
// Rectangle importer all write the same fields, and a rule spelled out three
// times is a rule that will only be fixed in one of them.

extension Config {
    /// The most gap anything may set, wherever it is set from: the slider, an
    /// agent, or a Rectangle config being read in.
    static let gapLimit = 40.0

    /// Bind an action, freeing the combination wherever else it was, and
    /// return what lost it. A combination can only drive one action, so this
    /// is the one place that rule lives; setHotkey and RectangleImport.apply
    /// both go through it.
    @discardableResult
    mutating func bind(_ action: HotkeyAction, to hotkey: Hotkey) -> [HotkeyAction] {
        let resolved = resolvedHotkeys
        let stolen = HotkeyAction.allCases.filter { $0 != action && resolved[$0] == hotkey }
        for other in stolen { hotkeys[other.rawValue] = "" }
        hotkeys[action.rawValue] = hotkey.spec
        return stolen
    }

    /// The gap, held inside the bounds every caller shares.
    mutating func setGap(_ points: Double) {
        zoneGap = max(0, min(points, Self.gapLimit))
    }
}
