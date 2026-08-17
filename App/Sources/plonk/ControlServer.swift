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
    /// Set instead of a body when the route keeps the socket: the connection
    /// is handed over and the server writes nothing more. Server-sent events
    /// are the only such route, and it stays a route rather than a special
    /// case in the transport.
    let handOff: ((NWConnection) -> Void)?

    init(status: Int, json: [String: Any], handOff: ((NWConnection) -> Void)? = nil) {
        self.status = status
        self.json = json
        self.handOff = handOff
    }

    static func ok(_ json: [String: Any]) -> HTTPResponse { HTTPResponse(status: 200, json: json) }
    static func badRequest(_ message: String) -> HTTPResponse { HTTPResponse(status: 400, json: ["error": message]) }
    static func notFound(_ message: String) -> HTTPResponse { HTTPResponse(status: 404, json: ["error": message]) }
    /// The request was understood and refused: a name already taken, a setting
    /// the user turned off, an agent that is not the one in charge.
    static func conflict(_ message: String) -> HTTPResponse { HTTPResponse(status: 409, json: ["error": message]) }
    static func failed(_ message: String) -> HTTPResponse { HTTPResponse(status: 500, json: ["error": message]) }
    /// Gives the raw connection to `attach`, which owns it from then on.
    static func stream(_ attach: @escaping (NWConnection) -> Void) -> HTTPResponse {
        HTTPResponse(status: 200, json: [:], handOff: attach)
    }
}

final class ControlServer {
    static let port: UInt16 = 43917

    private var listener: NWListener?
    private let handle: (HTTPRequest, @escaping (HTTPResponse) -> Void) -> Void

    /// The secret every request but `/ping` has to carry. Nil only when the
    /// token file could not be read or written; see `APIToken.rejection`.
    private let token: String?

    /// Called on the main queue when the port cannot be claimed, which in
    /// practice means a second Plonk is already running.
    var onUnavailable: ((String) -> Void)?

    init(token: String?, handle: @escaping (HTTPRequest, @escaping (HTTPResponse) -> Void) -> Void) {
        self.token = token
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
                self?.onUnavailable?(String(localized: .warningPortTaken(Int(Self.port))))
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
            // Browser first, so a page that reaches the port is told it is a
            // page rather than told to go and read a file it cannot read.
            if let reason = Self.browserRejection(for: request) {
                self.respond(conn, HTTPResponse(status: 403, json: ["error": reason]))
                return
            }
            if let rejection = APIToken.rejection(for: request, token: self.token) {
                self.respond(conn, HTTPResponse(status: rejection.status,
                                                json: ["error": rejection.message]))
                return
            }
            DispatchQueue.main.async {
                self.handle(request) { [weak self] response in
                    self?.respond(conn, response)
                }
            }
        }
    }

    /// A web page the user happens to have open must not be able to drive the
    /// API. Browsers always attach Origin to cross-site POSTs and
    /// Sec-Fetch-Site to every request, and neither header can be suppressed
    /// from page script. This is kept alongside the token rather than replaced
    /// by it: a page cannot read the token file either, but this refuses the
    /// page for what it is, and does so before anything else is considered.
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
        if let handOff = response.handOff {
            handOff(conn)
            return
        }
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
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 409: return "Conflict"
        case 503: return "Service Unavailable"
        default: return "Internal Server Error"
        }
    }
}
