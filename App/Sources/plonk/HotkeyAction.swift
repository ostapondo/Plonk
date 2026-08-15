import Foundation

// Everything that can be bound to a key, and how each one is titled, drawn and
// filed. Split out of Hotkey.swift, which is over the line limit: that says
// what a key combination *is*, and this says what the app does with one.

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
    case ruler
    case shortcutGuide
    case commandPalette

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
        case .ruler: return "Measure the screen"
        case .shortcutGuide: return "Show this app's shortcuts"
        case .commandPalette: return "Open the command palette"
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
        case .ruler: return "ruler"
        case .shortcutGuide: return "keyboard"
        case .commandPalette: return "command"
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
        case .shortcutGuide, .commandPalette: return "Guide"
        case .cropLive, .cropStill: return "Crop"
        case .ruler: return "Ruler"
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
        case .ruler: return "ruler"
        case .voice: return "voice"
        case .shortcutGuide, .commandPalette: return "shortcuts"
        default: return "zones"
        }
    }

    static func owned(by page: String) -> [HotkeyAction] {
        allCases.filter { $0.page == page }
    }

    static func owned(by page: String, group: String) -> [HotkeyAction] {
        allCases.filter { $0.page == page && $0.group == group }
    }
}
