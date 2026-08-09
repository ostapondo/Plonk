import Carbon.HIToolbox

// What each action is bound to out of the box.
//
// Split out of Hotkey.swift, which is over the line limit: the enum there
// says what an action *is*, and this says what key it arrives on. Every
// binding is ⌃⌥ and something, which is the one combination macOS itself
// leaves alone and no app in the wild seems to want.

extension HotkeyAction {
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
        case .shortcutGuide: code = kVK_ANSI_Slash; shift = true
        // Space, because the thing it opens is the one surface here that
        // answers a sentence rather than a key, and that is where every Mac
        // user's hand already goes for exactly that.
        case .commandPalette: code = kVK_Space
        }
        return Hotkey(keyCode: UInt32(code), control: true, option: true, shift: shift)
    }

    static var defaults: [String: String] {
        allCases.reduce(into: [:]) { $0[$1.rawValue] = $1.defaultHotkey.spec }
    }
}
