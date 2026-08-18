import AppKit
import Carbon.HIToolbox

// A key combination, stored in config as a readable spec like
// "control+option+s" so it stays hand-editable, and shown as ⌃⌥S.

struct Hotkey: Equatable {
    var keyCode: UInt32
    var control = false
    var option = false
    var shift = false
    var command = false

    var carbonModifiers: UInt32 {
        var flags: UInt32 = 0
        if control { flags |= UInt32(controlKey) }
        if option { flags |= UInt32(optionKey) }
        if shift { flags |= UInt32(shiftKey) }
        if command { flags |= UInt32(cmdKey) }
        return flags
    }

    var hasModifier: Bool { control || option || shift || command }

    /// What the user sees, in the order macOS writes modifiers.
    var display: String { parts.joined() }

    /// Each key on its own, for drawing them as separate caps.
    var parts: [String] {
        var keys: [String] = []
        if control { keys.append("⌃") }
        if option { keys.append("⌥") }
        if shift { keys.append("⇧") }
        if command { keys.append("⌘") }
        keys.append(Self.symbol(for: keyCode) ?? "?")
        return keys
    }

    var spec: String {
        var parts: [String] = []
        if control { parts.append("control") }
        if option { parts.append("option") }
        if shift { parts.append("shift") }
        if command { parts.append("command") }
        parts.append(Self.name(for: keyCode) ?? "")
        return parts.joined(separator: "+")
    }

    init(keyCode: UInt32, control: Bool = false, option: Bool = false,
         shift: Bool = false, command: Bool = false) {
        self.keyCode = keyCode
        self.control = control
        self.option = option
        self.shift = shift
        self.command = command
    }

    init?(spec: String) {
        var hotkey = Hotkey(keyCode: 0)
        var key: UInt32?
        for part in spec.lowercased().split(separator: "+").map(String.init) {
            switch part {
            case "control", "ctrl": hotkey.control = true
            case "option", "alt": hotkey.option = true
            case "shift": hotkey.shift = true
            case "command", "cmd": hotkey.command = true
            default: key = Self.keyCode(for: part)
            }
        }
        guard let key else { return nil }
        hotkey.keyCode = key
        self = hotkey
    }

    /// Nil for a press that cannot be a global hotkey on its own.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hotkey = Hotkey(
            keyCode: UInt32(event.keyCode),
            control: flags.contains(.control),
            option: flags.contains(.option),
            shift: flags.contains(.shift),
            command: flags.contains(.command)
        )
        guard Self.name(for: hotkey.keyCode) != nil, hotkey.hasModifier else { return nil }
        self = hotkey
    }

    // MARK: - Key table

    // Only keys that make sense as a window-management shortcut, so an
    // unmappable press is rejected at the recorder rather than silently saved.
    private static let keys: [(code: Int, name: String, symbol: String)] = [
        (kVK_ANSI_A, "a", "A"), (kVK_ANSI_B, "b", "B"), (kVK_ANSI_C, "c", "C"),
        (kVK_ANSI_D, "d", "D"), (kVK_ANSI_E, "e", "E"), (kVK_ANSI_F, "f", "F"),
        (kVK_ANSI_G, "g", "G"), (kVK_ANSI_H, "h", "H"), (kVK_ANSI_I, "i", "I"),
        (kVK_ANSI_J, "j", "J"), (kVK_ANSI_K, "k", "K"), (kVK_ANSI_L, "l", "L"),
        (kVK_ANSI_M, "m", "M"), (kVK_ANSI_N, "n", "N"), (kVK_ANSI_O, "o", "O"),
        (kVK_ANSI_P, "p", "P"), (kVK_ANSI_Q, "q", "Q"), (kVK_ANSI_R, "r", "R"),
        (kVK_ANSI_S, "s", "S"), (kVK_ANSI_T, "t", "T"), (kVK_ANSI_U, "u", "U"),
        (kVK_ANSI_V, "v", "V"), (kVK_ANSI_W, "w", "W"), (kVK_ANSI_X, "x", "X"),
        (kVK_ANSI_Y, "y", "Y"), (kVK_ANSI_Z, "z", "Z"),
        (kVK_ANSI_0, "0", "0"), (kVK_ANSI_1, "1", "1"), (kVK_ANSI_2, "2", "2"),
        (kVK_ANSI_3, "3", "3"), (kVK_ANSI_4, "4", "4"), (kVK_ANSI_5, "5", "5"),
        (kVK_ANSI_6, "6", "6"), (kVK_ANSI_7, "7", "7"), (kVK_ANSI_8, "8", "8"),
        (kVK_ANSI_9, "9", "9"),
        (kVK_LeftArrow, "left", "←"), (kVK_RightArrow, "right", "→"),
        (kVK_UpArrow, "up", "↑"), (kVK_DownArrow, "down", "↓"),
        (kVK_Return, "return", "↩"), (kVK_ANSI_KeypadEnter, "enter", "⌤"),
        (kVK_Space, "space", "␣"), (kVK_Tab, "tab", "⇥"),
        (kVK_Delete, "delete", "⌫"),
        (kVK_ANSI_Minus, "minus", "-"), (kVK_ANSI_Equal, "equal", "="),
        (kVK_ANSI_LeftBracket, "leftbracket", "["), (kVK_ANSI_RightBracket, "rightbracket", "]"),
        (kVK_ANSI_Comma, "comma", ","), (kVK_ANSI_Period, "period", "."),
        (kVK_ANSI_Slash, "slash", "/"), (kVK_ANSI_Backslash, "backslash", "\\"),
        (kVK_ANSI_Semicolon, "semicolon", ";"), (kVK_ANSI_Quote, "quote", "'"),
        (kVK_ANSI_Grave, "grave", "`"),
        (kVK_F1, "f1", "F1"), (kVK_F2, "f2", "F2"), (kVK_F3, "f3", "F3"),
        (kVK_F4, "f4", "F4"), (kVK_F5, "f5", "F5"), (kVK_F6, "f6", "F6"),
        (kVK_F7, "f7", "F7"), (kVK_F8, "f8", "F8"), (kVK_F9, "f9", "F9"),
        (kVK_F10, "f10", "F10"), (kVK_F11, "f11", "F11"), (kVK_F12, "f12", "F12"),
    ]

    static func name(for code: UInt32) -> String? {
        keys.first { $0.code == Int(code) }?.name
    }

    static func symbol(for code: UInt32) -> String? {
        keys.first { $0.code == Int(code) }?.symbol
    }

    static func keyCode(for name: String) -> UInt32? {
        keys.first { $0.name == name }.map { UInt32($0.code) }
    }
}
