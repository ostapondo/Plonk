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

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField, let editor = field.currentEditor() else { return }
            let draft = String(editor.string.prefix(4))
            if editor.string != draft {
                editor.string = draft
                editor.selectedRange = NSRange(location: draft.utf16.count, length: 0)
            }
            input.invalid = false
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
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
            guard let field = control as? NSTextField else { return false }
            switch command {
            case #selector(NSResponder.insertNewline(_:)):
                if let value = validWidth(textView.string) {
                    commit(value, field: field)
                } else {
                    replaceDraft(with: input.width, in: field)
                    textView.selectAll(nil)
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
            if let editor = field.currentEditor() {
                if editor.string != draft {
                    editor.string = draft
                    editor.selectedRange = NSRange(location: draft.utf16.count, length: 0)
                }
            } else {
                field.stringValue = draft
            }
        }
    }
}
