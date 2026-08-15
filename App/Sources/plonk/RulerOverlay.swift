import AppKit

// What the ruler draws while it is up: the box the pixels found, or the line
// being dragged, and the numbers for whichever it is.
//
// One transparent window per screen, at the level RegionPicker uses, and
// nothing dimmed: the whole point is to look at what is underneath while it is
// being measured. Every window draws the same measurement and only the one it
// falls on shows anything, which is what makes a line dragged across two
// monitors come out whole.

final class RulerOverlay {
    private var windows: [RulerWindow] = []
    private let tint: NSColor

    init(tint: NSColor) {
        self.tint = tint
    }

    func show() {
        for screen in NSScreen.screens {
            let window = RulerWindow(screen: screen, tint: tint)
            window.orderFrontRegardless()
            windows.append(window)
        }
        // Key, so Escape is delivered to the app rather than to whatever was in
        // front before the ruler covered it.
        windows.first?.makeKey()
    }

    func update(measurement: RulerMeasurement?, pointer: NSPoint, anchor: NSPoint?) {
        for window in windows {
            window.view.measurement = measurement
            window.view.pointer = pointer
            window.view.anchor = anchor
            window.view.needsDisplay = true
        }
    }

    func hide() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }
}

private final class RulerWindow: NSWindow {
    let view: RulerView

    init(screen: NSScreen, tint: NSColor) {
        view = RulerView(tint: tint)
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        hasShadow = false
        isReleasedWhenClosed = false
        // Mouse-moved events are only generated for a window that asks for
        // them, and the app's event monitor sees nothing without that.
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = view
    }

    override var canBecomeKey: Bool { true }
}

private final class RulerView: NSView {
    var measurement: RulerMeasurement?
    var pointer: NSPoint = .zero
    var anchor: NSPoint?
    private let tint: NSColor

    init(tint: NSColor) {
        self.tint = tint
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not from a nib") }

    override var isFlipped: Bool { false }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    /// Screen coordinates to this view's own, the way MouseOverlayView does it:
    /// the window spans one display and the points arrive global.
    private func local(_ point: NSPoint) -> NSPoint {
        let origin = window?.frame.origin ?? .zero
        return NSPoint(x: point.x - origin.x, y: point.y - origin.y)
    }

    /// A measured rect is in CG space; the view is not.
    private func local(_ rect: CGRect) -> NSRect {
        let primaryMaxY = NSScreen.screens.first?.frame.maxY ?? 0
        let flipped = NSPoint(x: rect.minX, y: primaryMaxY - rect.maxY)
        let origin = local(flipped)
        return NSRect(origin: origin, size: NSSize(width: rect.width, height: rect.height))
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext, let measurement else { return }
        switch measurement.kind {
        case .bounds:
            draw(box: local(measurement.rect), in: context)
        case .line:
            if let anchor { draw(line: local(anchor), to: local(pointer), in: context) }
        }
        drawLabel(measurement.label, near: local(pointer))
    }

    private func draw(box: NSRect, in context: CGContext) {
        context.setFillColor(tint.withAlphaComponent(0.14).cgColor)
        context.fill(box)
        context.setStrokeColor(tint.cgColor)
        context.setLineWidth(1.5)
        context.stroke(box.insetBy(dx: 0.75, dy: 0.75))
    }

    private func draw(line from: NSPoint, to: NSPoint, in context: CGContext) {
        // The two sides of the triangle, faint: a distance across the screen is
        // easier to trust when its horizontal and vertical parts are visible.
        context.setStrokeColor(tint.withAlphaComponent(0.45).cgColor)
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [4, 4])
        context.move(to: from)
        context.addLine(to: CGPoint(x: to.x, y: from.y))
        context.addLine(to: to)
        context.strokePath()

        context.setLineDash(phase: 0, lengths: [])
        context.setStrokeColor(tint.cgColor)
        context.setLineWidth(1.5)
        context.move(to: from)
        context.addLine(to: to)
        context.strokePath()
        for end in [from, to] {
            context.strokeEllipse(in: CGRect(x: end.x - 3, y: end.y - 3, width: 6, height: 6))
        }
    }

    private func drawLabel(_ text: String, near point: NSPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        // The label is two or three lines, so it is measured and drawn with the
        // rect-taking calls; the point-taking ones are single-line only and
        // would run the second line off the side of the first.
        let string = NSAttributedString(string: text, attributes: attributes)
        let bounding = string.boundingRect(with: NSSize(width: 400, height: 200),
                                           options: [.usesLineFragmentOrigin])
        let padding: CGFloat = 6
        let box = NSSize(width: bounding.width.rounded(.up) + padding * 2,
                         height: bounding.height.rounded(.up) + padding * 2)

        // Below and right of the pointer, unless that would put it off the
        // screen, in which case it goes to the other side of the cursor.
        var origin = NSPoint(x: point.x + 16, y: point.y - box.height - 16)
        if origin.x + box.width > bounds.maxX { origin.x = point.x - box.width - 16 }
        if origin.y < bounds.minY { origin.y = point.y + 16 }
        let frame = NSRect(origin: origin, size: box)

        let background = NSBezierPath(roundedRect: frame, xRadius: 6, yRadius: 6)
        NSColor.black.withAlphaComponent(0.8).setFill()
        background.fill()
        tint.withAlphaComponent(0.8).setStroke()
        background.lineWidth = 1
        background.stroke()
        string.draw(with: frame.insetBy(dx: padding, dy: padding), options: [.usesLineFragmentOrigin])
    }
}
