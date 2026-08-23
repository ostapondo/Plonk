import AppKit
import Network

// HTTP surface of the app. Kept apart from AppDelegate so routes can be
// exercised without a status bar or windows.
//
//   GET  /ping              liveness, cheap: touches neither AX nor the screen
//   GET  /state             disabled_features lists what the user switched off;
//                           a route under one of them answers 409
//   POST /awake             { on?, minutes?, until?, pid?, available? }
//                           available also resets the idle timer, which is what
//                           chat apps read; see AwakeManager
//   POST /layout            { items: [{ app, title?, screen?, frame: {x,y,w,h} }] }
//   POST /workspaces/save   { name, items?, move_existing? }  no items = snapshot the desktop
//   POST /workspaces/launch { name, screen? }   screen pulls it onto one monitor
//   POST /workspaces/delete { name }
//   POST /workspaces/rename { from, to }
//   POST /layouts/*         aliases of save/launch/delete, kept for older clients
//   POST /zones/save     { name, zones: [{x,y,w,h}], screen?, gap? }
//                        gap in points is the set's own; null or absent keeps the default
//   POST /zones/assign   { screen, name? }
//   POST /zones/delete   { name }
//   POST /shot/capture   { mode?, annotate?, path?, clipboard?, preview? }
//                        mode "app" also takes { app?, title_contains? } and
//                        photographs that window even when it is buried
//   POST /shot/annotate  { path, marks: [{kind, points, color?, width?}], output?, clipboard? }
//   POST /shot/text      { mode?, path?, clipboard?, languages? }  on-device OCR
//   POST /ruler/measure  { screen?, point? } | { from, to } | { interactive: true }
//   POST /layout/zone    { app, zone, title?, screen? }
//   POST /agents/hello     { name, version?, pid? }   registers/refreshes a session
//   POST /agents/select    { name? }   no name clears the selection
//   POST /agents/exclusive { on }      only the selected agent may change things
//   POST /agents/ask       { prompt, agent? }   queue a task for an agent (default: active)
//   GET  /agents/inbox?agent=<name>&wait=<0-25>  long-poll the agent's queued tasks
//   GET  /update/state     installed and available versions, and what the last check found
//   POST /update/check     asks GitHub for the latest release; the result lands in /update/state
//   POST /update/install   downloads it, checks its signature, swaps it in, relaunches
//   GET  /events           SSE stream of {"rev","what"}; rev also rides in /state
//
// Requests may carry X-Plonk-Agent: name/version (and X-Plonk-Agent-Pid) so
// the app knows who is driving; plonk-mcp sends them on every call.

final class Router {
    let store: ConfigStore
    let windows: WindowManager
    let awake: AwakeManager
    let agents: AgentRegistry
    let changes: ChangeBus
    /// The `/shot` routes, which answer after the request has been left behind.
    /// AppDelegate wires its capture closures onto this.
    let shots: ShotRoutes
    /// The `/ruler` route, which answers late for the same reason.
    let ruler: RulerRoutes

    /// Set by AppDelegate. Launching shows a panel and outlives the request, so
    /// it stays out of Router the same way capture does.
    var launchWorkspace: ((String, Workspace, Int?, @escaping ([[String: Any]]) -> Void) -> Void)?
    /// Set by AppDelegate; spawning a process is not Router's business.
    var runAdapter: ((AgentAdapter, String) -> Void)?
    /// Set by AppDelegate. Takes over a connection for the event stream and
    /// the revision its first frame reports.
    var attachEvents: ((NWConnection, Int) -> Void)?
    /// Set by AppDelegate. Checking reaches the network and installing quits
    /// the app, so neither belongs to a route handler.
    var updateState: (() -> [String: Any])?
    var checkForUpdates: (() -> Void)?
    var installUpdate: (() -> Void)?
    /// Show the zones an agent just changed. Only the part that is not a
    /// config change: applying one is hung on ConfigStore, not on a route.
    var didChangeZones: (() -> Void)?

    init(store: ConfigStore, windows: WindowManager, awake: AwakeManager,
         agents: AgentRegistry = AgentRegistry(), changes: ChangeBus = ChangeBus()) {
        self.store = store
        self.windows = windows
        self.awake = awake
        self.agents = agents
        self.changes = changes
        self.shots = ShotRoutes(store: store)
        self.ruler = RulerRoutes(windows: windows, store: store)
    }

    /// The route table. Every case is one line to the module that owns it, so
    /// this stays the list of what the app answers rather than how.
    func handle(_ request: HTTPRequest, respond: @escaping (HTTPResponse) -> Void) {
        let (path, query) = Self.splitQuery(request.path)
        let agent = Self.agentName(fromHeader: request.headers["x-plonk-agent"])
        // Not from a route that answers without a token: /ping is open so a
        // client can tell a closed app from a stale token, and that is all it
        // is for. Registering from it would let anything on the machine invent
        // agents that appear in the menu bar and in /state.
        if !APIToken.openPaths.contains(path) {
            agents.touch(header: request.headers["x-plonk-agent"],
                         pid: request.headers["x-plonk-agent-pid"].flatMap(Int.init))
        }
        if let reason = Self.exclusiveRejection(
            method: request.method, path: path, agent: agent,
            selected: store.config.selectedAgent, exclusive: store.config.agentExclusive
        ) {
            respond(.conflict(reason))
            return
        }
        // The user switched the module off, so its routes are refused whoever
        // asks. Reading state still says which ones, so an agent can tell.
        if let feature = Feature.owning(path: path), !store.config.isEnabled(feature) {
            respond(.conflict(feature.offReason))
            return
        }

        let body = request.body
        switch (request.method, path) {
        case ("GET", "/ping"):
            respond(.ok(["ok": true, "app": "Plonk"]))
        case ("GET", "/state"):
            respond(.ok(state()))

        case ("POST", "/awake"):
            handleAwake(body: body, respond: respond)

        case ("POST", "/layout"):
            respond(layoutRoute(body))
        case ("POST", "/layout/zone"):
            respond(placeInZoneRoute(body))

        // The /layouts names are what workspaces were called before they could
        // launch apps. Kept as aliases so an older client keeps working.
        case ("POST", "/workspaces/save"), ("POST", "/layouts/save"):
            respond(saveWorkspaceRoute(body))
        case ("POST", "/workspaces/launch"), ("POST", "/layouts/apply"):
            launchWorkspaceRoute(body, respond: respond)
        case ("POST", "/workspaces/delete"), ("POST", "/layouts/delete"):
            respond(deleteWorkspaceRoute(body))
        case ("POST", "/workspaces/rename"):
            respond(renameWorkspaceRoute(body))

        case ("POST", "/zones/save"):
            respond(saveZoneSetRoute(body))
        case ("POST", "/zones/assign"):
            respond(assignZoneSetRoute(body))
        case ("POST", "/zones/delete"):
            respond(deleteZoneSetRoute(body))

        case ("POST", "/agents/hello"):
            respond(agentHelloRoute(body))
        case ("POST", "/agents/select"):
            respond(selectAgentRoute(body))
        case ("POST", "/agents/exclusive"):
            respond(agentExclusiveRoute(body))
        case ("POST", "/agents/ask"):
            guard let prompt = Self.trimmedName(body["prompt"]) else {
                respond(.badRequest("body must include prompt"))
                return
            }
            respond(dispatch(prompt: prompt, to: Self.trimmedName(body["agent"])))
        case ("GET", "/agents/inbox"):
            agentInboxRoute(query: query, agent: agent, respond: respond)

        case ("POST", "/shot/capture"):
            shots.captureRoute(body, respond: respond)
        case ("POST", "/shot/annotate"):
            respond(shots.annotateRoute(body))
        case ("POST", "/shot/text"):
            shots.textRoute(body, respond: respond)

        case ("POST", "/ruler/measure"):
            ruler.measureRoute(body, respond: respond)

        case ("GET", "/update/state"):
            respond(.ok(updateState?() ?? ["error": "updates are not available"]))
        case ("POST", "/update/check"):
            respond(checkForUpdatesRoute())
        case ("POST", "/update/install"):
            respond(installUpdateRoute())

        case ("GET", "/events"):
            guard let attachEvents else {
                respond(.notFound("events are not available"))
                return
            }
            let rev = changes.rev
            respond(.stream { conn in attachEvents(conn, rev) })

        default:
            respond(.notFound("unknown route \(request.method) \(request.path)"))
        }
    }
}
