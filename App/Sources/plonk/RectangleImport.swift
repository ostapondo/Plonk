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
        /// Rectangle actions that were bound to something and did not come
        /// across, by Rectangle's own name. Either there is no counterpart
        /// here, or the key itself has no name in `Hotkey`'s table.
        var unmapped: [String] = []
        /// Rectangle's window gap, in points.
        var gapPoints: Double?

        /// Nothing was found at all — as opposed to something being found and
        /// none of it coming across, which `unmapped` is how you tell.
        var isEmpty: Bool { bindings.isEmpty && unmapped.isEmpty && gapPoints == nil }
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

    /// Whether a Rectangle action name is one of its fixed fractions of the
    /// screen, which is a zone set here.
    ///
    /// Matched on the end of the name rather than against a copy of
    /// Rectangle's enum, which has grown twelfths, sixteenths and vertical
    /// thirds and will grow more. Case and hyphens are ignored so the same
    /// rule reads `firstThird` from a config file and `first-third` from a URL.
    ///
    /// Halves are missing on purpose: four of the five end in `Half` and all
    /// four are imported. Rectangle's own centre half is the exception, and it
    /// is named.
    static func isFixedGrid(_ name: String) -> Bool {
        let plain = name.lowercased().replacingOccurrences(of: "-", with: "")
        if plain == "centerhalf" || plain == "centersection" { return true }
        return fractions.contains { plain.hasSuffix($0) || plain.hasSuffix($0 + "s") }
    }

    private static let fractions = [
        "third", "fourth", "fifth", "sixth", "eighth", "ninth", "twelfth", "sixteenth",
    ]

    /// The path Rectangle itself reads a config back from on launch.
    ///
    /// Not where its export button writes: that opens a save panel, so the
    /// file lands wherever the user pointed it. This is the one path both apps
    /// agree on, which is why docs/from-rectangle.md says to move it here.
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
                  let flags = (entry["modifierFlags"] as? NSNumber)?.uintValue
            else { continue }
            // Rectangle writes a negative key code for an action it has
            // unbound. Nothing was there, so nothing is missing.
            if keyCode < 0 { continue }
            guard let action = equivalents[name],
                  let hotkey = hotkey(keyCode: keyCode, modifierFlags: flags)
            else {
                found.unmapped.append(name)
                continue
            }
            found.bindings[action] = hotkey
        }
        return found
    }

    /// One Rectangle binding as a Plonk one, or nil when it cannot be.
    ///
    /// The flags carry whatever else AppKit reported at the time — caps lock,
    /// the function bit an arrow key sets — so only the four a global hotkey
    /// can hold are read. A key with no name in Hotkey's table cannot be shown
    /// or re-recorded, so it is refused here and reported by the caller.
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
            for other in config.bind(action, to: hotkey) where !displaced.contains(other) {
                displaced.append(other)
            }
        }
        // Whether an action still has a key, not whether it was in the import:
        // two imported actions sharing a combination leaves the earlier one
        // cleared, and it deserves the same notice as anything else.
        let resolved = config.resolvedHotkeys
        displaced.removeAll { resolved[$0] != nil }
        if let points = found.gapPoints { config.setGap(points) }
        return displaced
    }
}
