import AppKit
import Carbon.HIToolbox

enum ShotKeyCommand: Equatable {
    case cancel
    case copy
    case save
    case undo
    case redo
    case selectDisplay
    case copyColor
    case zoomMagnifier(increasing: Bool)

    /// `characters` is the event's `charactersIgnoringModifiers`. On a Latin layout the
    /// typed letter decides, as macOS menus do. Other layouts use the US key position
    /// for letter shortcuts.
    init?(keyCode: Int, characters: String?, flags: NSEvent.ModifierFlags, repeating: Bool) {
        guard !repeating else { return nil }
        let modifiers = flags.intersection([.command, .shift, .option, .control])
        switch (keyCode, modifiers) {
        case (kVK_Escape, []): self = .cancel
        case (kVK_Return, []), (kVK_ANSI_KeypadEnter, []): self = .copy
        default:
            switch (characters, modifiers) {
            case ("+", []), ("+", .shift), ("=", []), ("=", .shift):
                self = .zoomMagnifier(increasing: true)
                return
            case ("-", []):
                self = .zoomMagnifier(increasing: false)
                return
            default: break
            }
            switch (Self.letter(keyCode: keyCode, characters: characters), modifiers) {
            case ("s", .command): self = .save
            case ("z", .command): self = .undo
            case ("z", [.command, .shift]): self = .redo
            case ("f", []): self = .selectDisplay
            case ("c", []): self = .copyColor
            default: return nil
            }
        }
    }

    private static func letter(keyCode: Int, characters: String?) -> Character? {
        if let typed = characters?.lowercased(), typed.count == 1, let char = typed.first,
           char.isASCII, char.isLetter {
            return char
        }
        switch keyCode {
        case kVK_ANSI_C: return "c"
        case kVK_ANSI_F: return "f"
        case kVK_ANSI_S: return "s"
        case kVK_ANSI_Z: return "z"
        default: return nil
        }
    }
}
