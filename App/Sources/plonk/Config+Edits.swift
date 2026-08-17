import Foundation

// The rules about changing a config that more than one caller needs, kept here
// rather than at each call site. The settings page, an agent and the Rectangle
// importer all write the same fields, and a rule spelled out three times is a
// rule that will only be fixed in one of them.

extension Config {
    /// The most gap anything may set, wherever it is set from: the slider, an
    /// agent, or a Rectangle config being read in.
    static let gapLimit = 40.0
    /// The most a drop may reach past a zone's edge to cover its neighbour.
    static let edgeSpanLimit = 60.0
    /// Fully transparent zones would be a set the user cannot see to fix.
    static let opacityRange = 0.1...1.0

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

    /// Every bound a setting has, in one place. `ConfigStore` runs it after
    /// each change and once on load, so a range holds however the value
    /// arrived: a slider, an agent over the API, a Rectangle config being read
    /// in, or config.json edited by hand. No caller has to remember a limit,
    /// which is what kept the same clamp written out at three call sites.
    mutating func clamp() {
        zoneGap = min(max(zoneGap, 0), Self.gapLimit)
        zoneOpacity = min(max(zoneOpacity, Self.opacityRange.lowerBound),
                          Self.opacityRange.upperBound)
        zoneEdgeSpanPoints = min(max(zoneEdgeSpanPoints, 0), Self.edgeSpanLimit)
        rulerEdgeTolerance = min(max(rulerEdgeTolerance, EdgeDetector.toleranceRange.lowerBound),
                                 EdgeDetector.toleranceRange.upperBound)
        awakeTimeoutMinutes = max(0, awakeTimeoutMinutes)
        activeTimeoutMinutes = max(0, activeTimeoutMinutes)
        // Only when Vision answered. It reports nothing when it cannot start,
        // and dropping every language the user chose because a framework was
        // unavailable this once would be a setting silently thrown away.
        let supported = TextExtractor.supportedLanguages
        if !supported.isEmpty {
            textLanguages = textLanguages.filter(supported.contains)
        }
    }
}
