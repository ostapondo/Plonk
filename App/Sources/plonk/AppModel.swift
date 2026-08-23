import SwiftUI

// Everything the settings and zone windows can do, in one place. AppDelegate
// implements it; views never touch the managers directly.
//
// A plain setting needs nothing here. `update` writes any field of `Config`
// and every manager re-reads, so the list below is only the things that are
// not a stored value: commands.
protocol AppActions: AnyObject {
    /// Write one setting. The single path a value takes from the UI to disk:
    /// `ConfigStore` clamps it, saves it, and every manager re-reads. Adding a
    /// setting therefore adds no method here.
    func update<Value>(_ path: WritableKeyPath<Config, Value>, to value: Value)

    /// Keep-awake and stay-active are held by their managers, not by a stored
    /// flag: switching either by hand holds against the schedule until the
    /// schedule itself changes, which a config field could not express.
    func setAwake(_ on: Bool)
    func setActive(_ on: Bool)

    /// Binding an action frees the combination wherever else it was, so it
    /// goes through `Config.bind` rather than a plain write. See Config+Edits.
    func setHotkey(_ action: HotkeyAction, to hotkey: Hotkey)
    func clearHotkey(_ action: HotkeyAction)
    func resetHotkeys()

    /// Take whatever bindings an installed or exported Rectangle has that mean
    /// the same thing here. See RectangleImport.
    func importFromRectangle()
    /// Turn down the offer on Home, for good. See RectangleOffer.
    func dismissRectangleOffer()
    /// Hands the user the ruler: hover to size what is under the pointer, drag
    /// for a distance.
    func startRuler()
    func capture(_ mode: CaptureMode)
    func flashZones()
    func reportBug()

    func assignZoneSet(_ name: String?, toScreen index: Int)
    /// `gap` is the set's own spacing in points; nil means the default gap.
    func updateZoneSet(_ name: String, zones: [ZoneRect], gap: Double?)
    /// False when `new` is already taken, which leaves both sets untouched.
    func renameZoneSet(_ old: String, to new: String) -> Bool
    func deleteZoneSet(_ name: String)
    func togglePreview(zoneSet name: String, onScreen index: Int)
    func openZonePicker()
    /// The zone sets, listed over whatever is on screen, for the monitor the
    /// pointer is on.
    func openZoneSetPalette()
    /// `seed` opens the editor on a set that does not exist yet; it is only
    /// written if the user saves, so cancelling leaves nothing behind.
    func editZoneSet(_ name: String, seed: [ZoneRect]?, onScreen index: Int)

    /// `screen` pulls every window onto one monitor; nil keeps the monitors the
    /// workspace was captured on.
    func launchWorkspace(named name: String, onScreen screen: Int?)
    func deleteWorkspace(named name: String)
    /// False when `new` is already taken, which leaves both workspaces untouched.
    func renameWorkspace(_ old: String, to new: String) -> Bool
    /// Snapshots the desktop. Saving over an existing name replaces its items.
    func saveCurrentWorkspace(named name: String)
    func setWorkspaceMoveExisting(_ on: Bool, for name: String)
    func updateWorkspaceItem(_ index: Int, in name: String, urls: [String], args: [String])
    func removeWorkspaceItem(_ index: Int, from name: String)

    /// Everything the palette can run, in the order it should be offered.
    func paletteCommands() -> [PlonkCommand]
    func openCommandPalette()

    func checkForUpdates()
    /// Quits and relaunches into the new version when it succeeds.
    func installUpdate()
    func openReleasePage()
}

/// What the windows draw. `config` is every setting, held once rather than
/// copied field by field; the published properties beside it are the things
/// config cannot answer — what a manager is doing now, what macOS has granted,
/// what is on screen.
final class AppModel: ObservableObject {
    /// The settings, as saved. Written only by AppDelegate, off ConfigStore.
    @Published var config = Config()

    // Keep-awake, as the manager has it rather than as it was last saved.
    @Published var awakeOn = false
    /// Whether the manager is holding, which is not `config.awakeRequested`:
    /// that one is only what to restore after a relaunch. Named apart so a
    /// key path cannot mean both.
    @Published var awakeHeld = false
    /// Whether this Mac has a lid, which decides whether the lid-closed switch
    /// is worth showing at all.
    @Published var hasLid = true
    // Stay active, likewise.
    @Published var activeOn = false
    @Published var activeRequested = false
    @Published var activeStatus: LocalizedStringResource = .activeStatusOff
    @Published var activeTrusted = true

    // Which bindings macOS refused, and how the ones it took should read.
    @Published var unavailableHotkeys: [String] = []
    @Published var hotkeyDisplays: [String: String] = [:]
    @Published var hotkeyParts: [String: [String]] = [:]

    /// Whether Home should offer to take a Rectangle setup: one was found on
    /// this Mac and the offer has neither been taken nor turned down.
    @Published var rectangleFound = false

    @Published var supportedTextLanguages: [String] = []
    /// Non-empty only while a workspace is coming up.
    @Published var launchingWorkspace: String?
    @Published var launchStatuses: [LaunchStatus] = []
    @Published var previewedZoneSet: String?
    @Published var screenAssignments: [Int: String] = [:]
    @Published var screenCount = 1
    @Published var screenDescriptions: [String] = []
    /// Each screen's visible area in points, for drawing to scale.
    @Published var screenSizes: [CGSize] = []
    @Published var accessibilityGranted = false
    @Published var screenRecordingGranted = false
    @Published var apiWarning: String?
    @Published var configWarning: String?
    @Published var settingsPages: [SettingsPage] = []
    @Published var settingsGroups: [SettingsGroup] = []
    @Published var selectedPage: String?
    @Published var appVersion = ""
    @Published var shotStatus = ""
    // What macOS settled on, rather than what config asked for: a scheme is one
    // per machine and a login item can be refused, so the toggle shows what is
    // actually true. The write goes to config like any setting; applyConfig
    // tells macOS and reads back what it did.
    @Published var loginItemRegistered = true
    @Published var holdsRectangleURLs = false
    @Published var connectedAgents: [String] = []
    /// Non-empty only while a newer release is on offer.
    @Published var updateAvailableVersion = ""
    @Published var updateNotes = ""
    @Published var updateStatus = ""
    @Published var updatePhase = "idle"
    @Published var updateProgress = 0.0

    weak var actions: AppActions?
}

// One entry per page in the settings sidebar. A new module registers its page
// in SettingsPages instead of editing the sidebar.
struct SettingsPage: Identifiable {
    let id: String
    let title: LocalizedStringResource
    let icon: String
    /// The destination it belongs to, by SettingsGroup id.
    var parent: String?
    let make: (AppModel) -> AnyView
}

/// A sidebar destination. Its pages are the ones naming it as their parent, and
/// it expands into them only while it is the one being looked at.
struct SettingsGroup: Identifiable {
    let id: String
    let title: LocalizedStringResource
    let icon: String
}

extension AppModel {
    /// The colour the app draws itself with, ready to hand to SwiftUI.
    var accent: Color { Color(nsColor: config.appearance.accent) }

    // The lists, worked out from `config` when read rather than kept in step
    // with it: a copy would need refreshing after every write, and one write
    // path forgetting is a list that shows yesterday's names.
    var workspaceNames: [String] { config.workspaces.keys.sorted() }
    /// The sets the user made, by name.
    var customZoneSetNames: [String] { config.zoneSets.keys.sorted() }
    /// Every set that can be drawn: the user's first, then the built-in
    /// templates they have not shadowed.
    var zoneSetNames: [String] {
        let custom = customZoneSetNames
        return custom + BuiltinZoneSets.all.keys.sorted().filter { !custom.contains($0) }
    }
    /// Every set that can be drawn, the built-in templates included, which is
    /// more than `config.zoneSets` holds: that is only the ones the user made.
    var zoneSets: [String: [ZoneRect]] {
        BuiltinZoneSets.all.merging(config.zoneSets) { _, user in user }
    }

    /// The pages worth showing: every one whose feature is on, and every one
    /// that has no feature to be off. What the sidebar draws.
    var visiblePages: [SettingsPage] {
        settingsPages.filter { page in Feature.owning(page: page.id).map(isEnabled) ?? true }
    }

    /// The page on show, or the first one before anything has been picked. A
    /// page whose feature was just switched off gives way to the first.
    var currentPage: SettingsPage? {
        visiblePages.first { $0.id == selectedPage } ?? visiblePages.first
    }

    func isEnabled(_ feature: Feature) -> Bool { config.isEnabled(feature) }

    /// The switch for a whole feature, written through config like any setting.
    func binding(_ feature: Feature) -> Binding<Bool> {
        Binding(
            get: { self.config.isEnabled(feature) },
            set: { [weak self] on in
                guard let self else { return }
                var updated = config
                updated.setEnabled(feature, on)
                actions?.update(\.disabledFeatures, to: updated.disabledFeatures)
            }
        )
    }

    /// The same three facts everywhere they are summed up, so Home cannot say
    /// everything is ready while the top bar says a permission is missing.
    var allPermissionsGranted: Bool {
        accessibilityGranted && screenRecordingGranted && apiWarning == nil
    }

    var gettingStarted: GettingStarted {
        GettingStarted(accessibilityGranted: accessibilityGranted,
                       screenRecordingGranted: screenRecordingGranted,
                       snapped: config.sawFirstSnap,
                       agentConnected: config.sawFirstAgent)
    }

    /// The set a screen is on: the default set when nothing was assigned, and
    /// the empty name for edge snapping.
    func assignedZoneSet(onScreen index: Int) -> String {
        screenAssignments[index] ?? BuiltinZoneSets.defaultName
    }

    /// What a screen snaps to. Edge snapping has no zones to match against.
    func zones(onScreen index: Int) -> [ZoneRect] {
        let name = assignedZoneSet(onScreen: index)
        return name.isEmpty ? [] : zoneSets[name] ?? []
    }

    /// The size line for a screen, or nothing for one that has gone away.
    func screenDescription(_ index: Int) -> String {
        screenDescriptions.indices.contains(index) ? screenDescriptions[index] : ""
    }

    func screenSize(_ index: Int) -> CGSize {
        screenSizes.indices.contains(index) ? screenSizes[index] : CGSize(width: 1440, height: 900)
    }

    /// A zone set name nobody has taken, which is `base` itself when it is free.
    func freeZoneSetName(base: String) -> String {
        if zoneSets[base] == nil { return base }
        var index = 2
        while zoneSets["\(base) \(index)"] != nil { index += 1 }
        return "\(base) \(index)"
    }

    /// Opens the editor on a set. A built-in template is duplicated first, so
    /// editing one never changes what the app ships with.
    func editZoneSet(named name: String, onScreen index: Int) {
        guard let actions else { return }
        guard !customZoneSetNames.contains(name) else {
            actions.editZoneSet(name, seed: nil, onScreen: index)
            return
        }
        actions.editZoneSet(freeZoneSetName(base: name + " copy"),
                            seed: zoneSets[name] ?? [], onScreen: index)
    }

    /// A setting, read straight off the config and written straight back. This
    /// is what a settings row binds to; nothing in between needs writing.
    func binding<Value>(_ path: WritableKeyPath<Config, Value>) -> Binding<Value> {
        Binding(
            get: { self.config[keyPath: path] },
            set: { [weak self] value in self?.actions?.update(path, to: value) }
        )
    }

    /// State a manager or macOS owns rather than the config, written through
    /// the command that owns it: keep-awake, stay-active, the login item.
    func binding<Value>(_ keyPath: KeyPath<AppModel, Value>,
                        set: @escaping (AppActions, Value) -> Void) -> Binding<Value> {
        Binding(
            get: { self[keyPath: keyPath] },
            set: { [weak self] value in
                guard let actions = self?.actions else { return }
                set(actions, value)
            }
        )
    }
}
