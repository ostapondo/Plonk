import AppKit
import Carbon.HIToolbox
import Testing
@testable import plonk

struct ShotKeyCommandTests {
    private func command(_ code: Int, _ characters: String?, _ flags: NSEvent.ModifierFlags,
                         repeating: Bool = false) -> ShotKeyCommand? {
        ShotKeyCommand(keyCode: code, characters: characters, flags: flags, repeating: repeating)
    }

    @Test func escapeCancels() {
        #expect(command(kVK_Escape, "\u{1B}", []) == .cancel)
    }

    @Test(arguments: [kVK_Return, kVK_ANSI_KeypadEnter]) func returnCopies(_ code: Int) {
        #expect(command(code, "\r", .numericPad) == .copy)
    }

    @Test func commandSSavesWithCapsLock() {
        #expect(command(kVK_ANSI_S, "s", [.command, .capsLock]) == .save)
    }

    @Test func commandZUndoes() {
        #expect(command(kVK_ANSI_Z, "z", .command) == .undo)
    }

    @Test func addingShiftToCommandZRedoes() {
        #expect(command(kVK_ANSI_Z, "Z", [.command, .shift]) == .redo)
    }

    @Test func withoutCharactersTheKeyPositionDecides() {
        #expect(command(kVK_ANSI_S, nil, .command) == .save)
        #expect(command(kVK_ANSI_Z, "", [.command, .shift]) == .redo)
    }

    @Test func azertyUndoFollowsTheLetterZ() {
        #expect(command(kVK_ANSI_W, "z", .command) == .undo)
        #expect(command(kVK_ANSI_Z, "w", .command) == nil)
    }

    @Test func dvorakSaveFollowsTheLetterS() {
        #expect(command(kVK_ANSI_Semicolon, "s", .command) == .save)
        #expect(command(kVK_ANSI_S, "o", .command) == nil)
    }

    @Test func selectDisplayFollowsTheLetterF() {
        #expect(command(kVK_ANSI_Y, "f", []) == .selectDisplay)
        #expect(command(kVK_ANSI_F, "u", []) == nil)
        #expect(command(kVK_ANSI_F, nil, []) == .selectDisplay)
        #expect(command(kVK_ANSI_Y, "f", .shift) == nil)
    }

    @Test func nonLatinLayoutFallsBackToTheKeyPosition() {
        #expect(command(kVK_ANSI_Z, "я", .command) == .undo)
        #expect(command(kVK_ANSI_Z, "Я", [.command, .shift]) == .redo)
        #expect(command(kVK_ANSI_S, "і", .command) == .save)
    }

    @Test func ordinaryTypingIsLeftToAppKit() {
        #expect(command(kVK_ANSI_S, "s", []) == nil)
    }

    @Test func otherModifierCombinationsAreLeftToAppKit() {
        #expect(command(kVK_ANSI_S, "s", [.command, .option]) == nil)
    }

    @Test func holdingReturnDoesNotRepeatCopy() {
        #expect(command(kVK_Return, "\r", [], repeating: true) == nil)
    }

    @Test func holdingCommandZDoesNotRepeatUndo() {
        #expect(command(kVK_ANSI_Z, "z", .command, repeating: true) == nil)
    }
}
