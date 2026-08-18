import Testing
import Foundation
@testable import plonk

// The /shot routes, driven through Router the way a client reaches them. Taking
// a real screenshot needs a desktop and a Screen Recording grant, so capture is
// stubbed and what is checked is the answer each outcome earns.
struct ShotRoutesTests {

    @Test func captureReportsCancellation() {
        let h = RouterHarness()
        h.router.shots.capture = { _, _, done in done(nil) }
        #expect(h.post("/shot/capture", ["mode": "region"]).status == 409)
    }

    /// Naming no window is the caller's mistake, and saying so must not depend
    /// on capture being wired up — nor may it quietly photograph the screen,
    /// which would answer a question nobody asked and look right doing it.
    @Test func appCaptureNeedsAWindowToBeNamed() {
        let h = RouterHarness()
        var screenCaptures = 0
        h.router.shots.capture = { _, _, done in
            screenCaptures += 1
            done(nil)
        }
        #expect(h.post("/shot/capture", ["mode": "app"]).status == 400)
        #expect(h.post("/shot/capture", ["mode": "app", "app": "   "]).status == 400)
        #expect(screenCaptures == 0)
    }

    @Test func appCaptureReportsAWindowItCouldNotFind() {
        let h = RouterHarness()
        h.router.shots.captureWindow = { query, _, done in
            done(.failure(.noMatch(query, tried: 12)))
        }
        let response = h.post("/shot/capture", ["mode": "app", "app": "Spotify"])
        #expect(response.status == 404)
        #expect((response.json["error"] as? String)?.contains("Spotify") == true)
    }

    /// A minimized window is a real window that cannot be photographed, which
    /// is neither a bad request nor a missing one.
    @Test func appCaptureReportsAWindowItCouldNotPhotograph() {
        let h = RouterHarness()
        h.router.shots.captureWindow = { _, _, done in
            done(.failure(.captureFailed(WindowCapture.Candidate(
                id: 7, app: "Spotify", bundleID: "com.spotify.client", title: "Premium",
                bounds: CGRect(x: 0, y: 0, width: 800, height: 600), onScreen: false))))
        }
        let response = h.post("/shot/capture", ["mode": "app", "app": "Spotify"])
        #expect(response.status == 409)
        #expect((response.json["error"] as? String)?.contains("un-minimize") == true)
    }

    /// Both halves of the query reach the finder, since either alone can be
    /// what tells two windows of the same app apart.
    @Test func appCaptureForwardsTheWholeQuery() {
        let h = RouterHarness()
        var asked: WindowCapture.Query?
        h.router.shots.captureWindow = { query, _, done in
            asked = query
            done(.failure(.noMatch(query, tried: 1)))
        }
        _ = h.post("/shot/capture", ["mode": "app", "app": "Code", "title_contains": "Router.swift"])
        #expect(asked?.app == "Code")
        #expect(asked?.titleContains == "Router.swift")
    }

    /// An unknown mode falls back to the whole screen rather than 400: the
    /// modes have grown before and a client that is behind still works.
    @Test func anUnknownModeIsTakenAsTheScreen() {
        let h = RouterHarness()
        var asked: CaptureMode?
        h.router.shots.capture = { mode, _, done in
            asked = mode
            done(nil)
        }
        _ = h.post("/shot/capture", ["mode": "nonsense"])
        #expect(asked == .screen)
    }
}
