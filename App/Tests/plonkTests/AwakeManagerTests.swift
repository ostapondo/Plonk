import Testing
import Foundation
@testable import plonk

struct AwakeManagerTests {

    @Test func restoreResumesASessionThatIsStillRunning() {
        let awake = AwakeManager()
        awake.restore(sessionEnd: Date().addingTimeInterval(600))
        #expect(awake.wants)
        #expect(awake.sessionEnd != nil)
        awake.set(false)
    }

    @Test func restoreIgnoresASessionThatRanOutWhileClosed() {
        let awake = AwakeManager()
        awake.restore(sessionEnd: Date().addingTimeInterval(-60))
        #expect(!awake.wants)
        #expect(awake.sessionEnd == nil)
    }

    @Test func restoreWithoutAnEndDateMeansNoLimit() {
        let awake = AwakeManager()
        awake.restore(sessionEnd: nil)
        #expect(awake.wants)
        #expect(awake.sessionEnd == nil)
        awake.set(false)
    }

    @Test func togglingOffClearsTheSession() {
        let awake = AwakeManager()
        awake.set(true, minutes: 30)
        #expect(awake.sessionEnd != nil)
        awake.set(false)
        #expect(!awake.wants)
        #expect(awake.sessionEnd == nil)
    }
}

struct LidSleepTests {

    @Test func theGuardWatchesTheFlagAndWhetherPlonkIsStillAround() {
        let script = LidSleep.guardScript(flagPath: "/tmp/lid-guard")
        #expect(script.contains("/usr/bin/pmset -a disablesleep 1"))
        #expect(script.contains("[ -f \"/tmp/lid-guard\" ]"))
        #expect(script.contains("/usr/bin/pgrep -x plonk"))
        // A relaunch is waited out rather than treated as the app being gone.
        #expect(script.contains("-ge \(LidSleep.graceSeconds)"))
        // Whatever ends the loop, sleep has to come back.
        #expect(script.contains("/usr/bin/pmset -a disablesleep 0"))
        // Backgrounded with its pipes closed, or `do shell script` waits for it.
        #expect(script.hasSuffix("</dev/null >/dev/null 2>&1 &"))
    }

    @Test func aFlagPathThatCouldBreakOutOfTheCommandIsRefused() {
        #expect(LidSleep.isShellSafe("/var/folders/x/plonk-lid-1.guard"))
        #expect(!LidSleep.isShellSafe("/tmp/'; rm -rf /; echo '"))
        #expect(!LidSleep.isShellSafe("/tmp/$(whoami).guard"))
        #expect(!LidSleep.isShellSafe("/tmp/a\"b"))
    }

    @Test func theScriptSurvivesBeingPutInsideAnAppleScriptString() {
        let literal = LidSleep.appleScriptLiteral("say \"hi\"\nand \\ that")
        #expect(literal == "\"say \\\"hi\\\"\\nand \\\\ that\"")
    }
}
