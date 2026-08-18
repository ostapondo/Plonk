import Foundation

// Who may call what, and how a request is taken apart before anyone asks.
//
// Kept out of the route table so the rule can be read on its own: it decides
// what "only the selected agent controls" blocks, and getting it wrong either
// hands control away or locks the user out of their own app.

extension Router {
    /// "/agents/inbox?agent=x&wait=25" → ("/agents/inbox", ["agent": "x", "wait": "25"]).
    /// URLComponents owns the escaping and the malformed cases; hand-rolling
    /// this trapped on a bare "=" pair, which any caller could send.
    static func splitQuery(_ raw: String) -> (path: String, query: [String: String]) {
        guard raw.contains("?") else { return (raw, [:]) }
        guard let components = URLComponents(string: raw) else {
            return (String(raw.prefix(while: { $0 != "?" })), [:])
        }
        let query = (components.queryItems ?? []).reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value ?? ""
        }
        return (components.path, query)
    }

    /// The name half of an `X-Plonk-Agent: name/version` header.
    static func agentName(fromHeader header: String?) -> String? {
        guard let name = header?.split(separator: "/", maxSplits: 1).first
            .map({ $0.trimmingCharacters(in: .whitespaces) }), !name.isEmpty else { return nil }
        return name
    }

    /// Everything that changes windows or config. Reads and screenshots stay
    /// open to every agent; hello must stay open or nobody could register.
    // /update is guarded because installing one quits and relaunches the app.
    private static let guardedPrefixes = ["/layout", "/layouts", "/workspaces", "/zones", "/awake", "/active", "/update"]
    // /agents/ask is guarded too: a prompt is a way to move windows by proxy,
    // and it can launch an adapter's shell command outright.
    private static let guardedPaths: Set<String> = ["/agents/select", "/agents/exclusive", "/agents/ask"]

    /// The 409 reason when "only the selected agent controls" blocks this
    /// request, nil when it may proceed. The inbox is not here: who may read a
    /// queue depends on whose queue it is, which the route itself checks.
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

    static func trimmedName(_ value: Any?) -> String? {
        guard let name = (value as? String)?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return nil }
        return name
    }
}
