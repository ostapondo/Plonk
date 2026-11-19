import AppKit
import Carbon.HIToolbox

enum ShotKeyCommand {
    case action(QuickShotAction)
    case select(Annotation.Kind)
    case undo
    case redo
    case cancel
    case tab(backward: Bool)

    init?(event: NSEvent, window: NSWindow, canvas: ShotMarkupCanvas) {
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let key = event.charactersIgnoringModifiers?.lowercased()
        if key == "s", flags == .command || flags == [.command, .shift] {
            self = .action(.save(forceCopy: flags.contains(.shift)))
            return
        }
        if event.keyCode == kVK_Escape, flags.isEmpty, !(window.firstResponder is NSTextView) {
            self = .cancel
            return
        }
        guard window.firstResponder === canvas else { return nil }
        if key == "z", flags == .command || flags == [.command, .shift] {
            self = flags.contains(.shift) ? .redo : .undo
            return
        }
        if event.keyCode == kVK_Tab, flags.isEmpty || flags == .shift {
            self = .tab(backward: flags.contains(.shift))
            return
        }
        guard flags.isEmpty else { return nil }
        switch Int(event.keyCode) {
        case kVK_Return, kVK_ANSI_KeypadEnter, kVK_Space:
            self = .action(.copy)
        default:
            switch key {
            case "1": self = .select(.rectangle)
            case "2": self = .select(.ellipse)
            case "4": self = .select(.arrow)
            case "5": self = .select(.pen)
            case "7": self = .select(.text)
            case "p": self = .action(.preview)
            case "o": self = .action(.recognizeText)
            case "w": self = .action(.editor)
            default: return nil
            }
        }
    }
}
