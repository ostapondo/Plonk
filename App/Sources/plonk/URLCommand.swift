import Foundation

// plonk://execute-action?name=left-half
//
// The action names are Rectangle's, so a Raycast script or a Stream Deck
// button that already drives Rectangle needs only its scheme swapped. Names
// past the ten shared placements are this app's own.
//
// Both schemes parse here. Whether macOS actually delivers a `rectangle://`
// URL to this app is a separate question; see RectangleURLs.

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
        /// An action that ends when a key comes back up, which a URL has no
        /// way of doing.
        case heldDownAction(String)
    }

    static let schemes: Set<String> = ["plonk", RectangleURLs.scheme]
    static let host = "execute-action"

    static func parse(_ url: URL) -> Result<URLCommand, Failure> {
        let scheme = url.scheme?.lowercased() ?? ""
        guard schemes.contains(scheme) else { return .failure(.unknownScheme(scheme)) }
        let verb = url.host()?.lowercased() ?? ""
        guard verb == host else { return .failure(.unknownHost(verb)) }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let name = query.first(where: { $0.name == "name" })?.value, !name.isEmpty else {
            return .failure(.missingName)
        }
        let wanted = name.lowercased()
        if let action = HotkeyAction.allCases.first(where: { $0.urlName == wanted })
            ?? aliases[wanted] {
            guard !heldDown.contains(action) else { return .failure(.heldDownAction(wanted)) }
            return .success(.action(action))
        }
        if isFixedGrid(wanted) { return .failure(.fixedGridAction(wanted)) }
        return .failure(.unknownAction(wanted))
    }

    /// Rectangle's names for things this app calls something else.
    static let aliases: [String: HotkeyAction] = [
        "restore": .unsnap,
        // Rectangle answers to a second name for each half, so a script may
        // hold either. WindowAction.aliasName is where they come from.
        "left-side": .leftHalf,
        "right-side": .rightHalf,
        "top-side": .topHalf,
        "bottom-side": .bottomHalf,
    ]

    /// Actions that run for as long as a key is held. Voice finishes on the
    /// key coming back up, and a URL has no second half, so one would leave the
    /// microphone listening with nothing to close it.
    static let heldDown: Set<HotkeyAction> = [.voice]

    /// Rectangle's fixed fractions, which are a zone set here. One spelling of
    /// the rule, shared with the importer.
    static func isFixedGrid(_ name: String) -> Bool { RectangleImport.isFixedGrid(name) }
}

extension HotkeyAction {
    /// The name this action answers to in a URL. Spelled out rather than
    /// derived from the case name, since other people's scripts hold these and
    /// a rename should take a deliberate edit. The ten placements match
    /// Rectangle's spelling.
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
        case .nextDisplay: return "next-display"
        case .previousDisplay: return "previous-display"
        case .larger: return "larger"
        case .smaller: return "smaller"
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
