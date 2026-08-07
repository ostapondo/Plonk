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
        conn.send(content: Data(head.utf8), completion: .contentProcessed { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                if error != nil {
                    conn.cancel()
                    return
                }
                self.connections.append(conn)
                self.startKeepaliveIfNeeded()
            }
        })
    }

    func broadcast(rev: Int, what: String) {
        send(Data(Self.frame(rev: rev, what: what).utf8))
    }

    private static func frame(rev: Int, what: String) -> String {
        "data: {\"rev\": \(rev), \"what\": \"\(what)\"}\n\n"
    }

    /// A comment frame flushes out connections whose client is gone; without
    /// it a dead listener would linger until the next real event.
    private func startKeepaliveIfNeeded() {
        guard keepalive == nil else { return }
        keepalive = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
            self?.send(Data(": ping\n\n".utf8))
        }
    }

    private func send(_ data: Data) {
        for conn in connections {
            conn.send(content: data, completion: .contentProcessed { [weak self] error in
                guard error != nil else { return }
                DispatchQueue.main.async {
                    conn.cancel()
                    self?.connections.removeAll { $0 === conn }
                }
            })
        }
    }
}
