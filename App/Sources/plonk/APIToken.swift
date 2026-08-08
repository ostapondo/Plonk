import Foundation

/// The shared secret the loopback API is gated on.
///
/// Binding to loopback keeps the machine's network out. It does nothing about
/// the machine itself: every process running as this user can reach the port,
/// and Plonk holds Screen Recording, so an unauthenticated `/shot/capture`
/// hands a caller that has no such grant of its own a picture of the screen.
/// That is the permission being lent out, not just the window layout.
///
/// So a client has to present a token it could only have got by reading a file
/// in this user's home directory. Anything already able to read that file could
/// read the screen by asking macOS directly, which is where this stops being
/// worth more: the point is that reaching the port is no longer enough.
///
/// It lives in its own file rather than in `config.json`, because config is
/// documented as plain JSON people open, edit and paste into bug reports, and a
/// secret in it would leave with the first pasted zone set.
enum APIToken {

    /// Lowercased, because `HTTPRequest.headers` is.
    static let headerName = "x-plonk-token"

    /// Reaching the port must stay enough to answer "is the app running", so
    /// the MCP server and the CLI can tell a closed app from a stale token
    /// without holding either. It reveals nothing else.
    static let openPaths: Set<String> = ["/ping"]

    static func url(in directory: URL? = nil) -> URL {
        let dir = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Plonk", isDirectory: true)
        return dir.appendingPathComponent("token")
    }

    /// The token for this install, generated on first launch.
    ///
    /// A file that cannot be read or written leaves the app without one, and
    /// the caller decides what that means — refusing every request would lock
    /// the user out of their own agent over a permissions problem on a file
    /// they never made.
    static func loadOrCreate(in directory: URL? = nil) -> String? {
        let url = Self.url(in: directory)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        if let existing = try? String(contentsOf: url, encoding: .utf8) {
            let token = existing.trimmingCharacters(in: .whitespacesAndNewlines)
            if !token.isEmpty {
                // An earlier copy, a restored backup or a hand-edited file can
                // be world-readable. Tighten it rather than trust it.
                try? FileManager.default.setAttributes(
                    [.posixPermissions: NSNumber(value: 0o600)], ofItemAtPath: url.path)
                return token
            }
        }

        let token = generate()
        let created = FileManager.default.createFile(
            atPath: url.path,
            contents: Data(token.utf8),
            attributes: [.posixPermissions: NSNumber(value: 0o600)])
        guard created else {
            NSLog("Plonk: could not write the API token to \(url.path)")
            return nil
        }
        return token
    }

    /// 32 bytes, hex. `random(in:)` draws from `SystemRandomNumberGenerator`,
    /// which is the platform's cryptographic source.
    static func generate() -> String {
        (0..<32)
            .map { _ in String(format: "%02x", Int(UInt8.random(in: 0...255))) }
            .joined()
    }

    /// Equal-length comparison that does not stop at the first difference. The
    /// length itself is not secret; which byte failed would be.
    static func matches(_ presented: String, _ token: String) -> Bool {
        let a = Array(presented.utf8), b = Array(token.utf8)
        guard a.count == b.count, !a.isEmpty else { return false }
        var difference: UInt8 = 0
        for i in a.indices { difference |= a[i] ^ b[i] }
        return difference == 0
    }

    /// The 401 reason, or nil when the request may proceed.
    ///
    /// `token` is nil when the app could not read or write the token file. The
    /// API stays open in that case: the alternative is an app that silently
    /// stops answering its own MCP server, which reads as a bug in everything
    /// except the one place the problem is.
    static func rejection(for request: HTTPRequest, token: String?) -> String? {
        guard let token else { return nil }
        if Self.openPaths.contains(request.path) { return nil }
        guard let presented = request.headers[Self.headerName], matches(presented, token) else {
            return "this request carried no valid token. Plonk's API is gated on the token in "
                + "~/Library/Application Support/Plonk/token, which the MCP server and the plonk "
                + "command read for themselves. A client that was started before the token changed "
                + "has to be restarted."
        }
        return nil
    }
}
