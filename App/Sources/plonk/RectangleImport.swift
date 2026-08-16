import Foundation

// Reading a Rectangle setup.
//
// Rectangle stores each binding as two numbers, a virtual key code and NSEvent
// modifier flags, under the action's own name. That holds in both places it
// keeps them — the RectangleConfig.json its Settings tab exports, and the live
// preferences of an installed copy — so one parser reads either.
//
// Only actions that mean the same thing in both apps are carried over.
// Rectangle's thirds, fourths, sixths, eighths and ninths are a fixed grid and
// the equivalent here is a zone set, so "first third" is zone 1 only on a
// screen currently using Thirds. Those are reported by name instead.

enum RectangleImport {
    /// What one read of a Rectangle setup found.
    struct Found: Equatable {
        var bindings: [HotkeyAction: Hotkey] = [:]
        /// Rectangle actions that hold a usable key but have no counterpart
        /// here, by Rectangle's own name.
        var unmapped: [String] = []
        /// Rectangle's window gap, in points.
        var gapPoints: Double?

        var isEmpty: Bool { bindings.isEmpty && gapPoints == nil }
    }

    static let equivalents: [String: HotkeyAction] = [
        "leftHalf": .leftHalf,
        "rightHalf": .rightHalf,
        "topHalf": .topHalf,
        "bottomHalf": .bottomHalf,
        "topLeft": .topLeft,
        "topRight": .topRight,
        "bottomLeft": .bottomLeft,
        "bottomRight": .bottomRight,
        "maximize": .maximize,
        "center": .center,
        // Rectangle's name for what ⌃⌥0 does here.
        "restore": .unsnap,
    ]

    static let defaultsSuite = "com.knollsoft.Rectangle"

    /// Where Rectangle's Settings tab leaves its export.
    static var exportedConfigURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Rectangle", isDirectory: true)
            .appendingPathComponent("RectangleConfig.json")
    }

    // MARK: - Reading

    /// Nil when the file is not an export: every version of one has a
    /// `shortcuts` object, so its absence is the cheapest thing to check.
    static func read(exportedJSON data: Data) -> Found? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let shortcuts = root["shortcuts"] as? [String: Any] else { return nil }
        var found = read(shortcuts: shortcuts)
        // Exported defaults are wrapped in the type they were stored as, so
        // the gap arrives as {"float": 8} rather than as a bare number.
        if let defaults = root["defaults"] as? [String: Any],
           let gap = defaults["gapSize"] as? [String: Any] {
            found.gapPoints = ["float", "double", "int"]
                .compactMap { (gap[$0] as? NSNumber)?.doubleValue }
                .first
        }
        return found
    }

    /// The live preferences of an installed Rectangle. This is handed a whole
    /// defaults domain, most of which is not a shortcut, so unrelated keys are
    /// skipped rather than treated as an error.
    static func read(defaults values: [String: Any]) -> Found {
        var found = read(shortcuts: values)
        if let gap = (values["gapSize"] as? NSNumber)?.doubleValue { found.gapPoints = gap }
        return found
    }

    private static func read(shortcuts: [String: Any]) -> Found {
        var found = Found()
        // Sorted so two actions sharing one combination resolve the same way
        // every run rather than by dictionary order.
        for (name, value) in shortcuts.sorted(by: { $0.key < $1.key }) {
            guard let entry = value as? [String: Any],
                  let keyCode = (entry["keyCode"] as? NSNumber)?.intValue,
                  let flags = (entry["modifierFlags"] as? NSNumber)?.uintValue,
                  let hotkey = hotkey(keyCode: keyCode, modifierFlags: flags)
            else { continue }
            if let action = equivalents[name] {
                found.bindings[action] = hotkey
            } else {
                found.unmapped.append(name)
            }
        }
        return found
    }

    /// One Rectangle binding as a Plonk one, or nil when it cannot be.
    ///
    /// Rectangle writes a negative key code for an action it has unbound. Its
    /// flags carry whatever else AppKit reported at the time — caps lock, the
    /// function bit an arrow key sets — so only the four a global hotkey can
    /// hold are read, and a key with no name in Hotkey's table is dropped.
    static func hotkey(keyCode: Int, modifierFlags: UInt) -> Hotkey? {
        guard keyCode >= 0, keyCode <= Int(UInt32.max) else { return nil }
        let code = UInt32(keyCode)
        guard Hotkey.name(for: code) != nil else { return nil }
        let hotkey = Hotkey(
            keyCode: code,
            control: modifierFlags & controlFlag != 0,
            option: modifierFlags & optionFlag != 0,
            shift: modifierFlags & shiftFlag != 0,
            command: modifierFlags & commandFlag != 0
        )
        return hotkey.hasModifier ? hotkey : nil
    }

    // NSEvent.ModifierFlags raw values. Written out because they are what is
    // in the file, not because AppKit is unavailable.
    private static let shiftFlag: UInt = 1 << 17
    private static let controlFlag: UInt = 1 << 18
    private static let optionFlag: UInt = 1 << 19
    private static let commandFlag: UInt = 1 << 20

    // MARK: - Applying

    /// Fold a read into a config, and return whatever it displaced.
    ///
    /// A combination can only drive one action, so an imported key frees
    /// whatever was on it, the same rule setHotkey follows. An action that
    /// gets a key of its own later in the same import is not displaced.
    @discardableResult
    static func apply(_ found: Found, to config: inout Config) -> [HotkeyAction] {
        var displaced: [HotkeyAction] = []
        for (action, hotkey) in found.bindings.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            for other in HotkeyAction.allCases
            where other != action && config.resolvedHotkeys[other] == hotkey {
                config.hotkeys[other.rawValue] = ""
                if !displaced.contains(other) { displaced.append(other) }
            }
            config.hotkeys[action.rawValue] = hotkey.spec
        }
        displaced.removeAll { found.bindings[$0] != nil }
        if let points = found.gapPoints {
            config.zoneGap = max(0, min(points, Config.gapLimit))
        }
        return displaced
    }
}
