import AppKit

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
    /// What the pointer tools may be tuned to. Bounded rather than free,
    /// because all of this is drawn over every display at once: a ring the
    /// width of a desk, or a fade of zero, is a setting that hides the thing
    /// you would change it back with.
    static let clickRadiusRange = 8.0...160.0
    static let clickLineWidthRange = 1.0...12.0
    static let clickFadeRange = 0.08...0.8
    static let crosshairLineWidthRange = 1.0...8.0
    static let spotlightRadiusRange = 40.0...400.0
    /// Dimming the desk to nothing hides it; dimming it fully hides the rest
    /// of the screen for as long as the flash lasts.
    static let dimRange = 0.1...0.95

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
        zoneGap = zoneGap.clamped(to: 0...Self.gapLimit)
        zoneSetGaps = zoneSetGaps.mapValues { $0.clamped(to: 0...Self.gapLimit) }
        zoneOpacity = zoneOpacity.clamped(to: Self.opacityRange)
        zoneEdgeSpanPoints = zoneEdgeSpanPoints.clamped(to: 0...Self.edgeSpanLimit)
        clickRadius = clickRadius.clamped(to: Self.clickRadiusRange)
        clickLineWidth = clickLineWidth.clamped(to: Self.clickLineWidthRange)
        clickFadeSeconds = clickFadeSeconds.clamped(to: Self.clickFadeRange)
        crosshairLineWidth = crosshairLineWidth.clamped(to: Self.crosshairLineWidthRange)
        crosshairOpacity = crosshairOpacity.clamped(to: Self.opacityRange)
        spotlightRadius = spotlightRadius.clamped(to: Self.spotlightRadiusRange)
        spotlightDim = spotlightDim.clamped(to: Self.dimRange)
        rulerEdgeTolerance = rulerEdgeTolerance.clamped(to: EdgeDetector.toleranceRange)
        awakeTimeoutMinutes = max(0, awakeTimeoutMinutes)
        // A rule with nothing to match, a zone below one, or the same app
        // twice is a line a hand-edited file can produce and nothing can act
        // on: one rule per app, the first one kept, trimmed. There is no
        // upper bound on the zone, because a set can hold any number and a
        // rule for one the set lacks is simply not followed.
        var seen = Set<String>()
        appRules = appRules.compactMap { rule in
            var kept = rule
            kept.app = rule.app.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !kept.app.isEmpty, seen.insert(AppRules.normalized(kept.app)).inserted else { return nil }
            kept.zone = max(1, kept.zone)
            if kept.screenUUID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { kept.screenUUID = nil }
            return kept
        }
        // A hand-edited file can name a feature twice or one that does not
        // exist; the list is kept to known ids, each once, in a fixed order.
        disabledFeatures = Feature.allCases.map(\.rawValue).filter(disabledFeatures.contains)
    }

    /// The key a modifier name stands for. Config stores the name because that
    /// is what a person reads in the file; what it means is Config's to say, so
    /// drag snapping and grab-and-move cannot disagree about it. Anything
    /// unrecognised is shift, which a hand-edited file can produce.
    static func modifierFlag(_ name: String) -> NSEvent.ModifierFlags {
        switch name {
        case "option": return .option
        case "control": return .control
        case "command": return .command
        default: return .shift
        }
    }

    var zonesModifierFlag: NSEvent.ModifierFlags { Self.modifierFlag(zonesModifier) }
    var grabMoveModifierFlag: NSEvent.ModifierFlags { Self.modifierFlag(grabMoveModifier) }

    // textLanguages is deliberately not here. What Vision will recognise is a
    // fact about this Mac, not a bound on the setting: config.json is meant to
    // be synced by hand, and a language chosen on a Mac that has the model
    // would be deleted from the file by the first save on a Mac that does not.
    // The picker only offers what is supported, and TextExtractor.recognize
    // names an unsupported tag back to the caller, which is a better answer
    // than a setting that quietly disappears.
}
