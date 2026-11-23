import SwiftUI

struct AnnotationWidthField: NSViewRepresentable {
    let kind: Annotation.Kind
    @Binding var width: Int
    @Binding var invalid: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: String(width))
        field.delegate = context.coordinator
        field.alignment = .right
        field.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        field.usesSingleLineMode = true
        field.setAccessibilityLabel(String(localized: .shotEditorWidth))
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.input = self
        if field.currentEditor() == nil, field.stringValue != String(width) {
            field.stringValue = String(width)
        }
        field.toolTip = invalid ? String(localized: rangeMessage) : nil
    }

    var rangeMessage: LocalizedStringResource {
        .annotationWidthRange(kind.widthRange.lowerBound, kind.widthRange.upperBound)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var input: AnnotationWidthField
        init(_ input: AnnotationWidthField) { self.input = input }

        private var accepted = ""

        // Posted with the first keystroke already in the editor, so the text before it is the
        // saved width the field was showing.
        func controlTextDidBeginEditing(_ notification: Notification) {
            accepted = String(input.width)
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField,
                  let editor = field.currentEditor() as? NSTextView, !editor.hasMarkedText() else { return }
            let typed = editor.string
            let normalized = AnnotationStyle.normalizeWidthDraft(typed)
            if normalized != nil { input.invalid = false }
            let draft = normalized ?? accepted
            accepted = draft
            guard typed != draft else { return }
            // The caret stays where it was relative to the text after it, not at the end.
            let after = typed.utf16.count - NSMaxRange(editor.selectedRange())
            replace(in: editor, with: draft, caret: max(0, draft.utf16.count - after))
        }

        /// Through shouldChangeText, so the field editor's undo stack stays in step with the
        /// text; setting `string` directly leaves it holding edits that no longer exist.
        private func replace(in editor: NSTextView, with draft: String, caret: Int) {
            let whole = NSRange(location: 0, length: editor.string.utf16.count)
            guard editor.shouldChangeText(in: whole, replacementString: draft) else { return }
            editor.textStorage?.replaceCharacters(in: whole, with: draft)
            editor.didChangeText()
            editor.setSelectedRange(NSRange(location: caret, length: 0))
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            // Return already put the saved width back and raised the error; leaving the field
            // without typing again must not clear it, or the entry looks accepted.
            if input.invalid {
                field.stringValue = String(input.width)
                return
            }
            if let value = validWidth(field.stringValue) {
                field.stringValue = String(value)
                save(value)
            } else {
                field.stringValue = String(input.width)
                HUD.shared.show(input.rangeMessage)
            }
            input.invalid = false
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy command: Selector) -> Bool {
            guard let field = control as? NSTextField, !textView.hasMarkedText() else { return false }
            switch command {
            case #selector(NSResponder.insertNewline(_:)):
                if let value = validWidth(textView.string) {
                    commit(value, field: field)
                } else {
                    replaceDraft(with: input.width, in: field)
                    textView.selectAll(nil)
                    accepted = textView.string
                    input.invalid = true
                }
            case #selector(NSResponder.cancelOperation(_:)):
                replaceDraft(with: input.width, in: field)
                input.invalid = false
            case #selector(NSResponder.moveUp(_:)), #selector(NSResponder.moveUpAndModifySelection(_:)):
                step(1, in: field, from: textView.string)
            case #selector(NSResponder.moveDown(_:)), #selector(NSResponder.moveDownAndModifySelection(_:)):
                step(-1, in: field, from: textView.string)
            default:
                return false
            }
            return true
        }

        private func step(_ direction: Int, in field: NSTextField, from text: String) {
            let current = AnnotationStyle.parseWidth(text) ?? input.width
            let amount = NSApp.currentEvent?.modifierFlags.contains(.shift) == true ? 10 : 1
            let next = (current + direction * amount).clamped(to: input.kind.widthRange)
            commit(next, field: field)
        }

        private func validWidth(_ text: String) -> Int? {
            guard let value = AnnotationStyle.parseWidth(text), input.kind.widthRange.contains(value) else {
                return nil
            }
            return value
        }

        private func save(_ value: Int) {
            if value != input.width { input.width = value }
        }

        private func commit(_ value: Int, field: NSTextField) {
            replaceDraft(with: value, in: field)
            input.invalid = false
            save(value)
        }

        private func replaceDraft(with value: Int, in field: NSTextField) {
            let draft = String(value)
            accepted = draft
            if let editor = field.currentEditor() as? NSTextView {
                if editor.string != draft { replace(in: editor, with: draft, caret: draft.utf16.count) }
            } else {
                field.stringValue = draft
            }
        }
    }
}
