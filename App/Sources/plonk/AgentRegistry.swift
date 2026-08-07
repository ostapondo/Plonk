import Foundation

/// One MCP client session. Two sessions of the same client (say two editor
/// windows) are distinct entries, told apart by pid.
struct AgentSession {
    var name: String
    var version: String
    var pid: Int?
    var lastSeen: Date
}

/// Who is driving the HTTP API. Presence is inferred from traffic: a hello
/// registers the session, any request carrying the agent header refreshes it,
/// and silence past the timeout means the process is gone. Entries are kept
/// and reported offline rather than removed, so the selector can keep showing
/// a client the user picked while it restarts.
final class AgentRegistry {
    /// Heartbeats arrive every 30 seconds; three misses means gone.
    static let presenceTimeout: TimeInterval = 100

    private(set) var sessions: [String: AgentSession] = [:]
    /// Fired when an agent appears for the first time, on the caller's queue.
    var onChange: (() -> Void)?

    func register(name: String, version: String = "", pid: Int? = nil, now: Date = Date()) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let key = "\(trimmed)#\(pid.map(String.init) ?? "?")"
        let isNew = sessions[key] == nil
        var session = sessions[key] ?? AgentSession(name: trimmed, version: version, pid: pid, lastSeen: now)
        if !version.isEmpty { session.version = version }
        session.lastSeen = now
        sessions[key] = session
        if isNew { onChange?() }
    }

    /// Refresh from a request's `X-Plonk-Agent: name/version` header, so agents
    /// that never say hello (plain HTTP clients) still show up.
    func touch(header: String?, pid: Int?, now: Date = Date()) {
        guard let header, !header.isEmpty else { return }
        let parts = header.split(separator: "/", maxSplits: 1)
        register(name: String(parts.first ?? ""),
                 version: parts.count > 1 ? String(parts[1]) : "",
                 pid: pid, now: now)
    }

    func isOnline(_ session: AgentSession, now: Date = Date()) -> Bool {
        now.timeIntervalSince(session.lastSeen) < Self.presenceTimeout
    }

    /// Distinct client names currently online, for the selector.
    func onlineNames(now: Date = Date()) -> [String] {
        Set(sessions.values.filter { isOnline($0, now: now) }.map(\.name)).sorted()
    }

    /// Sessions as they appear under "agents" in /state.
    func describe(selected: String?, now: Date = Date()) -> [[String: Any]] {
        sessions.values
            .sorted { ($0.name, $0.pid ?? 0) < ($1.name, $1.pid ?? 0) }
            .map { session in
                var entry: [String: Any] = [
                    "name": session.name,
                    "version": session.version,
                    "online": isOnline(session, now: now),
                    "last_seen": ISO8601DateFormatter().string(from: session.lastSeen),
                    "selected": session.name == selected,
                ]
                if let pid = session.pid { entry["pid"] = pid }
                return entry
            }
    }
}
