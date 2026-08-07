import Foundation
import Network

// Minimal HTTP server on loopback. Routes live in Router.

struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]  // lowercased names
    let body: [String: Any]
}

struct HTTPResponse {
    let status: Int
    let json: [String: Any]

    static func ok(_ json: [String: Any]) -> HTTPResponse { HTTPResponse(status: 200, json: json) }
    static func badRequest(_ message: String) -> HTTPResponse { HTTPResponse(status: 400, json: ["error": message]) }
    static func notFound(_ message: String) -> HTTPResponse { HTTPResponse(status: 404, json: ["error": message]) }
    static func failed(_ message: String) -> HTTPResponse { HTTPResponse(status: 500, json: ["error": message]) }
}

final class ControlServer {
    static let port: UInt16 = 43917

    private var listener: NWListener?
    private let handle: (HTTPRequest, @escaping (HTTPResponse) -> Void) -> Void
    /// When set, GET /events connections are handed over as SSE streams
    /// instead of the usual request/response cycle.
    var events: EventBroadcaster?
    /// The revision the first SSE frame reports.
    var currentRev: () -> Int = { 1 }

    /// Called on the main queue when the port cannot be claimed, which in
    /// practice means a second Plonk is already running.
    var onUnavailable: ((String) -> Void)?

    init(handle: @escaping (HTTPRequest, @escaping (HTTPResponse) -> Void) -> Void) {
        self.handle = handle
    }

    func start() throws {
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = NWEndpoint.hostPort(
            host: .ipv4(.loopback),
            port: NWEndpoint.Port(rawValue: Self.port)!
        )
        let listener = try NWListener(using: params)
        listener.stateUpdateHandler = { [weak self] state in
            guard case .failed(let error) = state else { return }
            NSLog("Plonk: control server on port \(Self.port) is unavailable: \(error)")
            DispatchQueue.main.async {
                self?.onUnavailable?("Port \(Self.port) is taken, so the MCP tools cannot reach this app. Another copy of Plonk is probably already running.")
            }
        }
        listener.newConnectionHandler = { [weak self] conn in
            conn.start(queue: .global(qos: .userInitiated))
            self?.receive(on: conn, buffer: Data())
        }
        listener.start(queue: .global(qos: .userInitiated))
        self.listener = listener
    }

    // A request that never terminates would otherwise grow the buffer forever.
    private static let maxRequestBytes = 4 << 20

    private func receive(on conn: NWConnection, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self] data, _, isComplete, error in
            guard let self else { conn.cancel(); return }
            var buf = buffer
            if let data { buf.append(data) }
            if error != nil || buf.count > Self.maxRequestBytes { conn.cancel(); return }

            guard let request = Self.parseIfComplete(buf) else {
                if isComplete { conn.cancel() } else { self.receive(on: conn, buffer: buf) }
                return
            }
            if let reason = Self.browserRejection(for: request) {
                self.respond(conn, HTTPResponse(status: 403, json: ["error": reason]))
                return
            }
            if request.method == "GET", request.path == "/events" || request.path.hasPrefix("/events?") {
                DispatchQueue.main.async {
                    guard let events = self.events else {
                        self.respond(conn, .notFound("events are not available"))
                        return
                    }
                    events.attach(conn, rev: self.currentRev())
                }
                return
            }
            DispatchQueue.main.async {
                self.handle(request) { [weak self] response in
                    self?.respond(conn, response)
                }
            }
        }
    }

    /// The API has no authentication beyond being loopback-only, so a web page
    /// the user happens to have open must not be able to drive it. Browsers
    /// always attach Origin to cross-site POSTs and Sec-Fetch-Site to every
    /// request, and neither header can be suppressed from page script.
    static func browserRejection(for request: HTTPRequest) -> String? {
        guard request.headers["origin"] != nil || request.headers["sec-fetch-site"] != nil else { return nil }
        return "requests from web pages are not accepted"
    }

    /// Returns nil while the request is still incomplete.
    static func parseIfComplete(_ data: Data) -> HTTPRequest? {
        guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)),
              let head = String(data: data[data.startIndex..<headerEnd.lowerBound], encoding: .utf8) else { return nil }
        let lines = head.components(separatedBy: "\r\n")
        let parts = (lines.first ?? "").components(separatedBy: " ")
        guard parts.count >= 2 else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let kv = line.split(separator: ":", maxSplits: 1)
            guard kv.count == 2 else { continue }
            headers[kv[0].lowercased()] = kv[1].trimmingCharacters(in: .whitespaces)
        }

        let contentLength = headers["content-length"].flatMap(Int.init) ?? 0
        let bodyData = data[headerEnd.upperBound...]
        guard bodyData.count >= contentLength else { return nil }
        var body: [String: Any] = [:]
        if contentLength > 0,
           let parsed = try? JSONSerialization.jsonObject(with: bodyData.prefix(contentLength)) as? [String: Any] {
            body = parsed
        }
        return HTTPRequest(method: parts[0], path: parts[1], headers: headers, body: body)
    }

    private func respond(_ conn: NWConnection, _ response: HTTPResponse) {
        let body = (try? JSONSerialization.data(withJSONObject: response.json, options: [.sortedKeys])) ?? Data("{}".utf8)
        let head = "HTTP/1.1 \(response.status) \(Self.reason(response.status))\r\n"
            + "Content-Type: application/json\r\n"
            + "Content-Length: \(body.count)\r\n"
            + "Connection: close\r\n\r\n"
        var data = Data(head.utf8)
        data.append(body)
        conn.send(content: data, completion: .contentProcessed { _ in conn.cancel() })
    }

    private static func reason(_ status: Int) -> String {
        switch status {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 409: return "Conflict"
        default: return "Internal Server Error"
        }
    }
}
