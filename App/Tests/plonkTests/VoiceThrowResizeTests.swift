import Testing
@testable import plonk

/// Throwing a window to another display and sizing it, said out loud.
struct VoiceThrowResizeTests {

    @Test func aWindowIsThrownToTheNextOrPreviousDisplay() {
        #expect(VoiceCommand.parse("throw it to the next screen") == .throwToDisplay(next: true))
        #expect(VoiceCommand.parse("put this on the other monitor") == .throwToDisplay(next: true))
        #expect(VoiceCommand.parse("move it to the previous display") == .throwToDisplay(next: false))
    }

    @Test func aWindowIsMadeBiggerOrSmaller() {
        #expect(VoiceCommand.parse("make it bigger") == .resize(larger: true))
        #expect(VoiceCommand.parse("larger") == .resize(larger: true))
        #expect(VoiceCommand.parse("make this smaller") == .resize(larger: false))
    }

    /// An app named, or no display named, is not one of these.
    @Test func whatStillGoesToTheAgent() {
        #expect(VoiceCommand.parse("throw chrome to the next screen") == nil)
        #expect(VoiceCommand.parse("make chrome bigger") == nil)
        #expect(VoiceCommand.parse("put this next to the terminal") == nil)
    }

    @Test func theHalvesStillWin() {
        #expect(VoiceCommand.parse("snap this left") == .preset(.leftHalf))
        #expect(VoiceCommand.parse("fill the screen") == .preset(.maximize))
    }
}
