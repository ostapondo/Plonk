import Testing
import Foundation
@testable import plonk

// Routes that do not touch Accessibility or the screen. Window placement and
// /state need a real desktop session, so they stay out of the suite.
struct RouterTests {

    private final class Harness {
        let directory: URL
        let store: ConfigStore
        let router: Router

        init() {
            directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("plonk-router-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            store = ConfigStore(directory: directory)
            router = Router(store: store, windows: WindowManager(), awake: AwakeManager())
            // Mirrors AppDelegate.setupServer, which owns this wiring.
            store.didMutate = { [router] in router.changes.bump("config") }
        }

        deinit { try? FileManager.default.removeItem(at: directory) }

        func post(_ path: String, _ body: [String: Any]) -> HTTPResponse {
            send(HTTPRequest(method: "POST", path: path, headers: [:], body: body))
        }

        func send(_ request: HTTPRequest) -> HTTPResponse {
            var result: HTTPResponse?
            router.handle(request) { result = $0 }
            return result ?? .failed("no response")
        }
    }

    private let sampleItem: [String: Any] = [
        "app": "Safari",
        "frame": ["x": 0, "y": 0, "w": 0.5, "h": 1],
    ]

    /// The MCP server's liveness check, so it must not depend on Accessibility.
    @Test func pingAnswersWithoutPermissions() {
        let h = Harness()
        let response = h.send(HTTPRequest(method: "GET", path: "/ping", headers: [:], body: [:]))
        #expect(response.status == 200)
        #expect(response.json["ok"] as? Bool == true)
    }

    @Test func unknownRouteIsNotFound() {
        let h = Harness()
        #expect(h.send(HTTPRequest(method: "GET", path: "/nope", headers: [:], body: [:])).status == 404)
    }

    @Test func layoutWithoutItemsIsRejected() {
        let h = Harness()
        #expect(h.post("/layout", [:]).status == 400)
        #expect(h.post("/layout", ["items": []]).status == 400)
    }

    @Test func savingAWorkspaceStoresIt() {
        let h = Harness()
        let response = h.post("/workspaces/save", ["name": " work ", "items": [sampleItem]])
        #expect(response.status == 200)
        #expect(response.json["saved"] as? String == "work")
        #expect(h.store.config.workspaces["work"]?.items.count == 1)
    }

    @Test func savingAWorkspaceKeepsWhatAnAppShouldOpen() throws {
        let h = Harness()
        let item: [String: Any] = [
            "app": "Visual Studio Code",
            "bundle_id": "com.microsoft.VSCode",
            "frame": ["x": 0, "y": 0, "w": 0.5, "h": 1],
            "urls": ["~/Projects/plonk"],
        ]
        #expect(h.post("/workspaces/save", ["name": "work", "items": [item]]).status == 200)
        let saved = try #require(h.store.config.workspaces["work"]?.items.first)
        #expect(saved.bundleID == "com.microsoft.VSCode")
        #expect(saved.urls == ["~/Projects/plonk"])
    }

    @Test func savingAWorkspaceNeedsAName() {
        let h = Harness()
        #expect(h.post("/workspaces/save", ["items": [sampleItem]]).status == 400)
        #expect(h.post("/workspaces/save", ["name": "   ", "items": [sampleItem]]).status == 400)
    }

    /// Editing the items of a workspace must not silently reset how it launches.
    @Test func resavingKeepsTheLaunchBehavior() {
        let h = Harness()
        _ = h.post("/workspaces/save", ["name": "work", "items": [sampleItem], "move_existing": false])
        _ = h.post("/workspaces/save", ["name": "work", "items": [sampleItem]])
        #expect(h.store.config.workspaces["work"]?.moveExisting == false)
    }

    /// A frame outside the screen used to be saved and then placed the window
    /// where nobody could reach it.
    @Test func savingRejectsFramesOutsideTheScreen() {
        let h = Harness()
        let outside: [String: Any] = ["app": "Safari", "frame": ["x": 0.6, "y": 0, "w": 0.5, "h": 1]]
        #expect(h.post("/workspaces/save", ["name": "work", "items": [outside]]).status == 400)
        #expect(h.store.config.workspaces["work"] == nil)
    }

    /// One bad item used to be dropped silently, saving a workspace short a window.
    @Test func savingRejectsTheWholeRequestWhenAnItemIsBad() {
        let h = Harness()
        let bad: [String: Any] = ["frame": ["x": 0, "y": 0, "w": 1, "h": 1]]
        #expect(h.post("/workspaces/save", ["name": "work", "items": [sampleItem, bad]]).status == 400)
        #expect(h.store.config.workspaces["work"] == nil)
    }

    @Test func layoutReportsAnOutOfRangeFramePerItem() throws {
        let h = Harness()
        let outside: [String: Any] = ["app": "Safari", "frame": ["x": 0, "y": 0, "w": 2, "h": 1]]
        let response = h.post("/layout", ["items": [outside]])
        #expect(response.status == 200)
        let results = try #require(response.json["results"] as? [[String: Any]])
        #expect(results.first?["ok"] as? Bool == false)
    }

    @Test func launchingAnUnknownWorkspaceIsNotFound() {
        let h = Harness()
        #expect(h.post("/workspaces/launch", ["name": "nope"]).status == 404)
    }

    @Test func launchingPassesTheWorkspaceAndScreenOn() throws {
        let h = Harness()
        _ = h.post("/workspaces/save", ["name": "work", "items": [sampleItem]])
        var launched: (name: String, apps: [String], screen: Int?)?
        h.router.launchWorkspace = { name, workspace, screen, done in
            launched = (name, workspace.apps, screen)
            done([["ok": true, "app": "Safari"]])
        }
        let response = h.post("/workspaces/launch", ["name": "work", "screen": 1])
        #expect(response.status == 200)
        #expect(response.json["ok"] as? Bool == true)
        #expect(launched?.name == "work")
        #expect(launched?.apps == ["Safari"])
        #expect(launched?.screen == 1)
    }

    @Test func deletingReportsWhetherItExisted() {
        let h = Harness()
        _ = h.post("/workspaces/save", ["name": "work", "items": [sampleItem]])
        #expect(h.post("/workspaces/delete", ["name": "work"]).status == 200)
        #expect(h.post("/workspaces/delete", ["name": "work"]).status == 404)
    }

    /// Saved layouts became workspaces; the old paths still reach them.
    @Test func layoutRoutesAreAliasesOfTheWorkspaceRoutes() {
        let h = Harness()
        #expect(h.post("/layouts/save", ["name": "work", "items": [sampleItem]]).status == 200)
        #expect(h.store.config.workspaces["work"]?.items.count == 1)

        var launchedName: String?
        h.router.launchWorkspace = { name, _, _, done in
            launchedName = name
            done([])
        }
        #expect(h.post("/layouts/apply", ["name": "work"]).status == 200)
        #expect(launchedName == "work")
        #expect(h.post("/layouts/delete", ["name": "work"]).status == 200)
    }

    @Test func workspaceChangesNotifyTheUI() {
        let h = Harness()
        var notifications = 0
        h.router.didChangeLayouts = { notifications += 1 }
        _ = h.post("/workspaces/save", ["name": "work", "items": [sampleItem]])
        _ = h.post("/workspaces/delete", ["name": "work"])
        #expect(notifications == 2)
    }

    @Test func zoneSetsAreValidatedAgainstScreenBounds() {
        let h = Harness()
        let outside: [String: Any] = ["x": 0.6, "y": 0, "w": 0.5, "h": 1]
        #expect(h.post("/zones/save", ["name": "bad", "zones": [outside]]).status == 400)
        #expect(h.post("/zones/save", ["name": "bad", "zones": []]).status == 400)
        #expect(h.store.config.zoneSets["bad"] == nil)
    }

    @Test func savingAZoneSetStoresIt() {
        let h = Harness()
        let zones: [[String: Any]] = [
            ["x": 0, "y": 0, "w": 0.5, "h": 1],
            ["x": 0.5, "y": 0, "w": 0.5, "h": 1],
        ]
        let response = h.post("/zones/save", ["name": "coding", "zones": zones])
        #expect(response.status == 200)
        #expect(h.store.config.zoneSets["coding"]?.count == 2)
    }

    @Test func assigningAnUnknownZoneSetIsNotFound() {
        let h = Harness()
        #expect(h.post("/zones/assign", ["screen": 0, "name": "nope"]).status == 404)
    }

    @Test func assigningNeedsAScreen() {
        let h = Harness()
        #expect(h.post("/zones/assign", ["name": "Halves"]).status == 400)
    }

    @Test func edgeSnappingIsStoredAsAnEmptyAssignment() {
        let h = Harness()
        #expect(h.post("/zones/assign", ["screen": 0, "name": "edge"]).status == 200)
        #expect(h.store.config.zones(forKeys: ScreenIdentity.keys(forIndex: 0)).isEmpty)
    }

    @Test func deletingAZoneSetAlsoClearsItsAssignments() {
        let h = Harness()
        let zones: [[String: Any]] = [["x": 0, "y": 0, "w": 1, "h": 1]]
        _ = h.post("/zones/save", ["name": "solo", "zones": zones, "screen": 0])
        #expect(h.store.config.screenZoneSets.values.contains("solo"))

        #expect(h.post("/zones/delete", ["name": "solo"]).status == 200)
        #expect(h.store.config.zoneSets["solo"] == nil)
        #expect(!h.store.config.screenZoneSets.values.contains("solo"))
        #expect(h.post("/zones/delete", ["name": "solo"]).status == 404)
    }

    @Test func captureReportsCancellation() {
        let h = Harness()
        h.router.capture = { _, _, done in done(nil) }
        #expect(h.post("/shot/capture", ["mode": "region"]).status == 409)
    }

    @Test func renamingAWorkspaceKeepsItsContentsAndBehavior() {
        let h = Harness()
        _ = h.post("/workspaces/save", ["name": "work", "items": [sampleItem], "move_existing": false])
        #expect(h.post("/workspaces/rename", ["from": "work", "to": "review"]).status == 200)
        #expect(h.store.config.workspaces["work"] == nil)
        #expect(h.store.config.workspaces["review"]?.moveExisting == false)
        #expect(h.post("/workspaces/rename", ["from": "work", "to": "x"]).status == 404)
    }

    @Test func renamingOntoAnExistingWorkspaceIsRejected() {
        let h = Harness()
        _ = h.post("/workspaces/save", ["name": "a", "items": [sampleItem]])
        _ = h.post("/workspaces/save", ["name": "b", "items": [sampleItem]])
        #expect(h.post("/workspaces/rename", ["from": "a", "to": "b"]).status == 409)
        #expect(h.store.config.workspaces["a"] != nil)
        #expect(h.store.config.workspaces["b"] != nil)
        #expect(h.post("/workspaces/rename", ["from": "a", "to": "a"]).status == 200)
    }

    @Test func renamingNeedsBothNames() {
        let h = Harness()
        #expect(h.post("/workspaces/rename", ["from": "a"]).status == 400)
        #expect(h.post("/workspaces/rename", ["to": "b"]).status == 400)
    }

    // MARK: - Agents

    @Test func helloRegistersTheAgent() {
        let h = Harness()
        let response = h.post("/agents/hello", ["name": "cursor", "version": "1.2", "pid": 7])
        #expect(response.status == 200)
        #expect(h.router.agents.onlineNames() == ["cursor"])
    }

    @Test func helloNeedsAName() {
        let h = Harness()
        #expect(h.post("/agents/hello", [:]).status == 400)
    }

    @Test func anyRequestWithTheAgentHeaderRegistersIt() {
        let h = Harness()
        _ = h.send(HTTPRequest(method: "GET", path: "/ping",
                               headers: ["x-plonk-agent": "openai-test-agent/0.1"], body: [:]))
        #expect(h.router.agents.onlineNames() == ["openai-test-agent"])
    }

    @Test func selectStoresAndClearsTheChoice() {
        let h = Harness()
        #expect(h.post("/agents/select", ["name": "claude-code"]).status == 200)
        #expect(h.store.config.selectedAgent == "claude-code")
        #expect(h.post("/agents/select", [:]).status == 200)
        #expect(h.store.config.selectedAgent == nil)
    }

    @Test func exclusiveModeBlocksEveryOtherAgent() {
        let h = Harness()
        _ = h.post("/agents/select", ["name": "claude-code"])
        _ = h.post("/agents/exclusive", ["on": true])

        let fromOther = HTTPRequest(method: "POST", path: "/workspaces/save",
                                    headers: ["x-plonk-agent": "cursor/1.0"],
                                    body: ["name": "work", "items": [sampleItem]])
        #expect(h.send(fromOther).status == 409)
        #expect(h.store.config.workspaces["work"] == nil)

        let fromSelected = HTTPRequest(method: "POST", path: "/workspaces/save",
                                       headers: ["x-plonk-agent": "claude-code/2.0"],
                                       body: ["name": "work", "items": [sampleItem]])
        #expect(h.send(fromSelected).status == 200)
        #expect(h.store.config.workspaces["work"]?.items.count == 1)
    }

    @Test func exclusiveModeLeavesReadsAndHelloOpen() {
        let h = Harness()
        _ = h.post("/agents/select", ["name": "claude-code"])
        _ = h.post("/agents/exclusive", ["on": true])
        let headers = ["x-plonk-agent": "cursor/1.0"]
        #expect(h.send(HTTPRequest(method: "GET", path: "/ping", headers: headers, body: [:])).status == 200)
        #expect(h.send(HTTPRequest(method: "POST", path: "/agents/hello", headers: headers,
                                   body: ["name": "cursor"])).status == 200)
    }

    /// Handing the wheel to someone else is itself guarded, or any agent could
    /// undo the user's choice.
    @Test func exclusiveModeGuardsTheSelectionItself() {
        let h = Harness()
        _ = h.post("/agents/select", ["name": "claude-code"])
        _ = h.post("/agents/exclusive", ["on": true])
        let steal = HTTPRequest(method: "POST", path: "/agents/select",
                                headers: ["x-plonk-agent": "cursor/1.0"], body: ["name": "cursor"])
        #expect(h.send(steal).status == 409)
        #expect(h.store.config.selectedAgent == "claude-code")

        let handOff = HTTPRequest(method: "POST", path: "/agents/select",
                                  headers: ["x-plonk-agent": "claude-code/2.0"], body: ["name": "cursor"])
        #expect(h.send(handOff).status == 200)
        #expect(h.store.config.selectedAgent == "cursor")
    }

    @Test func exclusiveModeWithoutASelectionBlocksNothing() {
        let h = Harness()
        _ = h.post("/agents/exclusive", ["on": true])
        let request = HTTPRequest(method: "POST", path: "/workspaces/save",
                                  headers: ["x-plonk-agent": "cursor/1.0"],
                                  body: ["name": "work", "items": [sampleItem]])
        #expect(h.send(request).status == 200)
    }

    @Test func askQueuesForTheSelectedAgent() {
        let h = Harness()
        _ = h.post("/agents/select", ["name": "claude-code"])
        let response = h.post("/agents/ask", ["prompt": "browser left"])
        #expect(response.status == 200)
        #expect(response.json["queued"] as? Bool == true)
        let inbox = h.send(HTTPRequest(method: "GET", path: "/agents/inbox?agent=claude-code",
                                       headers: [:], body: [:]))
        let tasks = inbox.json["tasks"] as? [[String: Any]]
        #expect(tasks?.first?["prompt"] as? String == "browser left")
    }

    @Test func askWithoutATargetIsRejected() {
        let h = Harness()
        #expect(h.post("/agents/ask", ["prompt": "hi"]).status == 400)
        #expect(h.post("/agents/ask", [:]).status == 400)
    }

    @Test func askRunsAConfiguredAdapterInsteadOfQueueing() {
        let h = Harness()
        h.store.update { $0.agentAdapters = [AgentAdapter(name: "codex-cli", command: "codex exec {prompt}")] }
        var launched: (name: String, prompt: String)?
        h.router.runAdapter = { adapter, prompt in launched = (adapter.name, prompt) }
        let response = h.post("/agents/ask", ["prompt": "terminal right", "agent": "codex-cli"])
        #expect(response.status == 200)
        #expect(response.json["launched"] as? Bool == true)
        #expect(launched?.name == "codex-cli")
        #expect(launched?.prompt == "terminal right")
        #expect(h.router.agents.drain(for: "codex-cli").isEmpty)
    }

    @Test func inboxNeedsAnAgentParameter() {
        let h = Harness()
        #expect(h.send(HTTPRequest(method: "GET", path: "/agents/inbox", headers: [:], body: [:])).status == 400)
    }

    @Test func queryStringsSplitCleanly() {
        let split = Router.splitQuery("/agents/inbox?agent=claude%2Dcode&wait=25")
        #expect(split.path == "/agents/inbox")
        #expect(split.query["agent"] == "claude-code")
        #expect(split.query["wait"] == "25")
        #expect(Router.splitQuery("/state").path == "/state")
    }

    /// A bare "=" pair used to trap and take the whole app down with it.
    @Test func malformedQueriesDoNotCrash() {
        #expect(Router.splitQuery("/state?=").path == "/state")
        #expect(Router.splitQuery("/state?a=1&=&b=2").query["b"] == "2")
        #expect(Router.splitQuery("/state?").path == "/state")
        #expect(Router.splitQuery("/state?flag").query["flag"] == "")
        let h = Harness()
        #expect(h.send(HTTPRequest(method: "GET", path: "/state?=", headers: [:], body: [:])).status != 404)
    }

    /// A prompt is a way to move windows by proxy, and can launch an adapter.
    @Test func exclusiveModeGuardsTheAgentChannel() {
        let h = Harness()
        _ = h.post("/agents/select", ["name": "claude-code"])
        _ = h.post("/agents/exclusive", ["on": true])
        let ask = HTTPRequest(method: "POST", path: "/agents/ask",
                              headers: ["x-plonk-agent": "cursor/1.0"],
                              body: ["prompt": "move everything to screen 2"])
        #expect(h.send(ask).status == 409)
        // Draining someone else's queue steals their prompts, GET or not.
        let peek = HTTPRequest(method: "GET", path: "/agents/inbox?agent=claude-code",
                               headers: ["x-plonk-agent": "cursor/1.0"], body: [:])
        #expect(h.send(peek).status == 409)
        let own = HTTPRequest(method: "GET", path: "/agents/inbox?agent=claude-code",
                              headers: ["x-plonk-agent": "claude-code/2.0"], body: [:])
        #expect(h.send(own).status == 200)
    }

    @Test func mutationsBumpTheRevision() {
        let h = Harness()
        let before = h.router.changes.rev
        var events: [String] = []
        h.router.changes.onEvent = { _, what in events.append(what) }
        _ = h.post("/workspaces/save", ["name": "work", "items": [sampleItem]])
        #expect(h.router.changes.rev > before)
        #expect(events.contains("config"))
    }

    @Test func agentChangesNotifyTheUI() {
        let h = Harness()
        var notifications = 0
        h.router.didChangeAgents = { notifications += 1 }
        _ = h.post("/agents/select", ["name": "claude-code"])
        _ = h.post("/agents/exclusive", ["on": true])
        #expect(notifications == 2)
    }
}
