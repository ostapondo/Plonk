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
    var display: String {
        var text = ""
        if control { text += "⌃" }
        if option { text += "⌥" }
        if shift { text += "⇧" }
        if command { text += "⌘" }
        return text + (Self.symbol(for: keyCode) ?? "?")
    }

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

/// Everything that can be bound to a key.
enum HotkeyAction: String, CaseIterable, Identifiable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case maximize, center
    case showZones, captureRegion, captureText
    case voice
    /// The numbered zones of the screen the window is on, as the drag overlay
    /// draws them. Nine is where the digit row runs out.
    case zone1, zone2, zone3, zone4, zone5, zone6, zone7, zone8, zone9
    /// Swap the whole zone set on the screen under the cursor, by its place in
    /// the list the Zones page shows.
    case layout1, layout2, layout3, layout4, layout5, layout6, layout7, layout8, layout9
    case unsnap
    case cycleZone, cycleZoneBack
    case focusLeft, focusRight, focusUp, focusDown
    case findCursor, jumpCursor
    case cropLive, cropStill

    var id: String { rawValue }

    var preset: Preset? {
        switch self {
        case .leftHalf: return .leftHalf
        case .rightHalf: return .rightHalf
        case .topHalf: return .topHalf
        case .bottomHalf: return .bottomHalf
        case .topLeft: return .topLeft
        case .topRight: return .topRight
        case .bottomLeft: return .bottomLeft
        case .bottomRight: return .bottomRight
        case .maximize: return .maximize
        case .center: return .center
        default: return nil
        }
    }

    /// 1-based zone this action snaps to, nil for everything else.
    var zoneNumber: Int? {
        switch self {
        case .zone1: return 1
        case .zone2: return 2
        case .zone3: return 3
        case .zone4: return 4
        case .zone5: return 5
        case .zone6: return 6
        case .zone7: return 7
        case .zone8: return 8
        case .zone9: return 9
        default: return nil
        }
    }

    /// 1-based zone set this action switches to, nil for everything else.
    var layoutNumber: Int? {
        switch self {
        case .layout1: return 1
        case .layout2: return 2
        case .layout3: return 3
        case .layout4: return 4
        case .layout5: return 5
        case .layout6: return 6
        case .layout7: return 7
        case .layout8: return 8
        case .layout9: return 9
        default: return nil
        }
    }

    var focusDirection: WindowNavigator.Direction? {
        switch self {
        case .focusLeft: return .left
        case .focusRight: return .right
        case .focusUp: return .up
        case .focusDown: return .down
        default: return nil
        }
    }

    var title: String {
        switch self {
        case .showZones: return "Flash the zones"
        case .captureRegion: return "Capture a region"
        case .captureText: return "Copy text from a region"
        case .voice: return "Push to talk"
        case .unsnap: return "Put it back"
        case .cycleZone: return "Next window in this zone"
        case .cycleZoneBack: return "Previous window in this zone"
        case .focusLeft: return "Focus the window to the left"
        case .focusRight: return "Focus the window to the right"
        case .focusUp: return "Focus the window above"
        case .focusDown: return "Focus the window below"
        case .findCursor: return "Find the pointer"
        case .jumpCursor: return "Jump the pointer to the next screen"
        case .cropLive: return "Pin a live crop on top"
        case .cropStill: return "Pin a still crop on top"
        default:
            if let number = zoneNumber { return "Zone \(number)" }
            if let number = layoutNumber { return "Zone set \(number)" }
            return preset?.title ?? rawValue
        }
    }

    /// Used where an action has no window position to draw.
    var symbol: String {
        switch self {
        case .showZones: return "square.grid.2x2"
        case .captureRegion: return "camera.viewfinder"
        case .captureText: return "text.viewfinder"
        case .voice: return "mic"
        case .unsnap: return "arrow.uturn.backward"
        case .cycleZone, .cycleZoneBack: return "arrow.triangle.2.circlepath"
        case .focusLeft: return "arrow.left"
        case .focusRight: return "arrow.right"
        case .focusUp: return "arrow.up"
        case .focusDown: return "arrow.down"
        case .findCursor: return "scope"
        case .jumpCursor: return "arrow.left.arrow.right"
        case .cropLive: return "pip"
        case .cropStill: return "photo"
        default:
            if zoneNumber != nil { return "square.grid.2x2" }
            if layoutNumber != nil { return "rectangle.3.group" }
            return "macwindow"
        }
    }

    var group: String {
        switch self {
        case .leftHalf, .rightHalf, .topHalf, .bottomHalf: return "Halves"
        case .topLeft, .topRight, .bottomLeft, .bottomRight: return "Quarters"
        case .maximize, .center: return "Whole screen"
        case .unsnap: return "Numbered zones"
        case .cycleZone, .cycleZoneBack, .focusLeft, .focusRight, .focusUp, .focusDown: return "Focus"
        case .findCursor, .jumpCursor: return "Pointer"
        case .cropLive, .cropStill: return "Crop"
        default:
            if zoneNumber != nil { return "Numbered zones" }
            if layoutNumber != nil { return "Zone sets" }
            return "Other"
        }
    }

    /// The settings page that owns this shortcut, matching SettingsPage ids.
    var page: String {
        switch self {
        case .captureRegion, .captureText, .cropLive, .cropStill: return "shot"
        case .findCursor, .jumpCursor: return "mouse"
        case .voice: return "voice"
        default: return "zones"
        }
    }

    static func owned(by page: String) -> [HotkeyAction] {
        allCases.filter { $0.page == page }
    }

    static func owned(by page: String, group: String) -> [HotkeyAction] {
        allCases.filter { $0.page == page && $0.group == group }
    }

    var defaultHotkey: Hotkey {
        let code: Int
        var shift = false
        switch self {
        case .leftHalf: code = kVK_LeftArrow
        case .rightHalf: code = kVK_RightArrow
        case .topHalf: code = kVK_UpArrow
        case .bottomHalf: code = kVK_DownArrow
        case .topLeft: code = kVK_ANSI_U
        case .topRight: code = kVK_ANSI_I
        case .bottomLeft: code = kVK_ANSI_J
        case .bottomRight: code = kVK_ANSI_K
        case .maximize: code = kVK_Return
        case .center: code = kVK_ANSI_C
        case .showZones: code = kVK_ANSI_Z
        case .captureRegion: code = kVK_ANSI_S
        case .captureText: code = kVK_ANSI_T
        case .voice: code = kVK_ANSI_V
        case .zone1: code = kVK_ANSI_1
        case .zone2: code = kVK_ANSI_2
        case .zone3: code = kVK_ANSI_3
        case .zone4: code = kVK_ANSI_4
        case .zone5: code = kVK_ANSI_5
        case .zone6: code = kVK_ANSI_6
        case .zone7: code = kVK_ANSI_7
        case .zone8: code = kVK_ANSI_8
        case .zone9: code = kVK_ANSI_9
        case .layout1: code = kVK_ANSI_1; shift = true
        case .layout2: code = kVK_ANSI_2; shift = true
        case .layout3: code = kVK_ANSI_3; shift = true
        case .layout4: code = kVK_ANSI_4; shift = true
        case .layout5: code = kVK_ANSI_5; shift = true
        case .layout6: code = kVK_ANSI_6; shift = true
        case .layout7: code = kVK_ANSI_7; shift = true
        case .layout8: code = kVK_ANSI_8; shift = true
        case .layout9: code = kVK_ANSI_9; shift = true
        case .unsnap: code = kVK_ANSI_0
        case .cycleZone: code = kVK_ANSI_Grave
        case .cycleZoneBack: code = kVK_ANSI_Grave; shift = true
        case .focusLeft: code = kVK_LeftArrow; shift = true
        case .focusRight: code = kVK_RightArrow; shift = true
        case .focusUp: code = kVK_UpArrow; shift = true
        case .focusDown: code = kVK_DownArrow; shift = true
        case .findCursor: code = kVK_ANSI_Slash
        case .jumpCursor: code = kVK_ANSI_Backslash
        case .cropLive: code = kVK_ANSI_P
        case .cropStill: code = kVK_ANSI_P; shift = true
        }
        return Hotkey(keyCode: UInt32(code), control: true, option: true, shift: shift)
    }

    static var defaults: [String: String] {
        allCases.reduce(into: [:]) { $0[$1.rawValue] = $1.defaultHotkey.spec }
    }
}
