import Foundation

// Reading a Rectangle setup, so that trying Plonk costs nothing.
//
// Rectangle keeps every binding as two numbers — a virtual key code and
// NSEvent modifier flags — under the action's own name. That is true in both
// places it stores them: the RectangleConfig.json its Settings tab exports,
// and the live preferences of an installed copy. So one parser reads either.
//
// Only the actions that mean the same thing in both apps are carried over.
// Rectangle's thirds, fourths, sixths, eighths and ninths are left behind on
// purpose: those are a fixed grid, the Plonk equivalent is a zone set, and
// "first third" is zone 1 only on a screen that happens to be using Thirds.
// Binding a key on that guess would put windows somewhere wrong on every
// other screen. They are reported instead, and docs/from-rectangle.md says
// what to do with them.

enum RectangleImport {
    /// What one read of a Rectangle setup found.
    struct Found: Equatable {
        var bindings: [HotkeyAction: Hotkey] = [:]
        /// Rectangle actions that hold a usable key but have no counterpart
        /// here, by Rectangle's own name. Named rather than guessed at.
        var unmapped: [String] = []
        /// Rectangle's window gap, in points.
        var gapPoints: Double?

        var isEmpty: Bool { bindings.isEmpty && gapPoints == nil }
    }

    /// The actions that mean the same thing in both apps.
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
        // Rectangle calls it restore, and it does what ⌃⌥0 does here: give the
        // window back the frame it had before any of this touched it.
        "restore": .unsnap,
    ]

    /// The domain an installed Rectangle writes its preferences to.
    static let defaultsSuite = "com.knollsoft.Rectangle"

    /// Where Rectangle's own export button leaves its file, and where an
    /// installed copy would read one back from.
    static var exportedConfigURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Rectangle", isDirectory: true)
            .appendingPathComponent("RectangleConfig.json")
    }

    // MARK: - Reading

    /// Rectangle's exported config, from the button on its Settings tab.
    /// Nil when the file is not that: a missing `shortcuts` object is the one
    /// thing every version of the export has.
    static func read(exportedJSON data: Data) -> Found? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let shortcuts = root["shortcuts"] as? [String: Any] else { return nil }
        var found = read(shortcuts: shortcuts)
        // Every exported default is wrapped in the type it was stored as, so
        // the gap arrives as {"float": 8} rather than as a bare number.
        if let defaults = root["defaults"] as? [String: Any],
           let gap = defaults["gapSize"] as? [String: Any] {
            found.gapPoints = ["float", "double", "int"]
                .compactMap { (gap[$0] as? NSNumber)?.doubleValue }
                .first
        }
        return found
    }

    /// The live preferences of an installed Rectangle, as read out of its own
    /// defaults domain. Unrelated keys are ignored rather than rejected, since
    /// this is handed a whole domain and most of it is not a shortcut.
    static func read(defaults values: [String: Any]) -> Found {
        var found = read(shortcuts: values)
        if let gap = (values["gapSize"] as? NSNumber)?.doubleValue { found.gapPoints = gap }
        return found
    }

    private static func read(shortcuts: [String: Any]) -> Found {
        var found = Found()
        // Sorted so that a file listing the same key twice, or two actions
        // sharing one combination, resolves the same way every run.
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
    /// Rectangle writes a negative key code for an action it has deliberately
    /// unbound, and its flags carry whatever else AppKit reported at the time —
    /// caps lock, the function bit an arrow key sets — so only the four
    /// modifiers a global hotkey can actually hold are read. A key this app has
    /// no name for is left behind rather than bound to something it could not
    /// draw or re-record.
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

    // NSEvent.ModifierFlags raw values, written out rather than imported. This
    // parses a file someone else wrote, and the numbers in that file are fixed
    // whatever AppKit decides to call them.
    private static let shiftFlag: UInt = 1 << 17
    private static let controlFlag: UInt = 1 << 18
    private static let optionFlag: UInt = 1 << 19
    private static let commandFlag: UInt = 1 << 20

    // MARK: - Applying

    /// Fold a read into a config, and name whatever it displaced.
    ///
    /// A combination can only drive one action, so an imported key frees
    /// whatever of Plonk's own was sitting on it — the same rule the shortcut
    /// recorder follows, and the reason this returns a list instead of doing it
    /// quietly. An action that gets a key of its own later in the same import
    /// is not displaced, so it does not appear.
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
