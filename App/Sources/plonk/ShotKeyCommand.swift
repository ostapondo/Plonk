import AppKit
import Carbon.HIToolbox

enum ShotKeyCommand: Equatable {
    case cancel
    case copy
    case save
    case undo
    case redo

    init?(keyCode: Int, flags: NSEvent.ModifierFlags, repeating: Bool) {
        guard !repeating else { return nil }
        let modifiers = flags.intersection([.command, .shift, .option, .control])
        switch (keyCode, modifiers) {
        case (kVK_Escape, []): self = .cancel
        case (kVK_Return, []), (kVK_ANSI_KeypadEnter, []): self = .copy
        case (kVK_ANSI_S, .command): self = .save
        case (kVK_ANSI_Z, .command): self = .undo
        case (kVK_ANSI_Z, [.command, .shift]): self = .redo
        default: return nil
        }
    }
}
