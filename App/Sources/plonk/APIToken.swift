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
    /// Nil when there is no file this user can both read and keep to
    /// themselves. That is not a token, so the API refuses to answer rather
    /// than answering to anyone — see `rejection`.
    static func loadOrCreate(in directory: URL? = nil) -> String? {
        let url = Self.url(in: directory)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) {
            // Somebody else's file — one `sudo` launch leaves a root-owned one
            // behind — cannot be tightened by this user and must not be
            // trusted: its contents are a secret they do not control. Same for
            // anything that is not a plain file.
            let owner = (attributes[.ownerAccountID] as? NSNumber)?.uint32Value
            guard owner == getuid() else {
                NSLog("Plonk: the API token at \(url.path) belongs to another user (uid \(owner.map(String.init) ?? "unknown"))")
                return nil
            }
            guard attributes[.type] as? FileAttributeType == .typeRegular else {
                NSLog("Plonk: the API token path \(url.path) is not a regular file")
                return nil
            }
        }

        if let existing = try? String(contentsOf: url, encoding: .utf8) {
            let token = existing.trimmingCharacters(in: .whitespacesAndNewlines)
            if !token.isEmpty {
                // An earlier copy, a restored backup or a hand-edited file can
                // be world-readable. Tighten it rather than trust it — and if
                // it will not tighten, it is a secret the rest of the machine
                // has already read, so it is no longer one.
                try? FileManager.default.setAttributes(
                    [.posixPermissions: NSNumber(value: 0o600)], ofItemAtPath: url.path)
                let mode = (try? FileManager.default.attributesOfItem(atPath: url.path))
                    .flatMap { ($0[.posixPermissions] as? NSNumber)?.int16Value } ?? 0
                guard mode & 0o077 == 0 else {
                    NSLog("Plonk: the API token at \(url.path) stayed readable by other users")
                    return nil
                }
                return token
            }
        }

        // Created by open(2) rather than FileManager, which writes the file
        // first and applies `.posixPermissions` after: on this machine a stat
        // loop caught the new token at mode 0644, secret already inside, three
        // times in four thousand samples. That window belongs to exactly the
        // process this file exists to keep out. O_EXCL means we never write
        // into something already there, and O_NOFOLLOW means never through a
        // symlink someone planted.
        let token = generate()
        // Only a blank or unreadable file reaches here; a usable one returned
        // above, and one that is not ours was refused.
        try? FileManager.default.removeItem(at: url)
        let descriptor = open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else {
            NSLog("Plonk: could not create the API token at \(url.path) (errno \(errno))")
            return nil
        }
        defer { close(descriptor) }
        let bytes = Array(token.utf8)
        let written = bytes.withUnsafeBufferPointer { write(descriptor, $0.baseAddress, $0.count) }
        guard written == bytes.count else {
            NSLog("Plonk: could not write the API token to \(url.path) (errno \(errno))")
            try? FileManager.default.removeItem(at: url)
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

    /// Why a request is not being answered: the caller's problem, or the app's.
    /// They are different failures and a client can only act on the difference.
    struct Rejection: Equatable {
        var status: Int
        var message: String
    }

    /// The rejection, or nil when the request may proceed.
    ///
    /// A missing token fails closed. The gate exists because reaching the port
    /// must not be enough to borrow Screen Recording, and an app that cannot
    /// hold a secret has not stopped holding that grant — so it stops
    /// answering instead, loudly, in a way that says which file to look at.
    /// The cost is an agent that goes quiet until a permissions problem is
    /// fixed; the alternative is a screenshot for anything on the machine that
    /// opens a socket.
    static func rejection(for request: HTTPRequest, token: String?) -> Rejection? {
        // The router strips the query before matching a path, so this must
        // too — otherwise "/ping?t=1" misses the one rule written to let it
        // through, and the two disagree about what a path is.
        let path = Router.splitQuery(request.path).path
        if Self.openPaths.contains(path) { return nil }
        guard let token else {
            return Rejection(status: 503, message:
                "Plonk has no usable API token, so it is answering nothing but /ping. The token "
                + "lives at ~/Library/Application Support/Plonk/token and has to be a plain file "
                + "owned by you and readable by you alone. Delete it and relaunch Plonk to have a "
                + "new one written.")
        }
        guard let presented = request.headers[Self.headerName], matches(presented, token) else {
            return Rejection(status: 401, message:
                "this request carried no valid token. Plonk's API is gated on the token in "
                + "~/Library/Application Support/Plonk/token, which the MCP server and the plonk "
                + "command read for themselves. A client that was started before the token changed "
                + "has to be restarted.")
        }
        return nil
    }
}
