import AppKit

final class ShotEditorCanvas: ShotMarkupCanvas {
    let image: NSImage

    init(image: NSImage, history: AnnotationHistory) {
        self.image = image
        super.init(frame: .zero, history: history)
        tool = .arrow
    }

    required init?(coder: NSCoder) { nil }

    override var imageRect: CGRect {
        guard bounds.width > 24, bounds.height > 24 else { return .zero }
        return ImageFit.rect(for: image.size, in: bounds.insetBy(dx: 12, dy: 12).size).offsetBy(dx: 12, dy: 12)
    }

    override func mouseDown(with event: NSEvent) {
        guard commitText() else { return }
        window?.makeFirstResponder(self)
        beginMark(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseDragged(with event: NSEvent) {
        dragMark(to: convert(event.locationInWindow, from: nil))
    }

    override func mouseUp(with event: NSEvent) {
        endMark(at: convert(event.locationInWindow, from: nil))
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill()
        dirtyRect.fill()
        image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1,
                   respectFlipped: true, hints: nil)
    }
}
