import Testing
import Foundation
@testable import plonk

struct ControlServerParseTests {

    @Test func parsesGetWithoutBody() throws {
        let request = try #require(ControlServer.parseIfComplete(
            Data("GET /state HTTP/1.1\r\nHost: localhost\r\n\r\n".utf8)))
        #expect(request.method == "GET")
        #expect(request.path == "/state")
        #expect(request.body.isEmpty)
        #expect(request.headers["host"] == "localhost")
    }

    @Test func parsesPostWithJSONBody() throws {
        let body = #"{"on":true}"#
        let request = try #require(ControlServer.parseIfComplete(
            Data("POST /awake HTTP/1.1\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)".utf8)))
        #expect(request.method == "POST")
        #expect(request.path == "/awake")
        #expect(request.body["on"] as? Bool == true)
    }

    @Test func incompleteHeadersReturnNil() {
        #expect(ControlServer.parseIfComplete(Data("POST /awake HTTP/1.1\r\nContent-Le".utf8)) == nil)
    }

    @Test func incompleteBodyReturnsNil() {
        let request = Data("POST /awake HTTP/1.1\r\nContent-Length: 20\r\n\r\n{\"on\":".utf8)
        #expect(ControlServer.parseIfComplete(request) == nil)
    }

    @Test func caseInsensitiveContentLength() throws {
        let body = #"{"a":1}"#
        let request = try #require(ControlServer.parseIfComplete(
            Data("POST /x HTTP/1.1\r\ncontent-length: \(body.utf8.count)\r\n\r\n\(body)".utf8)))
        #expect(request.body["a"] as? Int == 1)
    }

    @Test func malformedRequestLineReturnsNil() {
        #expect(ControlServer.parseIfComplete(Data("NONSENSE\r\n\r\n".utf8)) == nil)
    }
}

struct BrowserRejectionTests {

    private func request(headers: [String: String]) -> HTTPRequest {
        HTTPRequest(method: "POST", path: "/shot/capture", headers: headers, body: [:])
    }

    @Test func plainClientsAreAccepted() {
        #expect(ControlServer.browserRejection(for: request(headers: ["host": "127.0.0.1:43917"])) == nil)
    }

    @Test func crossSiteOriginIsRejected() {
        #expect(ControlServer.browserRejection(for: request(headers: ["origin": "https://evil.example"])) != nil)
    }

    /// A simple content type dodges the CORS preflight, so Origin alone is not
    /// enough; every browser fetch also carries Sec-Fetch-Site.
    @Test func browserFetchWithoutOriginIsRejected() {
        #expect(ControlServer.browserRejection(for: request(headers: ["sec-fetch-site": "cross-site"])) != nil)
    }

    @Test func rejectionSurvivesHeaderCasing() throws {
        let raw = "POST /shot/capture HTTP/1.1\r\nOrigin: https://evil.example\r\n\r\n"
        let parsed = try #require(ControlServer.parseIfComplete(Data(raw.utf8)))
        #expect(ControlServer.browserRejection(for: parsed) != nil)
    }
}

struct PresetTests {

    @Test func allPresetFractionsStayInBounds() {
        for preset in Preset.allCases {
            let f = preset.frac
            #expect(f.x >= 0 && f.y >= 0, Comment(rawValue: preset.rawValue))
            #expect(f.x + f.w <= 1.0001 && f.y + f.h <= 1.0001, Comment(rawValue: preset.rawValue))
        }
    }
}
