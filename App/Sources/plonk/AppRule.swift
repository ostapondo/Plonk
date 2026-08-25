import Foundation

// Where an app's windows go the moment they open: a numbered zone, and
// optionally the monitor that zone is on.
//
// A rule is the deliberate form of the habit NewWindowWatcher already follows.
// The habit is where an app's last window went and is forgotten at quit; a
// rule is written down, survives a relaunch, and holds even when the last
// window of that app was dragged somewhere else. So a rule wins over the
// habit, and both win over filling an empty zone.

struct AppRule: Codable, Equatable {
    /// Matched anywhere in the app's name or bundle id, case-insensitively,
    /// the same way an exclusion is; an exact match on either wins over a
    /// bare word. The bundle id is what the settings page writes.
    var app: String
    /// 1-based, as the overlay draws it.
    var zone: Int
    /// The display the zone is on, by UUID. Nil means whichever screen the
    /// window opened on; a display that is not attached falls back to that
    /// too, because a rule should not strand a window on a monitor that is
    /// in a drawer.
    var screenUUID: String?

    /// What an agent reads. The caller says where the display is today,
    /// since it has that in hand for every screen already; nil while the
    /// display is not attached, and the UUID is there either way.
    func asDict(screenIndex: Int?) -> [String: Any] {
        var entry: [String: Any] = ["app": app, "zone": zone]
        if let screenUUID {
            entry["screen_uuid"] = screenUUID
            if let screenIndex { entry["screen"] = screenIndex }
        }
        return entry
    }
}

extension AppRule {
    /// Tolerant of a hand-edited file, the way Workspace is: a rule with no
    /// zone, or a zone that is not a whole number, reads as zone 1 rather
    /// than taking every other setting down with it, and a rule with no app
    /// reads as an empty pattern for `Config.clamp` to drop. In an
    /// extension so the memberwise initializer stays.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        app = (try? c.decodeIfPresent(String.self, forKey: .app)) ?? ""
        zone = (try? c.decodeIfPresent(Int.self, forKey: .zone)) ?? 1
        screenUUID = try? c.decodeIfPresent(String.self, forKey: .screenUUID)
    }
}

enum AppRules {
    /// The rule for an app. A rule naming its bundle id wins, then one naming
    /// it exactly by name, then the first bare word found anywhere in either,
    /// whatever order the list is in: "code" for the family and
    /// "com.microsoft.VSCode" for the one app can both be on it, and the app
    /// that calls itself "Code" still goes where its own rule says.
    static func match(name: String, bundleID: String?, rules: [AppRule]) -> AppRule? {
        let bundle = normalized(bundleID ?? "")
        let plain = normalized(name)
        if !bundle.isEmpty, let rule = rules.first(where: { normalized($0.app) == bundle }) { return rule }
        if !plain.isEmpty, let rule = rules.first(where: { normalized($0.app) == plain }) { return rule }
        return rules.first { rule in
            let word = normalized(rule.app)
            return !word.isEmpty && (plain.contains(word) || bundle.contains(word))
        }
    }

    /// The rules with one for `app` replaced or added. Matched on the pattern
    /// as written, ignoring case, so "com.apple.Safari" and "com.apple.safari"
    /// are one rule and not two that disagree.
    static func upsert(_ rule: AppRule, in rules: [AppRule]) -> [AppRule] {
        var result = rules
        if let index = result.firstIndex(where: { same($0.app, rule.app) }) {
            result[index] = rule
        } else {
            result.append(rule)
        }
        return result
    }

    static func remove(app: String, from rules: [AppRule]) -> [AppRule] {
        rules.filter { !same($0.app, app) }
    }

    static func same(_ a: String, _ b: String) -> Bool {
        normalized(a) == normalized(b)
    }

    /// The pattern as it is compared: no space or line break round it, one
    /// case. A rule is stored with the space trimmed and its case kept.
    static func normalized(_ pattern: String) -> String {
        pattern.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
