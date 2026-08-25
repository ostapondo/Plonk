import Foundation

// Reading a config file.
//
// Swift synthesizes a decoder that demands every key and has no notion of a
// property's default, so a tolerant read is not something the language will
// write. Doing it per field cost a line each and made a forgotten line a
// default that silently stopped applying. This does it once, in JSON, before
// the decoder ever runs.

extension Config {
    /// Read a config file, tolerating every key it does not have.
    static func decode(_ data: Data) throws -> Config {
        guard let stored = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Failure.notAnObject
        }
        let defaults = try JSONSerialization
            .jsonObject(with: JSONEncoder().encode(Config())) as? [String: Any] ?? [:]
        // Nulls go first: `migrated` asks whether a key is present, and an
        // explicit null is present as far as a dictionary is concerned. Asking
        // after they are gone is the only way that question means what it says.
        let merged = Self.merging(defaults, under: Self.migrated(Self.withoutNulls(stored)))
        return try JSONDecoder().decode(
            Config.self, from: JSONSerialization.data(withJSONObject: merged))
    }

    enum Failure: Error {
        case notAnObject
    }

    /// `over` wins, key by key, recursing where both sides are objects. The
    /// recursion is what lets a file name one field of `appearance` without
    /// losing the rest of it.
    private static func merging(_ base: [String: Any], under over: [String: Any]) -> [String: Any] {
        base.merging(over) { mine, theirs in
            guard let mine = mine as? [String: Any], let theirs = theirs as? [String: Any] else {
                return theirs
            }
            return merging(mine, under: theirs)
        }
    }

    /// Drops every explicit `null`, at any depth, so the default is what shows
    /// through the merge.
    ///
    /// A file may hold one for any number of reasons: a hand edit, a field an
    /// older release wrote as null, an exporter that spells "unset" that way.
    /// Reaching the decoder it would be a hard failure on any field that is not
    /// Optional, and a failure is not one setting reset — `load` sets the whole
    /// file aside, which is every workspace and every zone set with it. So null
    /// means absent here, which is what the per-field decoder this replaced did
    /// with it.
    private static func withoutNulls(_ value: [String: Any]) -> [String: Any] {
        value.reduce(into: [String: Any]()) { result, pair in
            guard let cleaned = withoutNulls(any: pair.value) else { return }
            result[pair.key] = cleaned
        }
    }

    /// Nil for a null, which is how a dictionary key is dropped and how an
    /// array element is skipped. Lists matter as much as objects here: a
    /// workspace's items, a zone set's rects and the excluded-app patterns are
    /// all arrays, and one null in any of them is a whole config file.
    private static func withoutNulls(any value: Any) -> Any? {
        switch value {
        case is NSNull:
            return nil
        case let nested as [String: Any]:
            return withoutNulls(nested)
        case let list as [Any]:
            return list.compactMap { withoutNulls(any: $0) }
        default:
            return value
        }
    }

    /// Renames the keys older releases wrote, so a config file that predates a
    /// change still says what it meant.
    private static func migrated(_ stored: [String: Any]) -> [String: Any] {
        var stored = stored
        // Configs written before workspaces could launch apps hold bare item
        // arrays under "layouts".
        if stored["workspaces"] == nil, let layouts = stored["layouts"] as? [String: Any] {
            stored["workspaces"] = layouts.mapValues { ["items": $0] }
        }
        return staying(available: stored)
    }

    /// Stay active was a feature beside keep-awake until they were merged. Its
    /// schedule and its watched apps are triggers of the one session now, so
    /// they move across under the names that survived.
    ///
    /// Its own battery and timeout rules are dropped rather than merged: two
    /// settings became one, and keep-awake's is the one the same user was
    /// already reading on the page that is still there.
    private static func staying(available stored: [String: Any]) -> [String: Any] {
        var stored = stored
        if stored["awakeSchedule"] == nil, let schedule = stored["activeSchedule"] {
            stored["awakeSchedule"] = schedule
        }
        if stored["awakeApps"] == nil, let apps = stored["activeApps"] {
            stored["awakeApps"] = apps
        }
        // A list was its own switch back then: naming an app was the whole of
        // arming it. Now the switch is separate, so a list that was in use has
        // to be switched on to go on being in use.
        if stored["awakeAppsEnabled"] == nil, !((stored["awakeApps"] as? [Any])?.isEmpty ?? true) {
            stored["awakeAppsEnabled"] = true
        }
        guard stored["awakeAvailable"] == nil else { return stored }
        // A Mac with either trigger set up was asking to be shown as available,
        // so the merged session comes up at that level — unless the feature
        // behind them was switched off, which said the opposite just as plainly.
        let off = (stored["disabledFeatures"] as? [Any])?.contains { ($0 as? String) == "active" }
        let scheduled = (stored["awakeSchedule"] as? [String: Any])?["enabled"] as? Bool ?? false
        let watched = !((stored["awakeApps"] as? [Any])?.isEmpty ?? true)
        if (scheduled || watched) && off != true { stored["awakeAvailable"] = true }
        return stored
    }
}
