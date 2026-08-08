import Testing
@testable import plonk

/// The card that decides whether a new install ever moves a window. Its rules
/// are small and every one of them is a way to annoy someone who is already
/// set up, so they are worth pinning down.
struct GettingStartedTests {

    private func guide(accessibility: Bool = false, snapped: Bool = false,
                       agent: Bool = false) -> GettingStarted {
        GettingStarted(accessibilityGranted: accessibility, snapped: snapped, agentConnected: agent)
    }

    @Test func aFreshInstallHasThreeThingsToDo() {
        let fresh = guide()
        #expect(fresh.steps.count == 3)
        #expect(fresh.doneCount == 0)
        #expect(!fresh.isComplete)
        #expect(fresh.next?.id == "grant")
    }

    /// The next step is the first undone one, not the first one — otherwise the
    /// card keeps pointing at a permission that was granted minutes ago.
    @Test func theNextStepSkipsWhatIsDone() {
        #expect(guide(accessibility: true).next?.id == "snap")
        #expect(guide(accessibility: true, snapped: true).next?.id == "agent")
        #expect(guide(accessibility: true, snapped: true, agent: true).next == nil)
    }

    @Test func allThreeDoneMeansComplete() {
        let done = guide(accessibility: true, snapped: true, agent: true)
        #expect(done.isComplete)
        #expect(done.doneCount == 3)
    }

    /// Out of order is normal: an agent can be connected before the user has
    /// ever pressed a shortcut.
    @Test func stepsTickIndependently() {
        let partial = guide(accessibility: true, agent: true)
        #expect(partial.doneCount == 2)
        #expect(!partial.isComplete)
        #expect(partial.next?.id == "snap")
    }

    @Test func itHidesWhenFinishedOrDismissed() {
        #expect(GettingStarted.isVisible(hidden: false, complete: false))
        #expect(!GettingStarted.isVisible(hidden: true, complete: false))
        #expect(!GettingStarted.isVisible(hidden: false, complete: true))
        #expect(!GettingStarted.isVisible(hidden: true, complete: true))
    }
}
