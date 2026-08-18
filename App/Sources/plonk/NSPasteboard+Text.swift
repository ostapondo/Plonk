import AppKit

extension NSPasteboard {
    /// Replace whatever is on the pasteboard with one string.
    func replaceContents(with text: String) {
        clearContents()
        setString(text, forType: .string)
    }
}
