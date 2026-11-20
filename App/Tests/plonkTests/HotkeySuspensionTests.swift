import Testing
@testable import plonk

struct HotkeySuspensionTests {
    @Test func eachSuspensionFinishesHeldActionsOnlyOnce() {
        let manager = HotkeyManager()
        var finished = 0
        manager.onSuspend = { finished += 1 }
        manager.setSuspended(true)
        manager.setSuspended(true)
        #expect(finished == 1)
        manager.setSuspended(false)
        #expect(finished == 1)
        manager.setSuspended(true)
        #expect(finished == 2)
    }
}
