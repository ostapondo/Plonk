import Foundation

// Config lives in ~/Library/Application Support/Plonk/config.json as plain
// JSON, so it stays easy to edit or sync by hand.

struct LayoutItemSpec: Codable {
    var app: String
    var title: String?
    var screen: Int?
    var x: Double
    var y: Double
    var w: Double
    var h: Double

    init?(dict: [String: Any]) {
        guard let app = dict["app"] as? String,
              let frac = FracRect.parse(dict["frame"]) else { return nil }
        self.app = app
        self.title = dict["title"] as? String
        self.screen = (dict["screen"] as? NSNumber)?.intValue
        self.x = frac.x; self.y = frac.y; self.w = frac.w; self.h = frac.h
    }

    init(app: String, title: String? = nil, screen: Int? = nil, x: Double, y: Double, w: Double, h: Double) {
        self.app = app; self.title = title; self.screen = screen
        self.x = x; self.y = y; self.w = w; self.h = h
    }
}

struct Config: Codable {
    var hotkeysEnabled = true
    /// Action id to key spec, e.g. "leftHalf": "control+option+left". Missing
    /// entries use the action's default; an empty string means unbound.
    var hotkeys: [String: String] = [:]
    var dragSnapEnabled = true
    // Named after the modifier it used to be hard-wired to. Renaming the key
    // would silently reset the setting for everyone, so it stays.
    var zonesRequireShift = true
    var zonesModifier = "shift"  // shift | option | control
    // How the zone overlay looks and how much room it leaves around a snapped
    // window. The gap is in points and applies to the placed window too, not
    // just the drawing, so zones can be given breathing room.
    var zoneGap: Double = 0
    var zoneOpacity: Double = 1
    /// "#RRGGBB", or nil for the system accent colour.
    var zoneColorHex: String?
    var zoneNumbersVisible = true
    var zonesOnAllMonitors = false
    /// How near the shared edge of two zones the cursor has to come, in points,
    /// before a drop covers both. Zero switches it off.
    var zoneEdgeSpanPoints: Double = 16
    // Move and resize a window by dragging anywhere inside it with a modifier
    // held. Off by default: option-drag already means something inside a lot
    // of Mac apps, so this is a choice rather than a surprise.
    var grabMoveEnabled = false
    var grabMoveModifier = "option"  // option | command | control
    var grabMoveResize = true
    var grabMoveShowGeometry = true
    // The pointer tools. Each is independent and each is off until asked for.
    // Finding the pointer is a shortcut rather than a toggle, so it has none.
    var highlightClicksEnabled = false
    var crosshairsEnabled = false
    // Apps drag snapping and the placement hotkeys leave alone; see
    // AppExclusions. Explicit placement through the API is never filtered.
    var excludedApps: [String] = []
    // Whether windows Plonk placed are put back where they were after a
    // display is plugged in or unplugged.
    var restoreZonesOnScreenChange = true
    // Whether a newly opened window goes where that app's windows have been
    // going. Off by default: it moves windows nobody asked it to.
    var placeNewWindows = false
    // BCP-47 tags for text recognition, e.g. ["uk-UA", "en-US"]. Empty lets
    // Vision pick, which follows the system language.
    var textLanguages: [String] = []
    var awakeAllowOnBattery = true
    var awakeAutoWhileCharging = false
    var awakeKeepDisplayOn = true
    var awakeTimeoutMinutes = 0
    // Whether keep-awake was on when the app last quit, so it survives a
    // relaunch. Unix epoch seconds; nil means the session had no limit.
    var awakeRequested = false
    var awakeSessionEnd: Double?
    // Stay active. The schedule and the app list are settings; whether it was
    // switched on by hand is not restored, because a hold made yesterday says
    // nothing about today.
    var activeSchedule = ActiveSchedule()
    var activeApps: [String] = []
    var activeAllowOnBattery = false
    var activeTimeoutMinutes = 0
    var shotFolder = "~/Desktop"
    var shotCopyToClipboard = true
    // How different two neighbouring pixels have to be, on one channel of 255,
    // before the screen ruler treats the boundary between them as an edge. See
    // EdgeDetector. The key is not the "rulerTolerance" a pre-release build
    // wrote: that number was a distance from the pixel under the pointer, which
    // is a different measurement, so carrying it over would mean honouring a
    // setting nobody chose.
    var rulerEdgeTolerance = EdgeDetector.defaultTolerance
    var launchAtLogin = true
    // The only setting that decides whether the app ever opens an outbound
    // connection. Off means no release check, automatic or otherwise.
    var updateCheckAutomatically = true
    // Whether Home has already offered to take a Rectangle setup. Set by taking
    // the offer or by turning it down; either way it is not asked again.
    var rectangleOfferSettled = false
    // Whether to ask macOS to send rectangle:// URLs here as well. Off, because
    // a scheme is one per machine and the loser would be a Rectangle the user
    // still has installed. See RectangleURLs.
    var handleRectangleURLs = false
    // Which MCP client the user picked as the active agent (by client name),
    // and whether only that agent may change windows and settings.
    var selectedAgent: String?
    var agentExclusive = false
    // Whether a spoken sentence that is plainly one of the dozen common
    // commands runs here instead of going to an agent. See VoiceCommands.
    var voiceLocalCommands = true
    // What the Getting Started card on the Home page has already seen happen.
    // Both latch: a step stays done once it has been done, so the card does not
    // un-tick itself the moment an agent's session ends.
    var sawFirstSnap = false
    var sawFirstAgent = false
    var gettingStartedHidden = false
    // Agents Plonk can launch itself instead of queueing a task for a live MCP
    // session, e.g. "claude -p {prompt}". The prompt reaches the command
    // through the environment, never as text in the line; see
    // AgentAdapter.invocation. Edited in config.json for now.
    var agentAdapters: [AgentAdapter] = []
    /// Theme and accent; see AppearanceSettings.
    var appearance = AppearanceSettings()
    var workspaces: [String: Workspace] = [:]
    var zoneSets: [String: [ZoneRect]] = [:]
    // Keyed by display UUID; configs written before that used the screen index,
    // which is why lookups take a list of candidate keys.
    var screenZoneSets: [String: String] = [:]

    init() {}

    /// Assigned set name for a screen, or nil when it has no assignment.
    /// An empty string means edge snapping.
    func zoneAssignment(forKeys keys: [String]) -> String? {
        for key in keys {
            if let name = screenZoneSets[key] { return name }
        }
        return nil
    }

    func zones(forKeys keys: [String]) -> [ZoneRect] {
        guard let name = zoneAssignment(forKeys: keys) else {
            return BuiltinZoneSets.all[BuiltinZoneSets.defaultName] ?? []
        }
        if name.isEmpty { return [] }
        return zoneSets[name] ?? BuiltinZoneSets.all[name] ?? []
    }

    mutating func assignZoneSet(_ name: String?, forKeys keys: [String]) {
        keys.forEach { screenZoneSets.removeValue(forKey: $0) }
        if let name, let primary = keys.first { screenZoneSets[primary] = name }
    }

    /// Resolved bindings: what the user chose, otherwise the default.
    var resolvedHotkeys: [HotkeyAction: Hotkey] {
        HotkeyAction.allCases.reduce(into: [:]) { result, action in
            guard let spec = hotkeys[action.rawValue] else {
                result[action] = action.defaultHotkey
                return
            }
            if let hotkey = Hotkey(spec: spec) { result[action] = hotkey }
        }
    }

    mutating func forgetZoneSet(named name: String) {
        zoneSets.removeValue(forKey: name)
        screenZoneSets = screenZoneSets.filter { $0.value != name }
    }
}

// MARK: - Reading a file

extension Config {
    /// Read a config file, tolerating every key it does not have.
    ///
    /// Swift synthesizes a decoder that demands every key, and there is no way
    /// to tell it "use the property's default when one is missing". Spelling
    /// that out by hand cost a line per field, and a new setting decoded only
    /// if you remembered to add its line — which is a default that silently
    /// stops applying, not a compiler error.
    ///
    /// So the file is merged over the defaults as JSON first. Every key is then
    /// present, the synthesized decoder is enough, and adding a setting is the
    /// field and nothing else.
    static func decode(_ data: Data) throws -> Config {
        guard let stored = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Failure.notAnObject
        }
        let defaults = try JSONSerialization
            .jsonObject(with: JSONEncoder().encode(Config())) as? [String: Any] ?? [:]
        let merged = Self.merging(defaults, under: Self.migrated(stored))
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

    /// Renames a key an older release wrote. Configs written before workspaces
    /// could launch apps hold bare item arrays under "layouts".
    private static func migrated(_ stored: [String: Any]) -> [String: Any] {
        guard stored["workspaces"] == nil,
              let layouts = stored["layouts"] as? [String: Any] else { return stored }
        var stored = stored
        stored["workspaces"] = layouts.mapValues { ["items": $0] }
        return stored
    }
}

final class ConfigStore {
    private(set) var config = Config()
    /// Set when `load` had to set an unreadable config aside, so the UI can say so.
    private(set) var loadFailure: String?
    /// Fires after every update(), whoever triggered it — feeds live events.
    var didMutate: (() -> Void)?

    private let url: URL
    private let backupURL: URL

    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Plonk", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("config.json")
        backupURL = dir.appendingPathComponent("config.json.bad")
    }

    func load() {
        guard let data = try? Data(contentsOf: url) else { return }
        do {
            config = try Config.decode(data)
            // A file edited by hand is as much a caller as the slider is.
            config.clamp()
        } catch {
            // Keep the unreadable file instead of overwriting it on the next
            // save, so saved layouts can still be recovered by hand.
            NSLog("Plonk: config.json is unreadable (\(error)); moved to \(backupURL.path)")
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.moveItem(at: url, to: backupURL)
            loadFailure = String(localized: .warningSettingsReset(backupURL.path))
        }
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try encoder.encode(config).write(to: url, options: .atomic)
        } catch {
            NSLog("Plonk: could not write config: \(error)")
        }
    }

    func update(_ mutate: (inout Config) -> Void) {
        mutate(&config)
        config.clamp()
        save()
        didMutate?()
    }
}
