import AppKit
import Carbon.HIToolbox

final class QuickShotCanvas: NSView {
    private let bitmap: ShotBitmap
    private var selection: CGRect?
    private var start: CGPoint?
    private let editor = NSButton(title: String(localized: .shotAfterEditor), target: nil, action: nil)
    var onCancel: (() -> Void)?
    var onSelect: (() -> Void)?
    var onEditor: ((NSImage) -> Void)?

    init(bitmap: ShotBitmap) {
        self.bitmap = bitmap
        super.init(frame: CGRect(origin: .zero, size: bitmap.displaySize))
        editor.target = self
        editor.action = #selector(openEditor)
        editor.sizeToFit()
        editor.isHidden = true
        addSubview(editor)
    }

    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    private var geometry: ShotSelection { ShotSelection(pixels: bitmap.size, view: bounds.size) }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(bitmap.image, in: bounds)
        context.restoreGState()

        let shade = NSBezierPath(rect: bounds)
        if let selection { shade.appendRect(geometry.viewRect(selection)) }
        shade.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.6).setFill()
        shade.fill()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onSelect?()
        clearSelection()
        start = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start else { return }
        selection = geometry.selection(from: start, to: convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        mouseDragged(with: event)
        start = nil
        guard let selection else { return }
        let rect = geometry.viewRect(selection)
        editor.setFrameOrigin(CGPoint(x: rect.minX.clamped(to: 0...max(0, bounds.width - editor.frame.width)),
                                     y: min(rect.maxY + 10, bounds.height - editor.frame.height)))
        editor.isHidden = false
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == kVK_Escape {
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }

    func clearSelection() {
        start = nil
        selection = nil
        editor.isHidden = true
        needsDisplay = true
    }

    @objc private func openEditor() {
        guard let selection, let image = bitmap.crop(selection) else { return }
        onEditor?(image)
    }
}
