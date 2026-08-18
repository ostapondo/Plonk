import Foundation
import Network

/// Counts changes and tells whoever listens. `rev` also rides along in /state,
/// so an agent can cheaply notice it missed something.
final class ChangeBus {
    private(set) var rev = 1
    var onEvent: ((Int, String) -> Void)?

    /// `what` is a coarse category: config, windows, awake, agents.
    func bump(_ what: String) {
        rev += 1
        onEvent?(rev, what)
    }
}

/// Server-sent events on GET /events: every change bumps the revision and all
/// connected listeners get {"rev":N,"what":"…"}. Main-queue confined, like the
/// rest of the request handling.
final class EventBroadcaster {
    private var connections: [NWConnection] = []
    private var keepalive: Timer?

    func attach(_ conn: NWConnection, rev: Int) {
        let head = "HTTP/1.1 200 OK\r\n"
            + "Content-Type: text/event-stream\r\n"
            + "Cache-Control: no-cache\r\n"
            + "Connection: keep-alive\r\n\r\n"
            + "retry: 3000\n\n"
            + Self.frame(rev: rev, what: "hello")
        // Registered before the send completes: an event bumped in that window
        // would otherwise never reach this listener, and it would sit on a
        // revision it believes is current.
        connections.append(conn)
        startKeepaliveIfNeeded()
        send(Data(head.utf8), to: conn)
    }

    func broadcast(rev: Int, what: String) {
        send(Data(Self.frame(rev: rev, what: what).utf8))
    }

    private static func frame(rev: Int, what: String) -> String {
        let payload = (try? JSONSerialization.data(withJSONObject: ["rev": rev, "what": what],
                                                   options: [.sortedKeys]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return "data: \(payload)\n\n"
    }

    /// A comment frame flushes out connections whose client is gone; without
    /// it a dead listener would linger until the next real event.
    private func startKeepaliveIfNeeded() {
        guard keepalive == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
            self?.send(Data(": ping\n\n".utf8))
        }
        // A menu bar app should be idle when nothing is listening, so the
        // pings coalesce and the timer dies with the last connection.
        timer.tolerance = 5
        keepalive = timer
    }

    private func forget(_ conn: NWConnection) {
        connections.removeAll { $0 === conn }
        guard connections.isEmpty else { return }
        keepalive?.invalidate()
        keepalive = nil
    }

    private func send(_ data: Data) {
        for conn in connections { send(data, to: conn) }
    }

    /// A send that fails is the client gone; drop the connection.
    private func send(_ data: Data, to conn: NWConnection) {
        conn.send(content: data, completion: .contentProcessed { [weak self] error in
            guard error != nil else { return }
            DispatchQueue.main.async {
                conn.cancel()
                self?.forget(conn)
            }
        })
    }
}
