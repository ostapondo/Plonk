import Testing
import AppKit
@testable import plonk

// Launching itself needs a desktop session; what is testable is the bookkeeping
// around it — the lock, and which screen an item goes back to.
struct WorkspaceLauncherTests {

    /// `cancel` used to read `isRunning`, taking the non-recursive lock twice on
    /// the caller's thread and hanging the main queue behind the Cancel button.
    @Test(.timeLimit(.minutes(1)))
    func cancelReturnsWhenNothingIsLaunching() {
        let launcher = WorkspaceLauncher(windows: WindowManager())
        launcher.cancel()
        #expect(launcher.isRunning == false)
    }

    @Test(.timeLimit(.minutes(1)))
    func cancelIsRepeatable() {
        let launcher = WorkspaceLauncher(windows: WindowManager())
        launcher.cancel()
        launcher.cancel()
        #expect(launcher.isRunning == false)
    }

    @Test func anEmptyWorkspaceReportsWhyItDidNotLaunch() {
        let launcher = WorkspaceLauncher(windows: WindowManager())
        var results: [[String: Any]]?
        launcher.launch(Workspace(items: []), named: "work") { results = $0 }
        #expect(results?.first?["ok"] as? Bool == false)
        #expect(launcher.isRunning == false)
    }

    /// A workspace saved on two monitors and launched on one used to clamp onto
    /// the last screen; nil leaves the window where it already is instead.
    @Test func aScreenThatIsGoneFallsBackToNoPreference() {
        let item = WorkspaceItem(app: "Safari", screen: 999, x: 0, y: 0, w: 1, h: 1)
        #expect(WorkspaceLauncher.screenIndex(for: item) == nil)
    }

    @Test func anAttachedScreenIndexIsKept() throws {
        try #require(!NSScreen.screens.isEmpty)
        let item = WorkspaceItem(app: "Safari", screen: 0, x: 0, y: 0, w: 1, h: 1)
        #expect(WorkspaceLauncher.screenIndex(for: item) == 0)
    }

    @Test func anItemWithNoScreenHasNoPreference() {
        let item = WorkspaceItem(app: "Safari", x: 0, y: 0, w: 1, h: 1)
        #expect(WorkspaceLauncher.screenIndex(for: item) == nil)
    }
}
