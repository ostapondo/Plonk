import SwiftUI

// Everything the settings and zone windows can do, in one place. AppDelegate
// implements it; views never touch the managers directly.
protocol AppActions: AnyObject {
    func setAwake(_ on: Bool)
    func setAwakeAllowOnBattery(_ on: Bool)
    func setAwakeAutoWhileCharging(_ on: Bool)
    func setAwakeKeepDisplayOn(_ on: Bool)
    func setAwakeTimeout(minutes: Int)
    func setHotkeys(_ on: Bool)
    func setHotkey(_ action: HotkeyAction, to hotkey: Hotkey)
    func clearHotkey(_ action: HotkeyAction)
    func resetHotkeys()
    func setDragSnap(_ on: Bool)
    func setZonesRequireModifier(_ on: Bool)
    func setZonesModifier(_ name: String)
    /// Apps drag snapping and the placement shortcuts leave alone, one pattern
    /// per line. Matched against the app's name and bundle id, case-insensitively.
    func setExcludedApps(_ patterns: [String])
    func setRestoreZonesOnScreenChange(_ on: Bool)
    /// BCP-47 tags for text recognition; empty lets Vision choose.
    func setTextLanguages(_ tags: [String])
    func setLaunchAtLogin(_ on: Bool)
    func setShotFolder(_ folder: String)
    func setShotCopyToClipboard(_ on: Bool)
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

    /// Nil clears the selection, so any agent may drive again.
    func selectAgent(_ name: String?)
    func setAgentExclusive(_ on: Bool)

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
    @Published var hotkeysEnabled = true
    @Published var unavailableHotkeys: [String] = []
    @Published var hotkeyDisplays: [String: String] = [:]
    @Published var hotkeyParts: [String: [String]] = [:]
    @Published var dragSnapEnabled = true
    @Published var zonesRequireModifier = true
    @Published var zonesModifier = "shift"
    @Published var excludedApps: [String] = []
    @Published var restoreZonesOnScreenChange = true
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
    @Published var selectedPage: String?
    @Published var appVersion = ""
    @Published var shotFolder = "~/Desktop"
    @Published var shotCopyToClipboard = true
    @Published var shotStatus = ""
    @Published var launchAtLogin = true
    @Published var connectedAgents: [String] = []
    @Published var selectedAgent: String?
    @Published var agentExclusive = false
    @Published var updateCheckAutomatically = true
    /// Non-empty only while a newer release is on offer.
    @Published var updateAvailableVersion = ""
    @Published var updateNotes = ""
    @Published var updateStatus = ""
    @Published var updatePhase = "idle"
    @Published var updateProgress = 0.0

    weak var actions: AppActions?
}

// One entry per module in the settings sidebar. A new module registers its page
// in AppDelegate instead of editing SettingsView.
struct SettingsPage: Identifiable {
    let id: String
    let title: String
    let icon: String
    /// Sidebar group heading; nil pins the page above the first one.
    var section: String?
    let make: (AppModel) -> AnyView
}

extension AppModel {
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
