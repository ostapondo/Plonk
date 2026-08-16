import Foundation

// plonk://execute-action?name=left-half
//
// The vocabulary is Rectangle's, deliberately. Anyone arriving here already
// has `rectangle://execute-action?name=…` written into a Raycast script, an
// Alfred workflow or a Stream Deck button, and the names in those should keep
// working after the scheme is swapped; docs/from-rectangle.md is one sed away.
//
// Both schemes are answered here. Whether macOS actually hands this app a
// `rectangle://` URL is a different question, decided out loud in RectangleURLs
// rather than left to whichever bundle LaunchServices registered last.
//
// Everything past the shared vocabulary is named after the action, so the zones
// and the tools are reachable too.

enum URLCommand: Equatable {
    case action(HotkeyAction)

    enum Failure: Error, Equatable {
        /// A scheme this app does not answer to at all.
        case unknownScheme(String)
        /// Right scheme, wrong verb: not `execute-action`.
        case unknownHost(String)
        /// No `name` at all.
        case missingName
        /// A name nothing here answers to.
        case unknownAction(String)
        /// One of Rectangle's fixed-grid actions, which is a zone set here.
        case fixedGridAction(String)
    }

    /// Both are declared in the bundle. Whether this app is what macOS hands
    /// a `rectangle://` URL to is a separate question, and one the user
    /// answers; see RectangleURLs.
    static let schemes: Set<String> = ["plonk", RectangleURLs.scheme]
    static let host = "execute-action"

    static func parse(_ url: URL) -> Result<URLCommand, Failure> {
        let scheme = url.scheme?.lowercased() ?? ""
        guard schemes.contains(scheme) else { return .failure(.unknownScheme(scheme)) }
        guard url.host() == host else { return .failure(.unknownHost(url.host() ?? "")) }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let name = query.first(where: { $0.name == "name" })?.value, !name.isEmpty else {
            return .failure(.missingName)
        }
        let wanted = name.lowercased()
        if let action = HotkeyAction.allCases.first(where: { $0.urlName == wanted }) {
            return .success(.action(action))
        }
        if let action = aliases[wanted] { return .success(.action(action)) }
        if fixedGrid.contains(wanted) { return .failure(.fixedGridAction(wanted)) }
        return .failure(.unknownAction(wanted))
    }

    /// Rectangle's names for things this app calls something else.
    ///
    /// `next-display` and `previous-display` are not here on purpose. Those
    /// move the window to another screen; the nearest thing here, `jump-cursor`,
    /// moves the pointer and leaves the window where it is. Answering to the
    /// name and doing the other thing is worse than not answering.
    static let aliases: [String: HotkeyAction] = [
        "restore": .unsnap,
    ]

    /// Rectangle actions that are a zone set here rather than a fixed fraction
    /// of the screen. Listed so that a script asking for one is told why it did
    /// not happen, instead of appearing to work.
    static let fixedGrid: Set<String> = [
        "first-third", "center-third", "last-third",
        "first-two-thirds", "last-two-thirds", "center-two-thirds",
        "first-fourth", "second-fourth", "third-fourth", "last-fourth",
        "first-three-fourths", "center-three-fourths", "last-three-fourths",
        "top-left-sixth", "top-center-sixth", "top-right-sixth",
        "bottom-left-sixth", "bottom-center-sixth", "bottom-right-sixth",
        "top-left-ninth", "top-center-ninth", "top-right-ninth",
        "middle-left-ninth", "middle-center-ninth", "middle-right-ninth",
        "bottom-left-ninth", "bottom-center-ninth", "bottom-right-ninth",
        "top-left-third", "top-right-third", "bottom-left-third", "bottom-right-third",
        "top-left-eighth", "top-center-left-eighth", "top-center-right-eighth",
        "top-right-eighth", "bottom-left-eighth", "bottom-center-left-eighth",
        "bottom-center-right-eighth", "bottom-right-eighth",
    ]
}

extension HotkeyAction {
    /// The name this action answers to in a URL. Spelled out rather than
    /// derived from the case name: this is a public surface other people's
    /// scripts hold, so it should only ever change on purpose. The ten window
    /// placements match Rectangle's spelling exactly.
    var urlName: String {
        switch self {
        case .leftHalf: return "left-half"
        case .rightHalf: return "right-half"
        case .topHalf: return "top-half"
        case .bottomHalf: return "bottom-half"
        case .topLeft: return "top-left"
        case .topRight: return "top-right"
        case .bottomLeft: return "bottom-left"
        case .bottomRight: return "bottom-right"
        case .maximize: return "maximize"
        case .center: return "center"
        case .unsnap: return "unsnap"
        case .showZones: return "show-zones"
        case .captureRegion: return "capture-region"
        case .captureText: return "capture-text"
        case .voice: return "voice"
        case .zone1: return "zone-1"
        case .zone2: return "zone-2"
        case .zone3: return "zone-3"
        case .zone4: return "zone-4"
        case .zone5: return "zone-5"
        case .zone6: return "zone-6"
        case .zone7: return "zone-7"
        case .zone8: return "zone-8"
        case .zone9: return "zone-9"
        case .layout1: return "zone-set-1"
        case .layout2: return "zone-set-2"
        case .layout3: return "zone-set-3"
        case .layout4: return "zone-set-4"
        case .layout5: return "zone-set-5"
        case .layout6: return "zone-set-6"
        case .layout7: return "zone-set-7"
        case .layout8: return "zone-set-8"
        case .layout9: return "zone-set-9"
        case .zoneSetPalette: return "zone-set-palette"
        case .cycleZone: return "cycle-zone"
        case .cycleZoneBack: return "cycle-zone-back"
        case .focusLeft: return "focus-left"
        case .focusRight: return "focus-right"
        case .focusUp: return "focus-up"
        case .focusDown: return "focus-down"
        case .findCursor: return "find-cursor"
        case .jumpCursor: return "jump-cursor"
        case .cropLive: return "crop-live"
        case .cropStill: return "crop-still"
        case .ruler: return "ruler"
        case .shortcutGuide: return "shortcut-guide"
        case .commandPalette: return "command-palette"
        }
    }
}
