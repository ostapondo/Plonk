import AppKit

// What the ruler draws while it is up: how far the pointer can go each way
// before it meets an edge, or the line being dragged, with the numbers.
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

    /// Taken down and put back without losing the session, so the ruler can
    /// photograph the screen again without photographing itself.
    func setVisible(_ visible: Bool) {
        windows.forEach { visible ? $0.orderFrontRegardless() : $0.orderOut(nil) }
        if visible { windows.first?.makeKey() }
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
        case .spans:
            drawSpans(measurement, in: context)
        case .line:
            if let anchor { draw(line: local(anchor), to: local(pointer), in: context) }
            drawLabel(measurement.label, near: local(pointer))
        }
    }

    /// Two dimension lines crossing at the pointer, each ending where its scan
    /// stopped, each carrying its own number.
    ///
    /// Not a rectangle: the run across and the run down are separate answers
    /// and often belong to different things — the width of a row and the height
    /// of the gap it sits in. A box drawn round them would claim they are the
    /// sides of one object, which is the one thing the pixels cannot say.
    private func drawSpans(_ measurement: RulerMeasurement, in context: CGContext) {
        let span = local(measurement.rect)
        let centre = local(pointer)
        context.setStrokeColor(tint.cgColor)
        context.setLineWidth(1.5)

        draw(dimension: CGPoint(x: span.minX, y: centre.y),
             to: CGPoint(x: span.maxX, y: centre.y), in: context)
        draw(dimension: CGPoint(x: centre.x, y: span.minY),
             to: CGPoint(x: centre.x, y: span.maxY), in: context)
        drawSamplePoint(at: centre, in: context)

        // Above the horizontal line and right of the vertical one, so neither
        // label sits on top of what it is measuring. When both runs are short
        // the two land on each other, and the second one moves out of the way.
        let horizontal = labelFrame(measurement.horizontalLabel,
                                    centredAt: CGPoint(x: span.midX, y: centre.y + 24))
        let verticalSize = labelSize(measurement.verticalLabel)
        var vertical = labelFrame(measurement.verticalLabel,
                                  centredAt: CGPoint(x: centre.x + 26 + verticalSize.width / 2,
                                                     y: span.midY))
        if vertical.intersects(horizontal.insetBy(dx: -6, dy: -6)) {
            vertical.origin.y = horizontal.minY - vertical.height - 6
        }
        drawLabel(measurement.horizontalLabel, in: horizontal)
        drawLabel(measurement.verticalLabel, in: vertical)
    }

    /// The pixel every one of these numbers was measured from. Without it a
    /// short pair of runs is two ticks and a badge, and nothing says where the
    /// ruler was actually looking.
    private func drawSamplePoint(at centre: NSPoint, in context: CGContext) {
        context.setLineWidth(1)
        context.setStrokeColor(NSColor.white.cgColor)
        for (dx, dy) in [(1.0, 0.0), (0.0, 1.0)] {
            // A gap in the middle, so the pixel being sampled is not painted
            // over by the thing pointing at it.
            for direction in [-1.0, 1.0] {
                let inner = CGPoint(x: centre.x + dx * 3 * direction, y: centre.y + dy * 3 * direction)
                context.move(to: inner)
                context.addLine(to: CGPoint(x: centre.x + dx * 9 * direction,
                                            y: centre.y + dy * 9 * direction))
            }
        }
        context.strokePath()
    }

    /// A line with a tick across each end, the way a drawing marks a length.
    private func draw(dimension from: CGPoint, to: CGPoint, in context: CGContext) {
        context.move(to: from)
        context.addLine(to: to)
        let tick: CGFloat = 5
        let across = from.y == to.y
        for end in [from, to] {
            context.move(to: CGPoint(x: end.x - (across ? 0 : tick), y: end.y - (across ? tick : 0)))
            context.addLine(to: CGPoint(x: end.x + (across ? 0 : tick), y: end.y + (across ? tick : 0)))
        }
        context.strokePath()
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

    /// Centred on a point rather than offset from the pointer, for the numbers
    /// that belong to a line rather than to the cursor.
    private func labelFrame(_ text: String, centredAt point: NSPoint) -> NSRect {
        let size = labelSize(text)
        return NSRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                      width: size.width, height: size.height)
    }

    private func drawLabel(_ text: String, near point: NSPoint) {
        let size = labelSize(text)
        // Below and right of the pointer, unless that would put it off the
        // screen, in which case it goes to the other side of the cursor.
        var origin = NSPoint(x: point.x + 16, y: point.y - size.height - 16)
        if origin.x + size.width > bounds.maxX { origin.x = point.x - size.width - 16 }
        if origin.y < bounds.minY { origin.y = point.y + 16 }
        drawLabel(text, in: NSRect(origin: origin, size: size))
    }

    private static let labelAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
        .foregroundColor: NSColor.white,
    ]
    private static let labelPadding: CGFloat = 6

    /// A label can be three lines, so it is measured and drawn with the
    /// rect-taking calls; the point-taking ones are single-line only and would
    /// run the second line off the side of the first.
    private func labelSize(_ text: String) -> NSSize {
        let bounding = NSAttributedString(string: text, attributes: Self.labelAttributes)
            .boundingRect(with: NSSize(width: 400, height: 200), options: [.usesLineFragmentOrigin])
        return NSSize(width: bounding.width.rounded(.up) + Self.labelPadding * 2,
                      height: bounding.height.rounded(.up) + Self.labelPadding * 2)
    }

    private func drawLabel(_ text: String, in frame: NSRect) {
        // Nudged back inside rather than clipped: a number half off the edge of
        // the screen is worse than one that has moved a little.
        var frame = frame
        frame.origin.x = min(max(frame.minX, bounds.minX + 4), bounds.maxX - frame.width - 4)
        frame.origin.y = min(max(frame.minY, bounds.minY + 4), bounds.maxY - frame.height - 4)

        let background = NSBezierPath(roundedRect: frame, xRadius: 6, yRadius: 6)
        NSColor.black.withAlphaComponent(0.8).setFill()
        background.fill()
        tint.withAlphaComponent(0.8).setStroke()
        background.lineWidth = 1
        background.stroke()
        NSAttributedString(string: text, attributes: Self.labelAttributes)
            .draw(with: frame.insetBy(dx: Self.labelPadding, dy: Self.labelPadding),
                  options: [.usesLineFragmentOrigin])
    }
}
