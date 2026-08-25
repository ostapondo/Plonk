import Foundation

// Every setting, as one value. It is saved to
// ~/Library/Application Support/Plonk/config.json as plain JSON, so it
// stays easy to edit or sync by hand. That is also why reading one is its own
// problem; see Config+Decoding.
//
// Adding a setting is a field here and a row on a page. Nothing else: the
// decoder needs no line, and applying it is the job of ConfigStore.didMutate.
// Anything with a bound gets a line in Config.clamp, in Config+Edits.

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
    // How each of them is drawn. Every colour is "#RRGGBB" or nil, and nil is
    // the zone colour, which is what all three were wired to before any of it
    // was settable: leave these alone and the desk stays one colour. What the
    // numbers mean is PointerAppearance's to say.
    var clickColorHex: String?
    /// Nil draws a right click exactly like a left one.
    var rightClickColorHex: String?
    /// The radius the ring lands at, in points, and how heavy its line is.
    var clickRadius: Double = 34
    var clickLineWidth: Double = 3
    /// ring | dot | both
    var clickStyle = "ring"
    /// Seconds a ring takes to grow and fade out.
    var clickFadeSeconds: Double = 0.24
    var crosshairColorHex: String?
    var crosshairLineWidth: Double = 2
    var crosshairOpacity: Double = 0.7
    /// The circle finding the pointer leaves bright, and how far down the rest
    /// of the desk goes while it is up, 0 to 1.
    var spotlightRadius: Double = 110
    var spotlightDim: Double = 0.55
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
    // Whether the Mac keeps running with the lid shut. Unlike the settings
    // around it this one is a hold rather than a preference: it disables sleep
    // system-wide, so LidSleep hands it back when the app is not there to own
    // it, and AppDelegate.setupLidSleep clears it on the next launch.
    var awakeLidClosed = false
    var awakeTimeoutMinutes = 0
    // The level the session runs at: off holds a power assertion, on also
    // resets the idle timer, which is what keeps chat apps from showing you as
    // Away. See AwakeManager.
    var awakeAvailable = false
    // What starts a session without being asked: the hours it covers, and the
    // apps whose being open arms it. Each has a switch of its own, so a list
    // can be kept while it is not in use, the way the schedule keeps its hours.
    var awakeSchedule = AwakeSchedule()
    var awakeAppsEnabled = false
    var awakeApps: [String] = []
    // Whether a hand-made session was on when the app last quit, so it survives
    // a relaunch. Unix epoch seconds; nil means the session had no limit.
    var awakeRequested = false
    var awakeSessionEnd: Double?
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
    /// Modules switched off as a whole, by Feature id. Stored as the off list
    /// so a feature added later comes up on, the way a fresh install has it.
    var disabledFeatures: [String] = []
    /// Theme and accent; see AppearanceSettings.
    var appearance = AppearanceSettings()
    var workspaces: [String: Workspace] = [:]
    var zoneSets: [String: [ZoneRect]] = [:]
    /// A set's own gap in points, keyed by set name. A set with no entry
    /// uses `zoneGap`, the default; see `zoneGap(forSet:)`.
    var zoneSetGaps: [String: Double] = [:]
    // Keyed by display UUID; configs written before that used the screen index,
    // which is why lookups take a list of candidate keys.
    var screenZoneSets: [String: String] = [:]

    init() {}

    func isEnabled(_ feature: Feature) -> Bool {
        !disabledFeatures.contains(feature.rawValue)
    }

    mutating func setEnabled(_ feature: Feature, _ on: Bool) {
        disabledFeatures.removeAll { $0 == feature.rawValue }
        if !on { disabledFeatures.append(feature.rawValue) }
    }

    /// Hotkeys for whatever is on: a shortcut belonging to a feature that is
    /// off is not registered, so the key goes to whichever app wants it.
    var activeHotkeys: [HotkeyAction: Hotkey] {
        resolvedHotkeys.filter { action, _ in
            Feature.owning(action).map(isEnabled) ?? true
        }
    }

    /// Assigned set name for a screen, or nil when it has no assignment.
    /// An empty string means edge snapping.
    func zoneAssignment(forKeys keys: [String]) -> String? {
        keys.lazy.compactMap { screenZoneSets[$0] }.first
    }

    func zones(forKeys keys: [String]) -> [ZoneRect] {
        guard let name = zoneAssignment(forKeys: keys) else {
            return BuiltinZoneSets.all[BuiltinZoneSets.defaultName] ?? []
        }
        if name.isEmpty { return [] }
        return zoneSets[name] ?? BuiltinZoneSets.all[name] ?? []
    }

    /// The gap for a set: its own if it has one, else the default. Nil is
    /// the set an unassigned screen falls back to.
    func zoneGap(forSet name: String?) -> Double {
        zoneSetGaps[name ?? BuiltinZoneSets.defaultName] ?? zoneGap
    }

    /// The gap that applies on a screen, through the set it wears.
    func zoneGap(forKeys keys: [String]) -> Double {
        zoneGap(forSet: zoneAssignment(forKeys: keys))
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
        zoneSetGaps.removeValue(forKey: name)
        screenZoneSets = screenZoneSets.filter { $0.value != name }
    }
}
