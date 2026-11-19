import AppKit

final class ShotTextEntry: NSTextView {
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?

    override func doCommand(by selector: Selector) {
        guard !hasMarkedText() else { return super.doCommand(by: selector) }
        switch selector {
        case #selector(insertNewline(_:)), #selector(insertLineBreak(_:)),
             #selector(insertNewlineIgnoringFieldEditor(_:)):
            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                insertNewline(nil)
            } else {
                onCommit?()
            }
        case #selector(cancelOperation(_:)):
            onCancel?()
        default:
            super.doCommand(by: selector)
        }
    }
}
