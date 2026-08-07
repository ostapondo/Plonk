import AppKit

// HTTP surface of the app. Kept apart from AppDelegate so routes can be
// exercised without a status bar or windows.
//
//   GET  /ping              liveness, cheap: touches neither AX nor the screen
//   GET  /state
//   POST /awake             { on?, minutes? }
//   POST /layout            { items: [{ app, title?, screen?, frame: {x,y,w,h} }] }
//   POST /workspaces/save   { name, items?, move_existing? }  no items = snapshot the desktop
//   POST /workspaces/launch { name, screen? }   screen pulls it onto one monitor
//   POST /workspaces/delete { name }
//   POST /workspaces/rename { from, to }
//   POST /layouts/*         aliases of save/launch/delete, kept for older clients
//   POST /zones/save     { name, zones: [{x,y,w,h}], screen? }
//   POST /zones/assign   { screen, name? }
//   POST /zones/delete   { name }
//   POST /shot/capture   { mode?, annotate?, path?, clipboard?, preview? }
//   POST /shot/annotate  { path, marks: [{kind, points, color?, width?}], output?, clipboard? }
//   POST /layout/zone    { app, zone, title?, screen? }
//   POST /agents/hello     { name, version?, pid? }   registers/refreshes a session
//   POST /agents/select    { name? }   no name clears the selection
//   POST /agents/exclusive { on }      only the selected agent may change things
//   POST /agents/ask       { prompt, agent? }   queue a task for an agent (default: active)
//   GET  /agents/inbox?agent=<name>&wait=<0-25>  long-poll the agent's queued tasks
//
// Requests may carry X-Plonk-Agent: name/version (and X-Plonk-Agent-Pid) so
// the app knows who is driving; plonk-mcp sends them on every call.

final class Router {
    /// Longest side of the copy handed to agents, matching what the Claude API
    /// accepts without resampling.
    static let previewMaxDimension: CGFloat = 1568

    private let store: ConfigStore
    private let windows: WindowManager
    private let awake: AwakeManager
    let agents: AgentRegistry

    /// Set by AppDelegate; the editor and permission prompts need AppKit.
    var capture: ((CaptureMode, Bool, @escaping (NSImage?) -> Void) -> Void)?
    /// Set by AppDelegate. Launching shows a panel and outlives the request, so
    /// it stays out of Router the same way capture does.
    var launchWorkspace: ((String, Workspace, Int?, @escaping ([[String: Any]]) -> Void) -> Void)?
    /// Set by AppDelegate; spawning a process is not Router's business.
    var runAdapter: ((AgentAdapter, String) -> Void)?
    var didChangeLayouts: (() -> Void)?
    var didChangeZones: (() -> Void)?
    var didChangeAgents: (() -> Void)?
    var didSaveShot: ((String) -> Void)?
    var announce: ((_ text: String, _ imagePath: String?) -> Void)?

    init(store: ConfigStore, windows: WindowManager, awake: AwakeManager,
         agents: AgentRegistry = AgentRegistry()) {
        self.store = store
        self.windows = windows
        self.awake = awake
        self.agents = agents
    }

    func handle(_ request: HTTPRequest, respond: @escaping (HTTPResponse) -> Void) {
        let (path, query) = Self.splitQuery(request.path)
        let agent = Self.agentName(fromHeader: request.headers["x-plonk-agent"])
        agents.touch(header: request.headers["x-plonk-agent"],
                     pid: request.headers["x-plonk-agent-pid"].flatMap(Int.init))
        if let reason = Self.exclusiveRejection(
            method: request.method, path: path, agent: agent,
            selected: store.config.selectedAgent, exclusive: store.config.agentExclusive
        ) {
            respond(HTTPResponse(status: 409, json: ["error": reason]))
            return
        }

        let body = request.body
        switch (request.method, path) {
        case ("GET", "/ping"):
            respond(.ok(["ok": true, "app": "Plonk"]))

        case ("GET", "/state"):
            respond(.ok(state()))

        case ("POST", "/awake"):
            let on = (body["on"] as? Bool) ?? !awake.requested
            awake.set(on, minutes: (body["minutes"] as? NSNumber)?.intValue)
            respond(.ok(["ok": true, "awake": awake.isOn, "status": awake.statusText]))

        case ("POST", "/layout"):
            guard let items = body["items"] as? [[String: Any]], !items.isEmpty else {
                respond(.badRequest("body must be {\"items\": [{app, title?, screen?, frame:{x,y,w,h}}]}"))
                return
            }
            let results = items.map { item -> [String: Any] in
                guard let spec = LayoutItemSpec(dict: item) else {
                    return ["ok": false,
                            "error": "item needs app and frame {x,y,w,h} within 0..1, with w and h above 0"]
                }
                return place(spec)
            }
            respond(.ok(["results": results, "accessibility_granted": windows.isTrusted]))

        case ("POST", "/workspaces/save"), ("POST", "/layouts/save"):
            respond(saveRoute(body))

        case ("POST", "/workspaces/launch"), ("POST", "/layouts/apply"):
            launchRoute(body, respond: respond)

        case ("POST", "/workspaces/delete"), ("POST", "/layouts/delete"):
            guard let name = trimmedName(body["name"]) else {
                respond(.badRequest("body must include name"))
                return
            }
            guard store.config.workspaces[name] != nil else {
                respond(.notFound("no workspace named \"\(name)\""))
                return
            }
            store.update { $0.workspaces.removeValue(forKey: name) }
            didChangeLayouts?()
            respond(.ok(["ok": true, "deleted": name]))

        case ("POST", "/workspaces/rename"):
            guard let from = trimmedName(body["from"]), let to = trimmedName(body["to"]) else {
                respond(.badRequest("body must include from and to"))
                return
            }
            guard store.config.workspaces[from] != nil else {
                respond(.notFound("no workspace named \"\(from)\""))
                return
            }
            guard from == to || store.config.workspaces[to] == nil else {
                respond(HTTPResponse(status: 409, json: ["error": "a workspace named \"\(to)\" already exists"]))
                return
            }
            if from != to {
                store.update {
                    guard let workspace = $0.workspaces.removeValue(forKey: from) else { return }
                    $0.workspaces[to] = workspace
                }
                didChangeLayouts?()
            }
            respond(.ok(["ok": true, "renamed": from, "to": to]))

        case ("POST", "/zones/save"):
            guard let name = trimmedName(body["name"]), let raw = body["zones"] as? [[String: Any]] else {
                respond(.badRequest("body must be {\"name\", \"zones\": [{x,y,w,h}], \"screen\"?}"))
                return
            }
            let zones = raw.compactMap { ZoneRect(dict: $0) }
            guard !zones.isEmpty, zones.count == raw.count else {
                respond(.badRequest("every zone needs x,y,w,h within 0..1, with w and h above 0"))
                return
            }
            store.update {
                $0.zoneSets[name] = zones
                if let screen = (body["screen"] as? NSNumber)?.intValue {
                    $0.assignZoneSet(name, forKeys: ScreenIdentity.keys(forIndex: screen))
                }
            }
            didChangeZones?()
            respond(.ok(["ok": true, "saved": name, "zones": zones.count]))

        case ("POST", "/zones/assign"):
            guard let screen = (body["screen"] as? NSNumber)?.intValue else {
                respond(.badRequest("body must include screen; omit name for the default set (\(BuiltinZoneSets.defaultName)), pass \"edge\" for edge snapping"))
                return
            }
            let keys = ScreenIdentity.keys(forIndex: screen)
            let requested = (body["name"] as? String)?.trimmingCharacters(in: .whitespaces)
            let assignment: String?
            switch requested {
            case nil:
                assignment = nil
            case let name? where name.isEmpty || name.lowercased() == "edge":
                assignment = ""
            case let name?:
                guard store.config.zoneSets[name] != nil || BuiltinZoneSets.all[name] != nil else {
                    respond(.notFound("no zone set named \"\(name)\""))
                    return
                }
                assignment = name
            }
            store.update { $0.assignZoneSet(assignment, forKeys: keys) }
            didChangeZones?()
            respond(.ok(["ok": true]))

        case ("POST", "/zones/delete"):
            guard let name = trimmedName(body["name"]) else {
                respond(.badRequest("body must include name"))
                return
            }
            guard store.config.zoneSets[name] != nil else {
                respond(.notFound("no zone set named \"\(name)\""))
                return
            }
            store.update { $0.forgetZoneSet(named: name) }
            didChangeZones?()
            respond(.ok(["ok": true, "deleted": name]))

        case ("POST", "/layout/zone"):
            respond(zoneRoute(body))

        case ("POST", "/agents/hello"):
            guard let name = trimmedName(body["name"]) else {
                respond(.badRequest("body must include name"))
                return
            }
            agents.register(name: name,
                            version: (body["version"] as? String) ?? "",
                            pid: (body["pid"] as? NSNumber)?.intValue)
            var result: [String: Any] = ["ok": true, "exclusive": store.config.agentExclusive]
            if let selected = store.config.selectedAgent { result["selected_agent"] = selected }
            respond(.ok(result))

        case ("POST", "/agents/select"):
            let name = trimmedName(body["name"])
            store.update { $0.selectedAgent = name }
            didChangeAgents?()
            respond(.ok(name.map { ["ok": true, "selected_agent": $0] } ?? ["ok": true]))

        case ("POST", "/agents/exclusive"):
            guard let on = body["on"] as? Bool else {
                respond(.badRequest("body must be {\"on\": true|false}"))
                return
            }
            store.update { $0.agentExclusive = on }
            didChangeAgents?()
            respond(.ok(["ok": true, "exclusive": on]))

        case ("POST", "/agents/ask"):
            guard let prompt = trimmedName(body["prompt"]) else {
                respond(.badRequest("body must include prompt"))
                return
            }
            respond(dispatch(prompt: prompt, to: trimmedName(body["agent"])))

        case ("GET", "/agents/inbox"):
            guard let name = query["agent"], !name.isEmpty else {
                respond(.badRequest("query must include agent, e.g. /agents/inbox?agent=claude-code&wait=25"))
                return
            }
            let wait = min(max(Double(query["wait"] ?? "0") ?? 0, 0), 25)
            agents.wait(for: name, seconds: wait) { tasks in
                respond(.ok(["tasks": tasks.map(\.asDict)]))
            }

        case ("POST", "/shot/capture"):
            captureRoute(body, respond: respond)

        case ("POST", "/shot/annotate"):
            respond(annotateRoute(body))

        default:
            respond(.notFound("unknown route \(request.method) \(request.path)"))
        }
    }

    // MARK: - Agents

    /// Sends a prompt to an agent: a configured adapter is launched directly,
    /// anything else is queued for its live session to pick up over
    /// /agents/inbox. Voice and hotkeys land here too, via AppDelegate.
    func dispatch(prompt: String, to requested: String? = nil) -> HTTPResponse {
        guard let target = requested ?? store.config.selectedAgent else {
            return .badRequest("no agent named and none selected — pass \"agent\" or pick an active agent in Plonk")
        }
        if let adapter = store.config.agentAdapters.first(where: { $0.name == target }) {
            guard let runAdapter else { return .failed("adapters are not available") }
            runAdapter(adapter, prompt)
            return .ok(["ok": true, "agent": target, "launched": true])
        }
        let known = agents.sessions.values.contains { $0.name == target }
        let task = agents.enqueue(prompt, for: target)
        var result: [String: Any] = ["ok": true, "agent": target, "queued": true, "id": task.id]
        if !known {
            result["note"] = "no session named \"\(target)\" has connected yet; the task waits in its inbox"
        }
        return .ok(result)
    }

    /// "/agents/inbox?agent=x&wait=25" → ("/agents/inbox", ["agent": "x", "wait": "25"]).
    static func splitQuery(_ raw: String) -> (path: String, query: [String: String]) {
        guard let mark = raw.firstIndex(of: "?") else { return (raw, [:]) }
        let path = String(raw[raw.startIndex..<mark])
        var query: [String: String] = [:]
        for pair in raw[raw.index(after: mark)...].split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            guard let key = String(kv[0]).removingPercentEncoding else { continue }
            query[key] = kv.count > 1 ? (String(kv[1]).removingPercentEncoding ?? "") : ""
        }
        return (path, query)
    }

    /// The name half of an `X-Plonk-Agent: name/version` header.
    static func agentName(fromHeader header: String?) -> String? {
        guard let name = header?.split(separator: "/", maxSplits: 1).first
            .map({ $0.trimmingCharacters(in: .whitespaces) }), !name.isEmpty else { return nil }
        return name
    }

    /// Everything that changes windows or config. Reads and screenshots stay
    /// open to every agent; hello must stay open or nobody could register.
    private static let guardedPrefixes = ["/layout", "/layouts", "/workspaces", "/zones", "/awake"]
    private static let guardedPaths: Set<String> = ["/agents/select", "/agents/exclusive"]

    /// The 409 reason when "only the selected agent controls" blocks this
    /// request, nil when it may proceed.
    static func exclusiveRejection(method: String, path: String, agent: String?,
                                   selected: String?, exclusive: Bool) -> String? {
        guard exclusive, let selected, !selected.isEmpty, method == "POST" else { return nil }
        let guarded = Self.guardedPaths.contains(path)
            || Self.guardedPrefixes.contains { path == $0 || path.hasPrefix($0 + "/") }
        guard guarded, agent != selected else { return nil }
        let who = agent.map { "\"\($0)\"" } ?? "an unidentified client"
        return "the user made \"\(selected)\" the only agent allowed to change windows and settings, "
            + "and this request came from \(who). Reading state and taking screenshots still work; "
            + "the user can switch agents in Plonk's menu."
    }

    // MARK: - State

    private func state() -> [String: Any] {
        var zoneSets: [String: [[String: Double]]] = [:]
        for (name, zones) in BuiltinZoneSets.all { zoneSets[name] = zones.map(\.asDict) }
        for (name, zones) in store.config.zoneSets { zoneSets[name] = zones.map(\.asDict) }

        let screens = windows.screens()
        // Assignments are stored per display UUID; agents work in screen indices.
        var assignments: [String: String] = [:]
        for screen in screens {
            if let name = store.config.zoneAssignment(forKeys: ScreenIdentity.keys(forIndex: screen.index)) {
                assignments[String(screen.index)] = name
            }
        }

        var state: [String: Any] = [
            "awake": awake.isOn,
            "awake_details": [
                "requested": awake.requested,
                "status": awake.statusText,
                "power": awake.isOnAC ? "ac" : "battery",
                "allow_on_battery": awake.allowOnBattery,
                "auto_while_charging": awake.autoWhileCharging,
                "keep_display_on": awake.keepDisplayOn,
                "session_ends": awake.sessionEnd.map { ISO8601DateFormatter().string(from: $0) } ?? "",
            ],
            "accessibility_granted": windows.isTrusted,
            "saved_layouts": store.config.workspaces.keys.sorted(),
            "workspaces": store.config.workspaces.mapValues { workspace in
                [
                    "move_existing": workspace.moveExisting,
                    "apps": workspace.apps,
                    "items": workspace.items.map(\.asDict),
                ] as [String: Any]
            },
            "zone_sets": zoneSets,
            "screen_zone_sets": assignments,
            "screens": screens.map { s in
                [
                    "index": s.index,
                    "frame": ["x": s.frame.minX, "y": s.frame.minY, "w": s.frame.width, "h": s.frame.height],
                    "visible": ["x": s.visible.minX, "y": s.visible.minY, "w": s.visible.width, "h": s.visible.height],
                ]
            },
            "windows": windows.listWindows(),
            "agents": agents.describe(selected: store.config.selectedAgent),
            "agent_adapters": store.config.agentAdapters.map(\.name),
            "agent_exclusive": store.config.agentExclusive,
        ]
        if let selected = store.config.selectedAgent { state["selected_agent"] = selected }
        return state
    }

    // MARK: - Workspaces

    private func saveRoute(_ body: [String: Any]) -> HTTPResponse {
        guard let name = trimmedName(body["name"]) else {
            return .badRequest("body must include name")
        }
        let items: [WorkspaceItem]
        if let raw = body["items"] as? [[String: Any]], !raw.isEmpty {
            items = raw.compactMap { WorkspaceItem(dict: $0) }
            guard items.count == raw.count else {
                return .badRequest("every item needs app and frame {x,y,w,h} within 0..1, with w and h above 0")
            }
        } else {
            items = snapshotWorkspace()
            guard !items.isEmpty else {
                return .badRequest("nothing on screen to snapshot")
            }
        }
        // Editing an existing workspace keeps its launch behavior unless the
        // request says otherwise.
        let moveExisting = (body["move_existing"] as? Bool)
            ?? store.config.workspaces[name]?.moveExisting ?? true
        store.update { $0.workspaces[name] = Workspace(items: items, moveExisting: moveExisting) }
        didChangeLayouts?()
        return .ok(["ok": true, "saved": name, "items": items.count, "apps": Workspace(items: items).apps])
    }

    private func launchRoute(_ body: [String: Any], respond: @escaping (HTTPResponse) -> Void) {
        guard let name = trimmedName(body["name"]) else {
            respond(.badRequest("body must include name"))
            return
        }
        guard let workspace = store.config.workspaces[name] else {
            respond(.notFound("no workspace named \"\(name)\""))
            return
        }
        guard let launchWorkspace else {
            respond(.failed("launching is not available"))
            return
        }
        let screen = (body["screen"] as? NSNumber)?.intValue
        launchWorkspace(name, workspace, screen) { results in
            respond(.ok([
                "ok": results.allSatisfy { $0["ok"] as? Bool == true },
                "workspace": name,
                "results": results,
            ]))
        }
    }

    /// Everything on screen, as a workspace.
    func snapshotWorkspace() -> [WorkspaceItem] {
        windows.listWindows().compactMap { entry in
            let screen = entry["screen"] as? Int
            return WorkspaceItem(window: entry,
                                 screenUUID: screen.flatMap { ScreenIdentity.uuid(forIndex: $0) })
        }
    }

    private func place(_ spec: LayoutItemSpec) -> [String: Any] {
        let error = windows.place(
            app: spec.app,
            titleContains: spec.title,
            screen: spec.screen,
            frac: FracRect(spec.x, spec.y, spec.w, spec.h)
        )
        return error.map { ["ok": false, "app": spec.app, "error": $0] } ?? ["ok": true, "app": spec.app]
    }

    // MARK: - Zone placement

    /// Zones are addressed by the number the drag overlay draws on them, so
    /// "the middle zone" is whatever the user sees as 2 in a three-zone set.
    private func zoneRoute(_ body: [String: Any]) -> HTTPResponse {
        guard let app = trimmedName(body["app"]),
              let number = (body["zone"] as? NSNumber)?.intValue else {
            return .badRequest("body must be {\"app\", \"zone\": 1-based index, \"title\"?, \"screen\"?}")
        }
        let title = body["title"] as? String
        guard let screen = (body["screen"] as? NSNumber)?.intValue
                ?? windows.screenIndex(ofApp: app, titleContains: title) else {
            return .notFound("app \"\(app)\" is not running")
        }
        let zones = store.config.zones(forKeys: ScreenIdentity.keys(forIndex: screen))
        guard !zones.isEmpty else {
            return .badRequest("screen \(screen) uses edge snapping, so it has no numbered zones")
        }
        guard zones.indices.contains(number - 1) else {
            return .badRequest("screen \(screen) has zones 1...\(zones.count)")
        }
        let error = windows.place(app: app, titleContains: title, screen: screen,
                                  frac: zones[number - 1].frac)
        if let error { return .failed(error) }
        return .ok(["ok": true, "app": app, "screen": screen, "zone": number, "zones": zones.count])
    }

    // MARK: - Screenshot

    private func captureRoute(_ body: [String: Any], respond: @escaping (HTTPResponse) -> Void) {
        guard let capture else {
            respond(.failed("capture is not available"))
            return
        }
        let mode = CaptureMode(rawValue: (body["mode"] as? String) ?? "screen") ?? .screen
        let annotate = (body["annotate"] as? Bool) ?? false

        capture(mode, annotate) { [weak self] image in
            guard let self else { return }
            guard let image else {
                respond(HTTPResponse(status: 409, json: [
                    "error": "capture was cancelled, or Screen Recording permission is missing",
                ]))
                return
            }
            if annotate {
                respond(.ok(["ok": true, "editor_open": true]))
                return
            }

            let destination: ScreenshotManager.Destination = (body["path"] as? String)
                .map { .path($0) } ?? .folder(self.store.config.shotFolder)
            guard let path = ScreenshotManager.save(image, to: destination) else {
                respond(.failed("could not write \(destination.url.path)"))
                return
            }

            var result: [String: Any] = ["ok": true, "path": path]
            if (body["clipboard"] as? Bool) ?? self.store.config.shotCopyToClipboard {
                ScreenshotManager.copyToClipboard(image)
                result["clipboard"] = true
            }
            if (body["preview"] as? Bool) == true,
               let preview = ScreenshotManager.writePreview(image, maxDimension: Self.previewMaxDimension) {
                result["preview_path"] = preview
            }
            self.didSaveShot?(path)
            respond(.ok(result))
        }
    }

    /// Burns agent-supplied marks into an existing capture.
    private func annotateRoute(_ body: [String: Any]) -> HTTPResponse {
        guard let path = trimmedName(body["path"]), let raw = body["marks"] as? [[String: Any]], !raw.isEmpty else {
            return .badRequest("body must be {\"path\", \"marks\": [{kind, points:[{x,y}], color?, width?}]}")
        }
        let marks = raw.compactMap { Annotation(dict: $0) }
        guard marks.count == raw.count else {
            let kinds = Annotation.Kind.allCases.map(\.rawValue).joined(separator: ", ")
            return .badRequest("every mark needs a kind (\(kinds)) and at least two points in 0..1")
        }
        let expanded = (path as NSString).expandingTildeInPath
        guard let image = NSImage(contentsOfFile: expanded) else {
            return .notFound("no readable image at \(expanded)")
        }
        let destination: ScreenshotManager.Destination = (body["output"] as? String)
            .map { .path($0) } ?? .path(Self.markedPath(for: expanded))
        let copy = (body["clipboard"] as? Bool) ?? true

        // Rendering is main-actor work; keeping the image inside the hop means
        // only plain strings cross back out.
        let written: (path: String, preview: String?)? = MainActor.assumeIsolated {
            guard let marked = image.annotated(with: marks),
                  let saved = ScreenshotManager.save(marked, to: destination) else { return nil }
            if copy { ScreenshotManager.copyToClipboard(marked) }
            return (saved, ScreenshotManager.writePreview(marked, maxDimension: Self.previewMaxDimension))
        }
        guard let written else { return .failed("could not render or write \(destination.url.path)") }

        var result: [String: Any] = ["ok": true, "path": written.path, "marks": marks.count]
        if copy { result["clipboard"] = true }
        if let preview = written.preview { result["preview_path"] = preview }
        announce?(copy ? "Copied to clipboard" : "Saved", written.preview ?? written.path)
        return .ok(result)
    }

    private static func markedPath(for path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let stem = url.deletingPathExtension().lastPathComponent
        return url.deletingLastPathComponent().appendingPathComponent("\(stem) marked.png").path
    }

    private func trimmedName(_ value: Any?) -> String? {
        guard let name = (value as? String)?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return nil }
        return name
    }
}
