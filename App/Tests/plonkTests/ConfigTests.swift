import Testing
import Foundation
@testable import plonk

/// The one place a prompt from voice or /agents/ask meets a shell.
struct AgentAdapterTests {

    @Test func thePromptTravelsInTheEnvironmentNotTheCommandLine() {
        let invocation = AgentAdapter.invocation(command: "claude -p {prompt}", prompt: "browser left")
        #expect(invocation.command == "claude -p \"$PLONK_PROMPT\"")
        #expect(invocation.environment["PLONK_PROMPT"] == "browser left")
    }

    @Test func aTemplateWithoutThePlaceholderGetsOneAppended() {
        let invocation = AgentAdapter.invocation(command: "codex exec", prompt: "hi")
        #expect(invocation.command == "codex exec \"$PLONK_PROMPT\"")
    }

    /// Shell metacharacters used to escape a quoted template and run.
    @Test func metacharactersNeverReachTheShell() {
        let nasty = "open docs; rm -rf ~/tmp && echo $(whoami) `id` 'quoted'"
        for template in ["claude -p {prompt}", "mytool --ask '{prompt}'", "mytool --ask \"{prompt}\""] {
            let invocation = AgentAdapter.invocation(command: template, prompt: nasty)
            #expect(!invocation.command.contains("rm -rf"))
            #expect(!invocation.command.contains("whoami"))
            #expect(invocation.environment["PLONK_PROMPT"] == nasty)
        }
    }
}
import Foundation
@testable import plonk

struct ConfigTests {

    private func decode(_ json: String) throws -> Config {
        try JSONDecoder().decode(Config.self, from: Data(json.utf8))
    }

    @Test func emptyJSONYieldsDefaults() throws {
        let config = try decode("{}")
        #expect(config.hotkeysEnabled)
        #expect(config.dragSnapEnabled)
        #expect(config.zonesRequireShift)
        #expect(config.zonesModifier == "shift")
        #expect(config.awakeAllowOnBattery)
        #expect(!config.awakeAutoWhileCharging)
        #expect(config.awakeKeepDisplayOn)
        #expect(config.awakeTimeoutMinutes == 0)
        #expect(config.workspaces.isEmpty)
        #expect(config.zoneSets.isEmpty)
    }

    @Test func oldConfigWithoutNewKeysStillDecodes() throws {
        let config = try decode(#"{"hotkeysEnabled": false, "layouts": {}}"#)
        #expect(!config.hotkeysEnabled)
        #expect(config.zonesModifier == "shift")
    }

    // MARK: - Workspaces

    @Test func savedLayoutsBecomeWorkspaces() throws {
        let config = try decode(#"""
        {"layouts": {"work": [
            {"app": "Safari", "x": 0, "y": 0, "w": 0.5, "h": 1},
            {"app": "Terminal", "screen": 1, "x": 0.5, "y": 0, "w": 0.5, "h": 1}
        ]}}
        """#)
        let work = try #require(config.workspaces["work"])
        #expect(work.items.count == 2)
        #expect(work.items[0].app == "Safari")
        #expect(work.items[1].screen == 1)
        // Nothing to launch from, but the arrangement is intact.
        #expect(work.items[0].bundleID == nil)
        #expect(work.moveExisting)
    }

    @Test func migratedConfigStopsWritingTheOldKey() throws {
        let config = try decode(#"{"layouts": {"work": [{"app": "Safari", "x": 0, "y": 0, "w": 1, "h": 1}]}}"#)
        let json = try #require(String(data: JSONEncoder().encode(config), encoding: .utf8))
        #expect(json.contains("\"workspaces\""))
        #expect(!json.contains("\"layouts\""))
    }

    @Test func workspacesWinOverALeftoverLayoutsKey() throws {
        let config = try decode(#"""
        {"layouts": {"old": [{"app": "Safari", "x": 0, "y": 0, "w": 1, "h": 1}]},
         "workspaces": {"new": {"items": [{"app": "Mail", "x": 0, "y": 0, "w": 1, "h": 1}]}}}
        """#)
        #expect(config.workspaces.keys.sorted() == ["new"])
    }

    @Test func workspaceRoundTripKeepsLaunchDetails() throws {
        var config = Config()
        config.workspaces["work"] = Workspace(items: [
            WorkspaceItem(app: "Visual Studio Code", bundleID: "com.microsoft.VSCode",
                          bundlePath: "/Applications/Visual Studio Code.app",
                          windowIndex: 1, screen: 0, screenUUID: "uuid-1",
                          x: 0, y: 0, w: 0.5, h: 1, minimized: true,
                          urls: ["~/Projects/plonk"], args: ["--new-window"]),
        ], moveExisting: false)
        let decoded = try JSONDecoder().decode(Config.self, from: JSONEncoder().encode(config))
        let item = try #require(decoded.workspaces["work"]?.items.first)
        #expect(item.bundleID == "com.microsoft.VSCode")
        #expect(item.windowIndex == 1)
        #expect(item.screenUUID == "uuid-1")
        #expect(item.minimized == true)
        #expect(item.urls == ["~/Projects/plonk"])
        #expect(item.args == ["--new-window"])
        #expect(decoded.workspaces["work"]?.moveExisting == false)
    }

    @Test func roundTripPreservesValues() throws {
        var config = Config()
        config.zonesModifier = "option"
        config.zoneSets["Mine"] = [ZoneRect(0, 0, 0.5, 1)]
        config.screenZoneSets["0"] = "Mine"
        config.awakeTimeoutMinutes = 30
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(Config.self, from: data)
        #expect(decoded.zonesModifier == "option")
        #expect(decoded.screenZoneSets["0"] == "Mine")
        #expect(decoded.zoneSets["Mine"]?.count == 1)
        #expect(decoded.awakeTimeoutMinutes == 30)
    }

    @Test func awakeSessionSurvivesARoundTrip() throws {
        var config = Config()
        config.awakeRequested = true
        config.awakeSessionEnd = 1_800_000_000
        let decoded = try JSONDecoder().decode(Config.self, from: JSONEncoder().encode(config))
        #expect(decoded.awakeRequested)
        #expect(decoded.awakeSessionEnd == 1_800_000_000)
    }

    @Test func configWrittenBeforeAwakeWasPersistedStillDecodes() throws {
        let config = try decode(#"{"awakeTimeoutMinutes": 30}"#)
        #expect(!config.awakeRequested)
        #expect(config.awakeSessionEnd == nil)
    }

    // MARK: - Zone assignment

    @Test func unassignedScreenGetsDefaultSet() {
        let config = Config()
        #expect(config.zones(forKeys: ["uuid-1", "0"]).count == BuiltinZoneSets.all[BuiltinZoneSets.defaultName]?.count)
    }

    @Test func emptyAssignmentMeansEdgeSnapping() {
        var config = Config()
        config.screenZoneSets["uuid-1"] = ""
        #expect(config.zones(forKeys: ["uuid-1", "0"]).isEmpty)
    }

    @Test func customSetWinsOverBuiltinName() {
        var config = Config()
        config.zoneSets["Halves"] = [ZoneRect(0, 0, 1, 1)]
        config.screenZoneSets["uuid-1"] = "Halves"
        #expect(config.zones(forKeys: ["uuid-1"]).count == 1)
    }

    @Test func unknownSetNameYieldsNoZones() {
        var config = Config()
        config.screenZoneSets["uuid-1"] = "does-not-exist"
        #expect(config.zones(forKeys: ["uuid-1"]).isEmpty)
    }

    @Test func indexKeyStillResolvesForOlderConfigs() {
        var config = Config()
        config.screenZoneSets["0"] = "Quarters"
        #expect(config.zoneAssignment(forKeys: ["uuid-1", "0"]) == "Quarters")
        #expect(config.zones(forKeys: ["uuid-1", "0"]).count == 4)
    }

    @Test func uuidKeyWinsOverStaleIndexKey() {
        var config = Config()
        config.screenZoneSets["0"] = "Quarters"
        config.screenZoneSets["uuid-1"] = "Thirds"
        #expect(config.zoneAssignment(forKeys: ["uuid-1", "0"]) == "Thirds")
    }

    @Test func assigningClearsEveryStaleKeyForThatScreen() {
        var config = Config()
        config.screenZoneSets["0"] = "Quarters"
        config.assignZoneSet("Thirds", forKeys: ["uuid-1", "0"])
        #expect(config.screenZoneSets["uuid-1"] == "Thirds")
        #expect(config.screenZoneSets["0"] == nil)
    }

    @Test func assigningNilRestoresTheDefaultSet() {
        var config = Config()
        config.assignZoneSet("Thirds", forKeys: ["uuid-1", "0"])
        config.assignZoneSet(nil, forKeys: ["uuid-1", "0"])
        #expect(config.zoneAssignment(forKeys: ["uuid-1", "0"]) == nil)
    }

    @Test func forgettingASetDropsItsAssignments() {
        var config = Config()
        config.zoneSets["Mine"] = [ZoneRect(0, 0, 1, 1)]
        config.assignZoneSet("Mine", forKeys: ["uuid-1"])
        config.forgetZoneSet(named: "Mine")
        #expect(config.zoneSets["Mine"] == nil)
        #expect(config.screenZoneSets.isEmpty)
    }
}

struct ConfigStoreTests {

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("plonk-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func savesAndReloads() {
        let dir = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = ConfigStore(directory: dir)
        store.update {
            $0.workspaces["work"] = Workspace(items: [
                WorkspaceItem(app: "Safari", x: 0, y: 0, w: 0.5, h: 1),
            ])
        }

        let reopened = ConfigStore(directory: dir)
        reopened.load()
        #expect(reopened.config.workspaces["work"]?.items.count == 1)
    }

    @Test func corruptFileIsSetAsideInsteadOfSilentlyOverwritten() throws {
        let dir = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("config.json")
        try Data("{ not json".utf8).write(to: file)

        let store = ConfigStore(directory: dir)
        store.load()

        #expect(store.config.workspaces.isEmpty)
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("config.json.bad").path))
        // Losing every saved workspace has to reach the user, not just the log.
        #expect(store.loadFailure?.contains("config.json.bad") == true)
    }

    @Test func aReadableConfigReportsNoFailure() {
        let dir = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ConfigStore(directory: dir)
        store.update { $0.shotFolder = "~/Pictures" }

        let reopened = ConfigStore(directory: dir)
        reopened.load()
        #expect(reopened.loadFailure == nil)
    }
}

struct FracRectParsingTests {

    @Test func parsesAFrameInRange() throws {
        let frac = try #require(FracRect.parse(["x": 0.5, "y": 0, "w": 0.5, "h": 1]))
        #expect(abs(frac.x - 0.5) < 0.001)
        #expect(abs(frac.w - 0.5) < 0.001)
    }

    @Test func rejectsAFrameReachingPastTheScreen() {
        #expect(FracRect.parse(["x": 0.6, "y": 0, "w": 0.5, "h": 1]) == nil)
        #expect(FracRect.parse(["x": 0, "y": 0, "w": 2, "h": 1]) == nil)
    }

    @Test func rejectsNegativeOriginAndEmptySize() {
        #expect(FracRect.parse(["x": -0.1, "y": 0, "w": 0.5, "h": 1]) == nil)
        #expect(FracRect.parse(["x": 0, "y": 0, "w": 0, "h": 1]) == nil)
    }

    /// get_state rounds to two decimals, so a frame fed straight back has to fit.
    @Test func acceptsRoundedFullScreenFrames() {
        #expect(FracRect.parse(["x": 0, "y": 0, "w": 1, "h": 1]) != nil)
    }

    @Test func rejectsAMissingComponent() {
        #expect(FracRect.parse(["x": 0, "y": 0, "w": 1]) == nil)
        #expect(FracRect.parse(nil) == nil)
    }
}

struct LayoutItemSpecTests {

    @Test func parsesFullDictionary() throws {
        let spec = try #require(LayoutItemSpec(dict: [
            "app": "Safari",
            "title": "GitHub",
            "screen": 1,
            "frame": ["x": 0, "y": 0.5, "w": 0.5, "h": 0.5],
        ]))
        #expect(spec.app == "Safari")
        #expect(spec.title == "GitHub")
        #expect(spec.screen == 1)
        #expect(abs(spec.h - 0.5) < 0.001)
    }

    @Test func rejectsMissingApp() {
        #expect(LayoutItemSpec(dict: ["frame": ["x": 0, "y": 0, "w": 1, "h": 1]]) == nil)
    }

    @Test func rejectsMissingFrameComponent() {
        #expect(LayoutItemSpec(dict: ["app": "Safari", "frame": ["x": 0, "y": 0, "w": 1]]) == nil)
    }

    @Test func rejectsFrameOutsideTheScreen() {
        #expect(LayoutItemSpec(dict: ["app": "Safari", "frame": ["x": 0.6, "y": 0, "w": 0.5, "h": 1]]) == nil)
        #expect(LayoutItemSpec(dict: ["app": "Safari", "frame": ["x": 0, "y": 0, "w": 0, "h": 1]]) == nil)
    }
}

struct WorkspacePlanTests {

    private func item(_ app: String, bundleID: String? = nil,
                      urls: [String]? = nil, args: [String]? = nil) -> WorkspaceItem {
        WorkspaceItem(app: app, bundleID: bundleID, x: 0, y: 0, w: 0.5, h: 1, urls: urls, args: args)
    }

    @Test func windowsOfOneAppLaunchTogether() {
        let workspace = Workspace(items: [
            item("Safari", bundleID: "com.apple.Safari"),
            item("Terminal", bundleID: "com.apple.Terminal"),
            item("Safari", bundleID: "com.apple.Safari"),
        ])
        let groups = WorkspacePlan.groups(for: workspace)
        #expect(groups.count == 2)
        #expect(groups[0].itemIndices == [0, 2])
        #expect(groups[1].itemIndices == [1])
    }

    @Test func groupsFollowTheOrderTheyWereSavedIn() {
        let workspace = Workspace(items: [item("Terminal"), item("Safari")])
        #expect(WorkspacePlan.groups(for: workspace).map(\.app) == ["Terminal", "Safari"])
    }

    @Test func itemsWithoutABundleIDGroupByName() {
        let workspace = Workspace(items: [item("Safari"), item("safari")])
        #expect(WorkspacePlan.groups(for: workspace).count == 1)
    }

    @Test func whatAnAppOpensIsMergedAcrossItsWindows() {
        let workspace = Workspace(items: [
            item("Code", bundleID: "com.microsoft.VSCode", urls: ["~/a"], args: ["--new-window"]),
            item("Code", bundleID: "com.microsoft.VSCode", urls: ["~/b"]),
        ])
        let group = WorkspacePlan.groups(for: workspace)[0]
        #expect(group.urls == ["~/a", "~/b"])
        #expect(group.args == ["--new-window"])
    }

    @Test func appsListsEachAppOnce() {
        let workspace = Workspace(items: [
            item("Safari", bundleID: "com.apple.Safari"),
            item("Safari", bundleID: "com.apple.Safari"),
            item("Mail", bundleID: "com.apple.mail"),
        ])
        #expect(workspace.apps == ["Safari", "Mail"])
    }

    @Test func bareAndTildePathsBecomeFileURLs() throws {
        let home = try #require(WorkspaceLauncher.fileOrWebURL("~/Projects"))
        #expect(home.isFileURL)
        #expect(!home.path.hasPrefix("~"))
        #expect(WorkspaceLauncher.fileOrWebURL("/tmp")?.isFileURL == true)
        #expect(WorkspaceLauncher.fileOrWebURL("https://example.com")?.scheme == "https")
        #expect(WorkspaceLauncher.fileOrWebURL("  ") == nil)
        // Without a scheme there is nothing sensible to open.
        #expect(WorkspaceLauncher.fileOrWebURL("example.com") == nil)
    }
}

struct WorkspaceItemParsingTests {

    @Test func parsesEverythingAnAgentCanSend() throws {
        let item = try #require(WorkspaceItem(dict: [
            "app": "Visual Studio Code",
            "bundle_id": "com.microsoft.VSCode",
            "window_index": 2,
            "screen": 1,
            "screen_uuid": "uuid-1",
            "frame": ["x": 0, "y": 0.5, "w": 0.5, "h": 0.5],
            "minimized": true,
            "urls": ["~/Projects", ""],
            "args": ["--new-window"],
        ]))
        #expect(item.bundleID == "com.microsoft.VSCode")
        #expect(item.windowIndex == 2)
        #expect(item.screenUUID == "uuid-1")
        #expect(item.minimized == true)
        #expect(item.urls == ["~/Projects"])
        #expect(item.launchKey == "com.microsoft.VSCode")
    }

    @Test func rejectsMissingApp() {
        #expect(WorkspaceItem(dict: ["frame": ["x": 0, "y": 0, "w": 1, "h": 1]]) == nil)
    }

    /// The frames WindowManager reports are built from CGFloats, which is its
    /// own struct: a [String: CGFloat] does not cast to [String: Double], and a
    /// snapshot that trips over that silently saves nothing.
    @Test func parsesAWindowListedWithCoreGraphicsNumbers() throws {
        var entry: [String: Any] = [
            "app": "Google Chrome",
            "bundle_id": "com.google.Chrome",
            "bundle_path": "/Applications/Google Chrome.app",
            "minimized": false,
            "screen": 0,
            "window_index": 1,
        ]
        let width: CGFloat = 1728
        entry["fraction"] = [
            "x": Double(round(0 / width * 100) / 100),
            "y": 0.0,
            "w": Double(round(width / width * 100) / 100),
            "h": 1.0,
        ]
        let item = try #require(WorkspaceItem(window: entry, screenUUID: "uuid-1"))
        #expect(item.app == "Google Chrome")
        #expect(item.bundleID == "com.google.Chrome")
        #expect(item.windowIndex == 1)
        #expect(item.screenUUID == "uuid-1")
        #expect(item.w == 1)
    }

    @Test func minimizedWindowsAreNotWorthSnapshotting() {
        let entry: [String: Any] = [
            "app": "Claude", "minimized": true, "screen": 0,
            "fraction": ["x": 0.0, "y": 0.0, "w": 1.0, "h": 1.0],
        ]
        #expect(WorkspaceItem(window: entry) == nil)
    }

    @Test func aWindowWithNoFractionIsSkipped() {
        #expect(WorkspaceItem(window: ["app": "Claude", "minimized": false, "screen": 0]) == nil)
    }

    @Test func rejectsMissingFrameComponent() {
        #expect(WorkspaceItem(dict: ["app": "Safari", "frame": ["x": 0, "y": 0, "w": 1]]) == nil)
    }

    @Test func rejectsFrameOutsideTheScreen() {
        #expect(WorkspaceItem(dict: ["app": "Safari", "frame": ["x": 0, "y": 0.5, "w": 1, "h": 0.7]]) == nil)
    }

    @Test func roundTripsThroughItsDictionary() throws {
        let original = WorkspaceItem(app: "Safari", bundleID: "com.apple.Safari",
                                     screen: 1, x: 0.5, y: 0, w: 0.5, h: 1)
        let copy = try #require(WorkspaceItem(dict: original.asDict))
        #expect(copy.app == original.app)
        #expect(copy.bundleID == original.bundleID)
        #expect(copy.screen == 1)
        #expect(abs(copy.x - 0.5) < 0.001)
    }
}

struct ZoneRectParsingTests {

    @Test func rejectsZeroSize() {
        #expect(ZoneRect(dict: ["x": 0, "y": 0, "w": 0, "h": 1]) == nil)
    }

    @Test func rejectsNegativeOrigin() {
        #expect(ZoneRect(dict: ["x": -0.1, "y": 0, "w": 0.5, "h": 1]) == nil)
    }

    @Test func rejectsZoneReachingPastTheScreen() {
        #expect(ZoneRect(dict: ["x": 0.6, "y": 0, "w": 0.5, "h": 1]) == nil)
        #expect(ZoneRect(dict: ["x": 0, "y": 0.5, "w": 1, "h": 0.7]) == nil)
    }

    @Test func parsesValidDictionary() throws {
        let zone = try #require(ZoneRect(dict: ["x": 0.25, "y": 0, "w": 0.5, "h": 1]))
        #expect(abs(zone.x - 0.25) < 0.001)
        #expect(abs((zone.asDict["w"] ?? -1) - 0.5) < 0.001)
    }
}
