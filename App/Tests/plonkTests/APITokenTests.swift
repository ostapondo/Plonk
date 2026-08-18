import Testing
import Foundation
@testable import plonk

struct APITokenFileTests {

    @Test func firstLaunchWritesATokenAndKeepsIt() throws {
        let dir = TempDir()

        let first = try #require(APIToken.loadOrCreate(in: dir.url))
        #expect(!first.isEmpty)
        #expect(APIToken.loadOrCreate(in: dir.url) == first)
    }

    @Test func theFileIsReadableOnlyByItsOwner() throws {
        let dir = TempDir()

        _ = APIToken.loadOrCreate(in: dir.url)
        let attributes = try FileManager.default.attributesOfItem(atPath: APIToken.url(in: dir.url).path)
        let mode = try #require(attributes[.posixPermissions] as? NSNumber)
        #expect(mode.int16Value == 0o600)
    }

    /// A file restored from a backup, or copied by hand, can arrive readable by
    /// everyone — and by the time Plonk sees it, anything on the machine may
    /// already have read it. Fixing the mode does not unread it, so the secret
    /// itself is replaced.
    @Test func aLooseFileIsReplacedRatherThanTightened() throws {
        let dir = TempDir()
        let url = APIToken.url(in: dir.url)
        FileManager.default.createFile(
            atPath: url.path,
            contents: Data("borrowed\n".utf8),
            attributes: [.posixPermissions: NSNumber(value: 0o644)])

        let token = try #require(APIToken.loadOrCreate(in: dir.url))
        #expect(token != "borrowed")
        #expect(token.count == 64)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let mode = try #require(attributes[.posixPermissions] as? NSNumber)
        #expect(mode.int16Value == 0o600)
        // And it stays put from then on, rather than rotating every launch.
        #expect(APIToken.loadOrCreate(in: dir.url) == token)
    }

    @Test func anEmptyFileIsReplacedRatherThanUsed() throws {
        let dir = TempDir()
        try Data("   \n".utf8).write(to: APIToken.url(in: dir.url))

        let token = try #require(APIToken.loadOrCreate(in: dir.url))
        #expect(!token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test func twoInstallsDoNotShareAToken() {
        let a = TempDir(), b = TempDir()
        #expect(APIToken.loadOrCreate(in: a.url) != APIToken.loadOrCreate(in: b.url))
    }

    /// A file this user cannot tighten is one the rest of the machine has
    /// already read. It is not a secret any more, so it is not a token.
    @Test func aFileThatWillNotTightenIsRefused() throws {
        let dir = TempDir()
        let url = APIToken.url(in: dir.url)
        FileManager.default.createFile(atPath: url.path, contents: Data("loose\n".utf8),
                                       attributes: [.posixPermissions: NSNumber(value: 0o644)])
        // Make the directory read-only so the mode cannot be changed, the way
        // a root-owned file behaves for a normal user.
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: url.path)

        #expect(APIToken.loadOrCreate(in: dir.url) == nil)
        try FileManager.default.setAttributes([.immutable: false], ofItemAtPath: url.path)
    }

    /// A symlink at that path would have the token written wherever it points,
    /// with this user's hand on the pen. Refused twice over: the attributes of
    /// a link are the link's, and the create is O_NOFOLLOW.
    @Test func aSymlinkAtTheTokenPathIsRefused() throws {
        let dir = TempDir()
        let target = dir.url.appendingPathComponent("elsewhere")
        FileManager.default.createFile(atPath: target.path, contents: Data())
        try FileManager.default.createSymbolicLink(at: APIToken.url(in: dir.url), withDestinationURL: target)

        #expect(APIToken.loadOrCreate(in: dir.url) == nil)
        #expect(try String(contentsOf: target, encoding: .utf8).isEmpty)
    }

    /// Anything that is not a plain file — a directory planted at that path
    /// before first launch — is refused rather than worked around.
    @Test func aDirectoryAtTheTokenPathIsRefused() throws {
        let dir = TempDir()
        try FileManager.default.createDirectory(at: APIToken.url(in: dir.url), withIntermediateDirectories: true)

        #expect(APIToken.loadOrCreate(in: dir.url) == nil)
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

    /// Fail closed. An app that cannot hold a secret still holds Screen
    /// Recording, so it stops answering rather than answering to anyone.
    @Test func anAppWithoutATokenRefusesEverythingButPing() {
        let refused = APIToken.rejection(for: request("/shot/capture"), token: nil)
        #expect(refused?.status == 503)
        // Still tellable from a closed app, which is all /ping is for.
        #expect(APIToken.rejection(for: request("/ping"), token: nil) == nil)
    }

    /// A bad token is the caller's problem and a missing one is the app's, and
    /// a client can only tell them apart by the status.
    @Test func theTwoFailuresAreDifferentStatuses() {
        #expect(APIToken.rejection(for: request("/state"), token: token)?.status == 401)
        #expect(APIToken.rejection(for: request("/state"), token: nil)?.status == 503)
    }

    /// The router matches paths with the query stripped. So must the gate, or
    /// the only always-open route stops being open the moment anything adds a
    /// parameter to it.
    @Test func theQueryDoesNotHideAnOpenPath() {
        #expect(APIToken.rejection(for: request("/ping?t=1"), token: token) == nil)
        #expect(APIToken.rejection(for: request("/state?screen=0"), token: token)?.status == 401)
    }

    @Test func theHeaderSurvivesRequestParsing() throws {
        let raw = "POST /state HTTP/1.1\r\nX-Plonk-Token: \(token)\r\n\r\n"
        let parsed = try #require(ControlServer.parseIfComplete(Data(raw.utf8)))
        #expect(APIToken.rejection(for: parsed, token: token) == nil)
    }
}
