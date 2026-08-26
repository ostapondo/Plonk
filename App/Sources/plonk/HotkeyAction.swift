import Foundation

// Everything that can be bound to a key, and how each one is titled, drawn and
// filed. Split out of Hotkey.swift, which is over the line limit: that says
// what a key combination *is*, and this says what the app does with one.

enum HotkeyAction: String, CaseIterable, Identifiable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case maximize, center
    /// The front window onto the next display along, or the previous one.
    case nextDisplay, previousDisplay
    /// The front window grown or shrunk by a step about its centre.
    case larger, smaller
    case showZones, captureRegion, captureText
    case voice
    /// The numbered zones of the screen the window is on, as the drag overlay
    /// draws them. Nine is where the digit row runs out.
    case zone1, zone2, zone3, zone4, zone5, zone6, zone7, zone8, zone9
    /// Swap the whole zone set on the screen under the cursor, by its place in
    /// the list the Zones page shows.
    case layout1, layout2, layout3, layout4, layout5, layout6, layout7, layout8, layout9
    /// The same swap, but with the sets on screen to choose from.
    case zoneSetPalette
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
    var zoneNumber: Int? { number(afterPrefix: "zone") }

    /// 1-based zone set this action switches to, nil for everything else.
    var layoutNumber: Int? { number(afterPrefix: "layout") }

    private func number(afterPrefix prefix: String) -> Int? {
        rawValue.hasPrefix(prefix) ? Int(rawValue.dropFirst(prefix.count)) : nil
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

    var title: LocalizedStringResource {
        switch self {
        case .showZones: return .shortcutFlashZones
        case .captureRegion: return .shortcutCaptureRegion
        case .captureText: return .shortcutCaptureText
        case .voice: return .shortcutPushToTalk
        case .unsnap: return .shortcutPutItBack
        case .cycleZone: return .shortcutNextInZone
        case .cycleZoneBack: return .shortcutPreviousInZone
        case .focusLeft: return .shortcutFocusLeft
        case .focusRight: return .shortcutFocusRight
        case .focusUp: return .shortcutFocusUp
        case .focusDown: return .shortcutFocusDown
        case .findCursor: return .shortcutFindPointer
        case .jumpCursor: return .shortcutJumpPointer
        case .cropLive: return .shortcutCropLive
        case .cropStill: return .shortcutCropStill
        case .ruler: return .shortcutRuler
        case .shortcutGuide: return .shortcutGuide
        case .commandPalette: return .shortcutCommandPalette
        case .zoneSetPalette: return .shortcutZoneSetPalette
        case .nextDisplay: return .shortcutNextDisplay
        case .previousDisplay: return .shortcutPreviousDisplay
        case .larger: return .shortcutLarger
        case .smaller: return .shortcutSmaller
        default:
            if let number = zoneNumber { return .shortcutZone(number) }
            if let number = layoutNumber { return .shortcutZoneSet(number) }
            return preset?.title ?? LocalizedStringResource(stringLiteral: rawValue)
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
        case .zoneSetPalette: return "rectangle.3.group"
        case .nextDisplay: return "arrow.right.to.line"
        case .previousDisplay: return "arrow.left.to.line"
        case .larger: return "arrow.up.left.and.arrow.down.right"
        case .smaller: return "arrow.down.right.and.arrow.up.left"
        default:
            if zoneNumber != nil { return "square.grid.2x2" }
            if layoutNumber != nil { return "rectangle.3.group" }
            return "macwindow"
        }
    }

    /// The heading an action is filed under, as a value rather than as its own
    /// name: the pages filter on this, and a filter that compared printed text
    /// would break the moment the text was translated.
    enum Group: String, CaseIterable {
        case halves, quarters, wholeScreen, numberedZones, zoneSets
        case displays, size
        case focus, pointer, guide, crop, ruler, other

        var title: LocalizedStringResource {
            switch self {
            case .halves: return .shortcutGroupHalves
            case .quarters: return .shortcutGroupQuarters
            case .wholeScreen: return .shortcutGroupWholeScreen
            case .numberedZones: return .shortcutGroupNumberedZones
            case .zoneSets: return .shortcutGroupZoneSets
            case .displays: return .shortcutGroupDisplays
            case .size: return .shortcutGroupSize
            case .focus: return .shortcutGroupFocus
            case .pointer: return .shortcutGroupPointer
            case .guide: return .shortcutGroupGuide
            case .crop: return .shortcutGroupCrop
            case .ruler: return .shortcutGroupRuler
            case .other: return .shortcutGroupOther
            }
        }
    }

    var group: Group {
        switch self {
        case .leftHalf, .rightHalf, .topHalf, .bottomHalf: return .halves
        case .topLeft, .topRight, .bottomLeft, .bottomRight: return .quarters
        case .maximize, .center: return .wholeScreen
        case .nextDisplay, .previousDisplay: return .displays
        case .larger, .smaller: return .size
        case .unsnap: return .numberedZones
        case .cycleZone, .cycleZoneBack, .focusLeft, .focusRight, .focusUp, .focusDown: return .focus
        case .findCursor, .jumpCursor: return .pointer
        case .shortcutGuide, .commandPalette: return .guide
        case .cropLive, .cropStill: return .crop
        case .ruler: return .ruler
        case .zoneSetPalette: return .zoneSets
        default:
            if zoneNumber != nil { return .numberedZones }
            if layoutNumber != nil { return .zoneSets }
            return .other
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

    static func owned(by page: String, group: Group) -> [HotkeyAction] {
        allCases.filter { $0.page == page && $0.group == group }
    }
}
