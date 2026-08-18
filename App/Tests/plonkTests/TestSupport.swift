import Foundation
@testable import plonk

/// A scratch directory of its own per test, gone when the test is, so nothing
/// here can touch the config or the token the developer's own Plonk runs with.
final class TempDir {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("plonk-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: url) }
}

/// A Router over a scratch store, driven the way a client reaches it.
final class RouterHarness {
    let dir = TempDir()
    let store: ConfigStore
    let router: Router

    init() {
        store = ConfigStore(directory: dir.url)
        router = Router(store: store, windows: WindowManager(), awake: AwakeManager())
        // Mirrors AppDelegate.setupServer, which owns this wiring.
        store.didMutate = { [router] in router.changes.bump("config") }
    }

    func get(_ path: String, headers: [String: String] = [:]) -> HTTPResponse {
        send(HTTPRequest(method: "GET", path: path, headers: headers, body: [:]))
    }

    func post(_ path: String, _ body: [String: Any]) -> HTTPResponse {
        send(HTTPRequest(method: "POST", path: path, headers: [:], body: body))
    }

    func send(_ request: HTTPRequest) -> HTTPResponse {
        var result: HTTPResponse?
        router.handle(request) { result = $0 }
        return result ?? .failed("no response")
    }
}

/// Clock helpers for anything scheduled: a fixed calendar so the answers do
/// not depend on where the test runs.
let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

func at(_ iso: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: iso)!
}
