import Testing
import AppKit
@testable import plonk

// Which window a name lands on. The capture itself needs a real desktop and a
// Screen Recording grant, so it stays out; picking the right one out of a
// crowded desk is the part that can be wrong quietly, and it is all here.
struct WindowCaptureTests {

    private func candidate(_ app: String, _ title: String = "", bundleID: String = "",
                           size: CGSize = CGSize(width: 800, height: 600),
                           onScreen: Bool = true, id: CGWindowID = 1) -> WindowCapture.Candidate {
        WindowCapture.Candidate(id: id, app: app, bundleID: bundleID, title: title,
                                bounds: CGRect(origin: .zero, size: size), onScreen: onScreen)
    }

    private func found(_ query: WindowCapture.Query,
                       _ all: [WindowCapture.Candidate]) -> WindowCapture.Candidate? {
        try? WindowCapture.find(query, among: all).get()
    }

    @Test func anAppNameIsAnySubstringInAnyCase() {
        let all = [candidate("Spotify", "Radiohead — Weird Fishes")]
        #expect(found(WindowCapture.Query(app: "spot"), all)?.app == "Spotify")
        #expect(found(WindowCapture.Query(app: "SPOTIFY"), all)?.app == "Spotify")
        #expect(found(WindowCapture.Query(app: "Notes"), all) == nil)
    }

    /// "Code" is a substring of "Xcode", and Xcode's window is the bigger of
    /// the two — so on substrings alone the wrong editor wins, and wins
    /// quietly, since what comes back is a perfectly good screenshot.
    @Test func anExactNameBeatsAnAppThatMerelyContainsIt() {
        let all = [
            candidate("Xcode", "MyApp.xcodeproj", size: CGSize(width: 1600, height: 1000), id: 1),
            candidate("Code", "Router.swift", size: CGSize(width: 900, height: 700), id: 2),
        ]
        #expect(found(WindowCapture.Query(app: "Code"), all)?.app == "Code")
        #expect(found(WindowCapture.Query(app: "Xcode"), all)?.app == "Xcode")
        // Nothing is exact here, so the substring still has to find something.
        #expect(found(WindowCapture.Query(app: "cod"), all) != nil)
    }

    /// `get_state` prints a bundle id next to every window, so pasting one back
    /// has to work; the window server does not carry it, which is why it is
    /// looked up per process.
    @Test func aBundleIdFindsTheApp() {
        let all = [candidate("Spotify", "Weird Fishes", bundleID: "com.spotify.client")]
        #expect(found(WindowCapture.Query(app: "com.spotify.client"), all)?.app == "Spotify")
        #expect(found(WindowCapture.Query(app: "spotify.cl"), all)?.app == "Spotify")
        #expect(found(WindowCapture.Query(app: "com.apple.Safari"), all) == nil)
    }

    /// An exact bundle id is as precise as an exact name, so it outranks an app
    /// whose name merely contains the query.
    @Test func anExactBundleIdOutranksAPartialName() {
        let all = [
            candidate("Spotify Helper", size: CGSize(width: 1600, height: 1000), id: 1),
            candidate("Spotify", bundleID: "spotify", size: CGSize(width: 900, height: 700), id: 2),
        ]
        #expect(found(WindowCapture.Query(app: "spotify"), all)?.app == "Spotify")
    }

    /// The point of the feature: the window the user cannot see is exactly the
    /// one they are asking about, so being off screen must not disqualify it.
    @Test func aWindowOnAnotherSpaceIsStillFound() {
        let all = [candidate("Spotify", onScreen: false)]
        #expect(found(WindowCapture.Query(app: "Spotify"), all)?.app == "Spotify")
    }

    /// But when the app has one of each, the visible one is the one they mean.
    @Test func theOnScreenWindowWinsOverAParkedOne() {
        let all = [
            candidate("Spotify", "parked", size: CGSize(width: 1400, height: 900), onScreen: false, id: 1),
            candidate("Spotify", "here", size: CGSize(width: 400, height: 300), onScreen: true, id: 2),
        ]
        #expect(found(WindowCapture.Query(app: "Spotify"), all)?.title == "here")
    }

    /// An app's main window is its big one; the mini player and the inspector
    /// are not, however recently they were in front.
    @Test func theLargestWindowWinsAmongVisibleOnes() {
        let all = [
            candidate("Spotify", "Mini Player", size: CGSize(width: 300, height: 120), id: 1),
            candidate("Spotify", "Spotify Premium", size: CGSize(width: 1400, height: 900), id: 2),
        ]
        #expect(found(WindowCapture.Query(app: "Spotify"), all)?.title == "Spotify Premium")
    }

    /// Same app, same size: the window server lists front to back, so the first
    /// one is the one the user was last looking at.
    @Test func aTieGoesToTheFrontmost() {
        let all = [
            candidate("Code", "front.swift", id: 1),
            candidate("Code", "behind.swift", id: 2),
        ]
        #expect(found(WindowCapture.Query(app: "Code"), all)?.title == "front.swift")
    }

    @Test func aTitleNarrowsWithinTheApp() {
        let all = [
            candidate("Code", "Router.swift — plonk", size: CGSize(width: 1400, height: 900), id: 1),
            candidate("Code", "notes.md — journal", size: CGSize(width: 1400, height: 900), id: 2),
        ]
        #expect(found(WindowCapture.Query(app: "Code", titleContains: "journal"), all)?.id == 2)
        #expect(found(WindowCapture.Query(titleContains: "Router"), all)?.id == 1)
    }

    /// A capture that fails moves to the next match, so the order has to hold
    /// past the winner: a minimized window looks exactly like one on another
    /// Space from here, and only the first of those cannot be photographed.
    @Test func theMatchesAreRankedAllTheWayDown() {
        let all = [
            candidate("Notes", id: 1),
            candidate("Spotify", "minimized", size: CGSize(width: 1400, height: 900), onScreen: false, id: 2),
            candidate("Spotify", "other Space", size: CGSize(width: 900, height: 600), onScreen: false, id: 3),
            candidate("Spotify", "visible", size: CGSize(width: 400, height: 300), onScreen: true, id: 4),
        ]
        let order = WindowCapture.ranked(WindowCapture.Query(app: "Spotify"), among: all).map(\.id)
        #expect(order == [4, 2, 3])
    }

    @Test func askingForNothingIsRefused() {
        guard case .failure(let failure) = WindowCapture.find(WindowCapture.Query(), among: []) else {
            Issue.record("an empty query should not match anything")
            return
        }
        guard case .nothingAsked = failure else {
            Issue.record("expected nothingAsked, got \(failure)")
            return
        }
        #expect(WindowCapture.Query(app: "", titleContains: "").isEmpty)
    }

    @Test func aMissedQuerySaysWhatItLookedFor() {
        let all = [candidate("Notes")]
        guard case .failure(let failure) =
                WindowCapture.find(WindowCapture.Query(app: "Spotify"), among: all) else {
            Issue.record("Spotify is not open in this fixture")
            return
        }
        let message = failure.localizedDescription
        #expect(message.contains("Spotify"))
        #expect(message.contains("get_state"))
    }

    @Test func anEmptyDesktopSaysSoRatherThanNamingTheQuery() {
        guard case .failure(let failure) =
                WindowCapture.find(WindowCapture.Query(app: "Spotify"), among: []) else {
            Issue.record("nothing can match an empty desktop")
            return
        }
        #expect(failure.localizedDescription.contains("nothing is open"))
    }

    /// Without Screen Recording the desk looks nearly normal — the window list
    /// answers, only every title in it is empty — and the capture then writes
    /// no file, which is exactly what a minimized window does. Blaming the
    /// window would send the user to un-minimize something that is not
    /// minimized, so the permission is checked before any of that runs.
    @Test func theMissingPermissionIsNamedRatherThanTheWindow() {
        let message = WindowCapture.Failure.notPermitted.localizedDescription
        #expect(message.contains("Screen Recording"))
        #expect(!message.contains("minimized"))
    }
}
