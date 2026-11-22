import AppKit

final class QuickShotBackdrop: NSView {
    static let accent = NSColor(srgbRed: 0, green: 119 / 255, blue: 246 / 255, alpha: 1)
    private let image: CGImage
    private let fixed: Bool
    var selection: CGRect? { didSet { needsDisplay = true } }

    init(image: CGImage, frame: CGRect, fixed: Bool) {
        self.image = image
        self.fixed = fixed
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { !fixed }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: bounds)
        context.restoreGState()

        guard !fixed else { return }
        let shade = NSBezierPath(rect: bounds)
        if let selection { shade.appendRect(selection) }
        shade.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.6).setFill()
        shade.fill()
        if let selection { drawOutline(selection) }
    }

    private func drawOutline(_ frame: CGRect) {
        Self.accent.setStroke()
        let outline = NSBezierPath(rect: frame)
        outline.lineWidth = 1
        outline.stroke()

        let corners = NSBezierPath()
        let dx = min(ShotSelection.handleLength, frame.width / 2)
        let dy = min(ShotSelection.handleLength, frame.height / 2)
        for (x, directionX) in [(frame.minX, 1.0), (frame.maxX, -1.0)] {
            for (y, directionY) in [(frame.minY, 1.0), (frame.maxY, -1.0)] {
                corners.move(to: CGPoint(x: x, y: y + dy * directionY))
                corners.line(to: CGPoint(x: x, y: y))
                corners.line(to: CGPoint(x: x + dx * directionX, y: y))
            }
        }
        corners.lineWidth = 4
        corners.stroke()
    }
}
