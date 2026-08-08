import Testing
import Foundation
@testable import plonk

struct APITokenFileTests {

    /// A directory of its own per test, so nothing here can touch the token the
    /// developer's own copy of Plonk is running with.
    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("plonk-token-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func firstLaunchWritesATokenAndKeepsIt() throws {
        let dir = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let first = try #require(APIToken.loadOrCreate(in: dir))
        #expect(!first.isEmpty)
        #expect(APIToken.loadOrCreate(in: dir) == first)
    }

    @Test func theFileIsReadableOnlyByItsOwner() throws {
        let dir = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        _ = APIToken.loadOrCreate(in: dir)
        let attributes = try FileManager.default.attributesOfItem(atPath: APIToken.url(in: dir).path)
        let mode = try #require(attributes[.posixPermissions] as? NSNumber)
        #expect(mode.int16Value == 0o600)
    }

    /// A file restored from a backup, or copied by hand, can arrive readable by
    /// everyone. Reading it is also the moment to fix it.
    @Test func aLooseFileIsTightenedRatherThanTrusted() throws {
        let dir = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = APIToken.url(in: dir)
        FileManager.default.createFile(
            atPath: url.path,
            contents: Data("borrowed\n".utf8),
            attributes: [.posixPermissions: NSNumber(value: 0o644)])

        #expect(APIToken.loadOrCreate(in: dir) == "borrowed")
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let mode = try #require(attributes[.posixPermissions] as? NSNumber)
        #expect(mode.int16Value == 0o600)
    }

    @Test func anEmptyFileIsReplacedRatherThanUsed() throws {
        let dir = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data("   \n".utf8).write(to: APIToken.url(in: dir))

        let token = try #require(APIToken.loadOrCreate(in: dir))
        #expect(!token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test func twoInstallsDoNotShareAToken() {
        let a = temporaryDirectory(), b = temporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: a)
            try? FileManager.default.removeItem(at: b)
        }
        #expect(APIToken.loadOrCreate(in: a) != APIToken.loadOrCreate(in: b))
    }
}

struct APITokenComparisonTests {

    @Test func aTokenMatchesItself() {
        let token = APIToken.generate()
        #expect(APIToken.matches(token, token))
    }

    @Test func aDifferentTokenOfTheSameLengthDoesNot() {
        #expect(!APIToken.matches(String(repeating: "a", count: 64), String(repeating: "b", count: 64)))
    }

    @Test func aPrefixIsNotEnough() {
        let token = APIToken.generate()
        #expect(!APIToken.matches(String(token.dropLast()), token))
    }

    @Test func emptyMatchesNothingIncludingItself() {
        #expect(!APIToken.matches("", ""))
    }

    @Test func generatedTokensAreLongAndDistinct() {
        let tokens = Set((0..<32).map { _ in APIToken.generate() })
        #expect(tokens.count == 32)
        #expect(tokens.allSatisfy { $0.count == 64 })
    }
}

struct APITokenRejectionTests {

    private let token = "5f1e" + String(repeating: "0", count: 60)

    private func request(_ path: String, headers: [String: String] = [:]) -> HTTPRequest {
        HTTPRequest(method: "POST", path: path, headers: headers, body: [:])
    }

    @Test func theRightTokenIsLetThrough() {
        let r = request("/shot/capture", headers: [APIToken.headerName: token])
        #expect(APIToken.rejection(for: r, token: token) == nil)
    }

    @Test func aRequestWithoutOneIsRefused() {
        #expect(APIToken.rejection(for: request("/shot/capture"), token: token) != nil)
    }

    @Test func aWrongTokenIsRefused() {
        let r = request("/shot/capture", headers: [APIToken.headerName: String(repeating: "0", count: 64)])
        #expect(APIToken.rejection(for: r, token: token) != nil)
    }

    /// The screenshot routes are the reason the gate exists: they lend out
    /// Screen Recording, which the caller may well not hold itself.
    @Test func capturingAndReadingTheScreenAreBothGated() {
        for path in ["/shot/capture", "/shot/text", "/state"] {
            #expect(APIToken.rejection(for: request(path), token: token) != nil,
                    Comment(rawValue: path))
        }
    }

    @Test func pingStaysOpenSoAClosedAppIsTellableFromAStaleToken() {
        #expect(APIToken.rejection(for: request("/ping"), token: token) == nil)
    }

    /// Without a token the app says so in its own window rather than refusing
    /// every request, which would look like a broken MCP server.
    @Test func anAppWithoutATokenGatesNothing() {
        #expect(APIToken.rejection(for: request("/shot/capture"), token: nil) == nil)
    }

    @Test func theHeaderSurvivesRequestParsing() throws {
        let raw = "POST /state HTTP/1.1\r\nX-Plonk-Token: \(token)\r\n\r\n"
        let parsed = try #require(ControlServer.parseIfComplete(Data(raw.utf8)))
        #expect(APIToken.rejection(for: parsed, token: token) == nil)
    }
}
