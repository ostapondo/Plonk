import Foundation

// The /agents routes: who is connected, who is in charge, and the task queue
// between them.

extension Router {
    func agentHelloRoute(_ body: [String: Any]) -> HTTPResponse {
        guard let name = Self.trimmedName(body["name"]) else {
            return .badRequest("body must include name")
        }
        agents.register(name: name,
                        version: (body["version"] as? String) ?? "",
                        pid: (body["pid"] as? NSNumber)?.intValue)
        var result: [String: Any] = ["ok": true, "exclusive": store.config.agentExclusive]
        if let selected = store.config.selectedAgent { result["selected_agent"] = selected }
        return .ok(result)
    }

    func selectAgentRoute(_ body: [String: Any]) -> HTTPResponse {
        let name = Self.trimmedName(body["name"])
        store.update { $0.selectedAgent = name }
        return .ok(name.map { ["ok": true, "selected_agent": $0] } ?? ["ok": true])
    }

    func agentExclusiveRoute(_ body: [String: Any]) -> HTTPResponse {
        guard let on = body["on"] as? Bool else {
            return .badRequest("body must be {\"on\": true|false}")
        }
        store.update { $0.agentExclusive = on }
        return .ok(["ok": true, "exclusive": on])
    }

    func agentInboxRoute(query: [String: String], agent: String?,
                         respond: @escaping (HTTPResponse) -> Void) {
        guard let name = query["agent"], !name.isEmpty else {
            respond(.badRequest("query must include agent, e.g. /agents/inbox?agent=claude-code&wait=25"))
            return
        }
        // Draining a queue takes its prompts away, so a client that says who it
        // is may only read its own. Whether it is the active agent has nothing
        // to do with it.
        if let agent, agent != name {
            respond(.conflict("\"\(agent)\" cannot read the queue of \"\(name)\"; poll your own name"))
            return
        }
        let wait = (Double(query["wait"] ?? "0") ?? 0).clamped(to: 0...25)
        agents.wait(for: name, seconds: wait) { tasks in
            respond(.ok(["tasks": tasks.map(\.asDict)]))
        }
    }

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
}
