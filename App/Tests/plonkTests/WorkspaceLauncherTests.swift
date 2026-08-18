import Testing
import AppKit
@testable import plonk

// Launching itself needs a desktop session; what is testable is the bookkeeping
// around it — the lock, and which screen an item goes back to.
struct WorkspaceLauncherTests {

    /// Off the test's own thread: `cancel` used to take the non-recursive lock
    /// twice and block forever, which as an inline call hangs the run instead of
    /// failing it.
    private func expectReturns(_ body: @escaping () -> Void, _ what: Comment) {
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            body()
            done.signal()
        }
        #expect(done.wait(timeout: .now() + 5) == .success, what)
    }

    @Test func cancelReturnsWhenNothingIsLaunching() {
        let launcher = WorkspaceLauncher(windows: WindowManager())
        expectReturns({ launcher.cancel() }, "cancel deadlocked")
    }

    @Test func cancelIsRepeatable() {
        let launcher = WorkspaceLauncher(windows: WindowManager())
        expectReturns({ launcher.cancel(); launcher.cancel() }, "cancel deadlocked on the second call")
    }

    @Test func anEmptyWorkspaceReportsWhyItDidNotLaunch() {
        let launcher = WorkspaceLauncher(windows: WindowManager())
        var results: [[String: Any]]?
        launcher.launch(Workspace(items: []), named: "work") { results = $0 }
        #expect(results?.first?["ok"] as? Bool == false)
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
