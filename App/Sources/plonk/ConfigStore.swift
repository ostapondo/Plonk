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
    var awakeAllowOnBattery = true
    var awakeAutoWhileCharging = false
    var awakeKeepDisplayOn = true
    var awakeTimeoutMinutes = 0
    // Whether keep-awake was on when the app last quit, so it survives a
    // relaunch. Unix epoch seconds; nil means the session had no limit.
    var awakeRequested = false
    var awakeSessionEnd: Double?
    var shotFolder = "~/Desktop"
    var shotCopyToClipboard = true
    var launchAtLogin = true
    var workspaces: [String: Workspace] = [:]
    var zoneSets: [String: [ZoneRect]] = [:]
    // Keyed by display UUID; configs written before that used the screen index,
    // which is why lookups take a list of candidate keys.
    var screenZoneSets: [String: String] = [:]

    init() {}

    // Tolerate missing keys so old config files survive new fields.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hotkeysEnabled = try c.decodeIfPresent(Bool.self, forKey: .hotkeysEnabled) ?? true
        hotkeys = try c.decodeIfPresent([String: String].self, forKey: .hotkeys) ?? [:]
        dragSnapEnabled = try c.decodeIfPresent(Bool.self, forKey: .dragSnapEnabled) ?? true
        zonesRequireShift = try c.decodeIfPresent(Bool.self, forKey: .zonesRequireShift) ?? true
        zonesModifier = try c.decodeIfPresent(String.self, forKey: .zonesModifier) ?? "shift"
        awakeAllowOnBattery = try c.decodeIfPresent(Bool.self, forKey: .awakeAllowOnBattery) ?? true
        awakeAutoWhileCharging = try c.decodeIfPresent(Bool.self, forKey: .awakeAutoWhileCharging) ?? false
        awakeKeepDisplayOn = try c.decodeIfPresent(Bool.self, forKey: .awakeKeepDisplayOn) ?? true
        awakeTimeoutMinutes = try c.decodeIfPresent(Int.self, forKey: .awakeTimeoutMinutes) ?? 0
        awakeRequested = try c.decodeIfPresent(Bool.self, forKey: .awakeRequested) ?? false
        awakeSessionEnd = try c.decodeIfPresent(Double.self, forKey: .awakeSessionEnd)
        shotFolder = try c.decodeIfPresent(String.self, forKey: .shotFolder) ?? "~/Desktop"
        shotCopyToClipboard = try c.decodeIfPresent(Bool.self, forKey: .shotCopyToClipboard) ?? true
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? true
        if let current = try c.decodeIfPresent([String: Workspace].self, forKey: .workspaces) {
            workspaces = current
        } else {
            let legacy = try decoder.container(keyedBy: LegacyKeys.self)
            workspaces = (try legacy.decodeIfPresent([String: [WorkspaceItem]].self, forKey: .layouts) ?? [:])
                .mapValues { Workspace(items: $0) }
        }
        zoneSets = try c.decodeIfPresent([String: [ZoneRect]].self, forKey: .zoneSets) ?? [:]
        screenZoneSets = try c.decodeIfPresent([String: String].self, forKey: .screenZoneSets) ?? [:]
    }

    /// Configs written before workspaces hold bare item arrays under "layouts".
    /// Every field workspaces added is optional, so those still decode.
    private enum LegacyKeys: String, CodingKey {
        case layouts
    }

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

final class ConfigStore {
    private(set) var config = Config()
    /// Set when `load` had to set an unreadable config aside, so the UI can say so.
    private(set) var loadFailure: String?

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
            config = try JSONDecoder().decode(Config.self, from: data)
        } catch {
            // Keep the unreadable file instead of overwriting it on the next
            // save, so saved layouts can still be recovered by hand.
            NSLog("Plonk: config.json is unreadable (\(error)); moved to \(backupURL.path)")
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.moveItem(at: url, to: backupURL)
            loadFailure = "Settings could not be read and were reset. The old file is at \(backupURL.path)."
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
        save()
    }
}
