import Foundation

// A zone set is a template of fractional rects (origin top-left, 0..1 of a
// screen's visible area). Sets are screen-agnostic, and config stores their
// names per screen. The same names also reach API callers.
enum BuiltinZoneSets {
    static let defaultName = "Halves"

    static let all: [String: [ZoneRect]] = [
        defaultName: [ZoneRect(0, 0, 0.5, 1), ZoneRect(0.5, 0, 0.5, 1)],
        "Thirds": [ZoneRect(0, 0, 1.0 / 3, 1), ZoneRect(1.0 / 3, 0, 1.0 / 3, 1), ZoneRect(2.0 / 3, 0, 1.0 / 3, 1)],
        "60 / 40": [ZoneRect(0, 0, 0.6, 1), ZoneRect(0.6, 0, 0.4, 1)],
        "Quarters": [
            ZoneRect(0, 0, 0.5, 0.5), ZoneRect(0.5, 0, 0.5, 0.5),
            ZoneRect(0, 0.5, 0.5, 0.5), ZoneRect(0.5, 0.5, 0.5, 0.5),
        ],
        "Priority": [ZoneRect(0, 0, 0.6, 1), ZoneRect(0.6, 0, 0.4, 0.5), ZoneRect(0.6, 0.5, 0.4, 0.5)],
    ]

    static func displayName(_ name: String) -> String {
        switch name {
        case defaultName: String(localized: .zoneSetHalves)
        case "Thirds": String(localized: .zoneSetThirds)
        case "Quarters": String(localized: .zoneSetQuarters)
        case "Priority": String(localized: .zoneSetPriority)
        default: name
        }
    }
}
