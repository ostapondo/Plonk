import SwiftUI

struct ShotEditorDragInput: NSViewRepresentable {
    let onDrag: (_ start: CGPoint, _ point: CGPoint, _ shift: Bool) -> Void
    let onEnd: (_ point: CGPoint, _ shift: Bool) -> Void
    let onShiftChange: (Bool) -> Void

    func makeNSView(context: Context) -> InputView { InputView(self) }

    func updateNSView(_ view: InputView, context: Context) { view.input = self }

    final class InputView: NSView {
        var input: ShotEditorDragInput
        private var start: CGPoint?
        private var dragging = false

        init(_ input: ShotEditorDragInput) {
            self.input = input
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }
        override var isFlipped: Bool { true }
        override var acceptsFirstResponder: Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
            start = convert(event.locationInWindow, from: nil)
        }

        override func mouseDragged(with event: NSEvent) {
            guard let start else { return }
            let point = convert(event.locationInWindow, from: nil)
            guard dragging || hypot(point.x - start.x, point.y - start.y) >= 1 else { return }
            dragging = true
            input.onDrag(start, point, event.modifierFlags.contains(.shift))
        }

        override func mouseUp(with event: NSEvent) {
            start = nil
            guard dragging else { return }
            dragging = false
            input.onEnd(convert(event.locationInWindow, from: nil), event.modifierFlags.contains(.shift))
        }

        override func flagsChanged(with event: NSEvent) {
            if dragging { input.onShiftChange(event.modifierFlags.contains(.shift)) }
            super.flagsChanged(with: event)
        }
    }
}
