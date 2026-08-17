import SwiftUI

// Everything the settings and zone windows can do, in one place. AppDelegate
// implements it; views never touch the managers directly.
protocol AppActions: AnyObject {
    func setAwake(_ on: Bool)
    func setAwakeAllowOnBattery(_ on: Bool)
    func setAwakeAutoWhileCharging(_ on: Bool)
    func setAwakeKeepDisplayOn(_ on: Bool)
    func setAwakeTimeout(minutes: Int)
    /// Stay active: keep the system idle timer at zero so chat apps go on
    /// showing you as available. Switching it by hand holds against the
    /// schedule until the schedule itself changes.
    func setActive(_ on: Bool)
    func setActiveTimeout(minutes: Int)
    func setActiveSchedule(_ schedule: ActiveSchedule)
    /// Bundle ids. Stay active runs while any of them is running.
    func setActiveApps(_ bundleIDs: [String])
    func setActiveAllowOnBattery(_ on: Bool)
    func openAccessibilitySettings()
    func setHotkeys(_ on: Bool)
    func setHotkey(_ action: HotkeyAction, to hotkey: Hotkey)
    func clearHotkey(_ action: HotkeyAction)
    func resetHotkeys()
    func setDragSnap(_ on: Bool)
    func setZonesRequireModifier(_ on: Bool)
    func setZonesModifier(_ name: String)
    /// Empty space left around each zone, in points — in the overlay and in
    /// the window that lands there.
    func setZoneGap(_ points: Double)
    func setZoneOpacity(_ value: Double)
    /// "#RRGGBB", or nil to follow the system accent colour.
    func setZoneColor(_ hex: String?)
    func setZoneNumbersVisible(_ on: Bool)
    func setZonesOnAllMonitors(_ on: Bool)
    /// How near the shared edge of two zones the cursor has to come before a
    /// drop covers both, in points. Zero switches it off.
    func setZoneEdgeSpan(_ points: Double)
    /// Move and resize a window by dragging anywhere inside it with a modifier
    /// held, instead of aiming for the title bar or the border.
    func setGrabMove(_ on: Bool)
    func setGrabMoveModifier(_ name: String)
    func setGrabMoveResize(_ on: Bool)
    func setGrabMoveShowGeometry(_ on: Bool)
    /// Apps drag snapping and the placement shortcuts leave alone, one pattern
    /// per line. Matched against the app's name and bundle id, case-insensitively.
    /// A ring on every click, for screen recordings.
    func setHighlightClicks(_ on: Bool)
    func setCrosshairs(_ on: Bool)
    func setExcludedApps(_ patterns: [String])
    func setRestoreZonesOnScreenChange(_ on: Bool)
    /// Send a newly opened window where that app's windows have been going.
    func setPlaceNewWindows(_ on: Bool)
    /// BCP-47 tags for text recognition; empty lets Vision choose.
    func setTextLanguages(_ tags: [String])
    func setLaunchAtLogin(_ on: Bool)
    func setShotFolder(_ folder: String)
    func setShotCopyToClipboard(_ on: Bool)
    /// How different a pixel has to be before the ruler calls it an edge,
    /// on one channel of 255. See EdgeDetector.
    func setRulerTolerance(_ value: Int)
    /// Hands the user the ruler: hover to size what is under the pointer, drag
    /// for a distance.
    func startRuler()
    func capture(_ mode: CaptureMode)
    func flashZones()
    func reportBug()

    func assignZoneSet(_ name: String?, toScreen index: Int)
    func updateZoneSet(_ name: String, zones: [ZoneRect])
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
    func cancelWorkspaceLaunch()

    /// "system", "light" or "dark". Anything else reads as "system".
    func setTheme(_ name: String)
    /// "#RRGGBB", or nil to follow the system accent colour.
    func setAccent(_ hex: String?)
    /// Everything the palette can run, in the order it should be offered.
    func paletteCommands() -> [PlonkCommand]
    func openCommandPalette()

    /// Nil clears the selection, so any agent may drive again.
    func selectAgent(_ name: String?)
    func setAgentExclusive(_ on: Bool)
    func setVoiceLocalCommands(_ on: Bool)
    func hideGettingStarted()

    func setUpdateCheckAutomatically(_ on: Bool)
    func checkForUpdates()
    /// Quits and relaunches into the new version when it succeeds.
    func installUpdate()
    func openReleasePage()
}

final class AppModel: ObservableObject {
    @Published var awakeOn = false
    @Published var awakeRequested = false
    @Published var awakeAllowOnBattery = true
    @Published var awakeAutoWhileCharging = false
    @Published var awakeKeepDisplayOn = true
    @Published var awakeTimeoutMinutes = 0
    @Published var activeOn = false
    @Published var activeRequested = false
    @Published var activeStatus: LocalizedStringResource = .activeStatusOff
    @Published var activeTrusted = true
    @Published var activeSchedule = ActiveSchedule()
    @Published var activeApps: [String] = []
    @Published var activeAllowOnBattery = false
    @Published var activeTimeoutMinutes = 0
    @Published var hotkeysEnabled = true
    @Published var unavailableHotkeys: [String] = []
    @Published var hotkeyDisplays: [String: String] = [:]
    @Published var hotkeyParts: [String: [String]] = [:]
    @Published var dragSnapEnabled = true
    @Published var zonesRequireModifier = true
    @Published var zonesModifier = "shift"
    @Published var zoneGap = 0.0
    @Published var zoneOpacity = 1.0
    @Published var zoneColorHex: String?
    @Published var zoneNumbersVisible = true
    @Published var zonesOnAllMonitors = false
    @Published var zoneEdgeSpan = 16.0
    @Published var grabMoveEnabled = false
    @Published var grabMoveModifier = "option"
    @Published var grabMoveResize = true
    @Published var grabMoveShowGeometry = true
    @Published var highlightClicksEnabled = false
    @Published var crosshairsEnabled = false
    @Published var excludedApps: [String] = []
    @Published var restoreZonesOnScreenChange = true
    @Published var placeNewWindows = false
    @Published var textLanguages: [String] = []
    @Published var supportedTextLanguages: [String] = []
    @Published var workspaceNames: [String] = []
    @Published var workspaces: [String: Workspace] = [:]
    /// Non-empty only while a workspace is coming up.
    @Published var launchingWorkspace: String?
    @Published var launchStatuses: [LaunchStatus] = []
    @Published var zoneSetNames: [String] = []
    @Published var zoneSets: [String: [ZoneRect]] = [:]
    @Published var customZoneSetNames: [String] = []
    @Published var previewedZoneSet: String?
    @Published var screenAssignments: [Int: String] = [:]
    @Published var screenCount = 1
    @Published var screenDescriptions: [String] = []
    @Published var accessibilityGranted = false
    @Published var screenRecordingGranted = false
    @Published var apiWarning: String?
    @Published var configWarning: String?
    @Published var settingsPages: [SettingsPage] = []
    @Published var settingsGroups: [SettingsGroup] = []
    @Published var selectedPage: String?
    @Published var appearance = AppearanceSettings()
    @Published var appVersion = ""
    @Published var shotFolder = "~/Desktop"
    @Published var shotCopyToClipboard = true
    @Published var shotStatus = ""
    @Published var rulerEdgeTolerance = EdgeDetector.defaultTolerance
    @Published var launchAtLogin = true
    @Published var connectedAgents: [String] = []
    @Published var selectedAgent: String?
    @Published var agentExclusive = false
    @Published var voiceLocalCommands = true
    @Published var sawFirstSnap = false
    @Published var sawFirstAgent = false
    @Published var gettingStartedHidden = false
    @Published var updateCheckAutomatically = true
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
    var accent: Color { Color(nsColor: appearance.accent) }

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

    /// Reads published state, writes through AppActions.
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
