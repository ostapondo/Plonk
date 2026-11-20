import AppKit
import Carbon.HIToolbox
import Testing
@testable import plonk

struct ShotKeyCommandTests {
    @Test func escapeCancels() {
        #expect(ShotKeyCommand(keyCode: kVK_Escape, flags: [], repeating: false) == .cancel)
    }

    @Test(arguments: [kVK_Return, kVK_ANSI_KeypadEnter]) func returnCopies(_ code: Int) {
        #expect(ShotKeyCommand(keyCode: code, flags: .numericPad, repeating: false) == .copy)
    }

    @Test func commandSUsesThePhysicalKeyWithCapsLock() {
        #expect(ShotKeyCommand(keyCode: kVK_ANSI_S, flags: [.command, .capsLock], repeating: false) == .save)
    }

    @Test func commandZUsesThePhysicalKeyForUndo() {
        #expect(ShotKeyCommand(keyCode: kVK_ANSI_Z, flags: .command, repeating: false) == .undo)
    }

    @Test func addingShiftToCommandZRedoes() {
        #expect(ShotKeyCommand(keyCode: kVK_ANSI_Z, flags: [.command, .shift], repeating: false) == .redo)
    }

    @Test func ordinaryTypingIsLeftToAppKit() {
        #expect(ShotKeyCommand(keyCode: kVK_ANSI_S, flags: [], repeating: false) == nil)
    }

    @Test func otherModifierCombinationsAreLeftToAppKit() {
        #expect(ShotKeyCommand(keyCode: kVK_ANSI_S, flags: [.command, .option], repeating: false) == nil)
    }

    @Test func holdingReturnDoesNotRepeatCopy() {
        #expect(ShotKeyCommand(keyCode: kVK_Return, flags: [], repeating: true) == nil)
    }
}
