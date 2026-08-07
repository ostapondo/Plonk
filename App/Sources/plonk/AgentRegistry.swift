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
        let previous = sessions[key]
        var session = previous ?? AgentSession(name: trimmed, version: version, pid: pid, lastSeen: now)
        if !version.isEmpty { session.version = version }
        session.lastSeen = now
        sessions[key] = session
        // Heartbeats from a session already online change nothing anyone is
        // watching; arriving and coming back do.
        if previous.map({ !isOnline($0, now: now) }) ?? true { onChange?() }
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

    // MARK: - Inbox

    /// A prompt waiting for an agent to pick it up — the channel through which
    /// voice and other outgoing requests reach the active agent.
    struct Task {
        let id = UUID().uuidString
        let prompt: String
        let created = Date()

        var asDict: [String: Any] {
            ["id": id, "prompt": prompt,
             "created": AgentRegistry.iso.string(from: created)]
        }
    }

    /// Building one of these is far dearer than formatting with it, and
    /// everything here is main-queue confined.
    static let iso = ISO8601DateFormatter()

    /// Prompts an agent never came back for are worthless; keeping the newest
    /// few bounds a queue nobody may ever drain.
    static let maxQueuedTasks = 20

    private var inbox: [String: [Task]] = [:]
    /// The one parked long-poll responder per agent, waiting for a task or its
    /// timeout. Everything runs on the main queue (Router.handle does), so no
    /// locking. Only one is kept: a client that polls again has abandoned its
    /// previous connection, and handing a task to that dead socket would throw
    /// the user's words away.
    private var waiters: [String: (cancel: DispatchWorkItem, respond: ([Task]) -> Void)] = [:]

    @discardableResult
    func enqueue(_ prompt: String, for agent: String) -> Task {
        let task = Task(prompt: prompt)
        if let waiter = waiters.removeValue(forKey: agent) {
            waiter.cancel.cancel()
            waiter.respond([task])
        } else {
            var queued = inbox[agent] ?? []
            queued.append(task)
            inbox[agent] = queued.suffix(Self.maxQueuedTasks)
        }
        return task
    }

    func drain(for agent: String) -> [Task] {
        inbox.removeValue(forKey: agent) ?? []
    }

    /// Parks the responder until a task arrives, up to `seconds`, then answers
    /// with whatever there is (possibly nothing).
    func wait(for agent: String, seconds: Double, respond: @escaping ([Task]) -> Void) {
        let queued = drain(for: agent)
        guard queued.isEmpty else {
            respond(queued)
            return
        }
        // A caller that asked not to wait wants an answer, not a parked socket.
        guard seconds > 0 else {
            respond([])
            return
        }
        // A second poll means the first connection is gone; let it go empty
        // rather than leave it first in line for the next task.
        if let previous = waiters.removeValue(forKey: agent) {
            previous.cancel.cancel()
            previous.respond([])
        }
        let cancel = DispatchWorkItem { [weak self] in
            guard let self, let waiter = waiters.removeValue(forKey: agent) else { return }
            waiter.respond([])
        }
        waiters[agent] = (cancel: cancel, respond: respond)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: cancel)
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
