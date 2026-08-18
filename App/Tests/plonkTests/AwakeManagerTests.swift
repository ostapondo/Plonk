import Testing
import Foundation
@testable import plonk

struct AwakeManagerTests {

    @Test func restoreResumesASessionThatIsStillRunning() {
        let awake = AwakeManager()
        awake.restore(sessionEnd: Date().addingTimeInterval(600))
        #expect(awake.requested)
        #expect(awake.sessionEnd != nil)
        awake.set(false)
    }

    @Test func restoreIgnoresASessionThatRanOutWhileClosed() {
        let awake = AwakeManager()
        awake.restore(sessionEnd: Date().addingTimeInterval(-60))
        #expect(!awake.requested)
        #expect(awake.sessionEnd == nil)
    }

    @Test func restoreWithoutAnEndDateMeansNoLimit() {
        let awake = AwakeManager()
        awake.restore(sessionEnd: nil)
        #expect(awake.requested)
        #expect(awake.sessionEnd == nil)
        awake.set(false)
    }

    @Test func togglingOffClearsTheSession() {
        let awake = AwakeManager()
        awake.set(true, minutes: 30)
        #expect(awake.sessionEnd != nil)
        awake.set(false)
        #expect(!awake.requested)
        #expect(awake.sessionEnd == nil)
    }
}
