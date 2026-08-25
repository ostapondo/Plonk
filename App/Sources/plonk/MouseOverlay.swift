import AppKit

// The window the mouse tools draw in: one borderless, click-through panel
// spanning every display, redrawn by a single layer-backed view.
//
// One window rather than one per screen, because a spotlight has to dim the
// whole desk at once and a crosshair has to cross all of it.

final class MouseOverlay {
    enum Mode: Equatable {
        /// Dim everything but a circle round the pointer.
        case spotlight
        case crosshairs
    }

    private var window: NSPanel?
    private let view = MouseOverlayView()
    private var pulseToken = 0

    var isSpotlighting: Bool {
        guard window?.isVisible == true, case .spotlight = view.mode else { return false }
        return true
    }

    func show(_ mode: Mode, at point: NSPoint, look: PointerAppearance) {
        let panel = preparedPanel()
        let previous = view.mode == mode ? view.point : nil
        view.mode = mode
        view.point = point
        view.look = look
        // Crosshairs move with the pointer, so redrawing the whole desk on
        // every sample would be several megapixels a frame. Only the lines
        // that left and the ones that arrived are dirty, unless a click ring
        // is animating on its own timer: it needs the whole view.
        if case .crosshairs = mode, let previous, view.pulse == nil {
            view.invalidateCrosshairs(at: previous)
            view.invalidateCrosshairs(at: point)
        } else {
            view.needsDisplay = true
        }
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    /// A ring that grows and fades where a click landed. Leaves whatever was
    /// on screen before it alone.
    ///
    /// The colour is taken now rather than read while it animates, so a right
    /// click keeps its own colour for the whole of its fade.
    func pulse(at point: NSPoint, right: Bool, look: PointerAppearance) {
        let panel = preparedPanel()
        view.look = look
        view.pulse = MouseOverlayView.Pulse(point: point, radius: look.clickRadius,
                                            opacity: 1, color: look.clickColor(right: right))
        view.needsDisplay = true
        if !panel.isVisible { panel.orderFrontRegardless() }

        pulseToken += 1
        let generation = pulseToken
        animatePulse(generation: generation, step: 0, radius: look.clickRadius,
                     interval: look.clickFade / Double(Self.pulseSteps))
    }

    /// Enough for the growth to read as motion at any fade length the settings
    /// allow; the interval is what the fade time changes.
    private static let pulseSteps = 12

    private func animatePulse(generation: Int, step: Int, radius: CGFloat, interval: TimeInterval) {
        let steps = Self.pulseSteps
        guard pulseToken == generation, step <= steps else {
            guard pulseToken == generation else { return }
            view.pulse = nil
            view.needsDisplay = true
            if view.mode == nil { window?.orderOut(nil) }
            return
        }
        let progress = CGFloat(step) / CGFloat(steps)
        view.pulse?.radius = radius * (0.5 + progress)
        view.pulse?.opacity = 1 - progress
        view.needsDisplay = true
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
            self?.animatePulse(generation: generation, step: step + 1,
                               radius: radius, interval: interval)
        }
    }

    var visibleWindows: [NSWindow] { [window].compactMap { $0 } }

    func hide() {
        view.mode = nil
        view.pulse = nil
        window?.orderOut(nil)
    }

    /// The union of every screen, in AppKit coordinates.
    private static func desktopFrame() -> NSRect {
        NSScreen.screens.reduce(NSRect.zero) { $0.isEmpty ? $1.frame : $0.union($1.frame) }
    }

    /// The panel, made on first use and stretched over every display, since
    /// screens can have come or gone since the last draw.
    private func preparedPanel() -> NSPanel {
        let panel = window ?? makePanel()
        window = panel
        panel.setFrame(Self.desktopFrame(), display: false)
        view.frame = panel.contentLayoutRect
        return panel
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: Self.desktopFrame(),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .screenSaver
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.contentView = view
        return panel
    }
}

final class MouseOverlayView: NSView {
    struct Pulse {
        var point: NSPoint
        var radius: CGFloat
        var opacity: CGFloat
        var color: NSColor
    }

    var mode: MouseOverlay.Mode?
    var point: NSPoint = .zero
    var look = PointerAppearance()
    var pulse: Pulse?

    override var isFlipped: Bool { false }

    /// Marks only the two bands a crosshair at this point occupies.
    func invalidateCrosshairs(at point: NSPoint) {
        let origin = window?.frame.origin ?? .zero
        let centre = NSPoint(x: point.x - origin.x, y: point.y - origin.y)
        // Wide enough for the line and the antialiasing either side of it,
        // whatever the line has been set to.
        let thickness = max(4, look.crosshairLineWidth * 2)
        setNeedsDisplay(NSRect(x: bounds.minX, y: centre.y - thickness,
                               width: bounds.width, height: thickness * 2))
        setNeedsDisplay(NSRect(x: centre.x - thickness, y: bounds.minY,
                               width: thickness * 2, height: bounds.height))
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        // The view spans every screen, so a point in screen coordinates has to
        // come back to the view's own origin before anything is drawn.
        let origin = window?.frame.origin ?? .zero
        let local = { (p: NSPoint) in NSPoint(x: p.x - origin.x, y: p.y - origin.y) }

        switch mode {
        case .spotlight:
            let centre = local(point)
            let radius = look.spotlightRadius
            context.setFillColor(NSColor.black.withAlphaComponent(look.spotlightDim).cgColor)
            context.fill(bounds)
            // Punch the circle out rather than drawing over it, so what is
            // underneath stays exactly as bright as it was.
            context.setBlendMode(.clear)
            context.fillEllipse(in: CGRect(x: centre.x - radius, y: centre.y - radius,
                                           width: radius * 2, height: radius * 2))
            context.setBlendMode(.normal)
            context.setStrokeColor(look.tint.withAlphaComponent(0.9).cgColor)
            context.setLineWidth(3)
            context.strokeEllipse(in: CGRect(x: centre.x - radius, y: centre.y - radius,
                                             width: radius * 2, height: radius * 2))
        case .crosshairs:
            let centre = local(point)
            context.setStrokeColor(look.crosshair.withAlphaComponent(look.crosshairOpacity).cgColor)
            context.setLineWidth(look.crosshairLineWidth)
            context.move(to: CGPoint(x: bounds.minX, y: centre.y))
            context.addLine(to: CGPoint(x: bounds.maxX, y: centre.y))
            context.move(to: CGPoint(x: centre.x, y: bounds.minY))
            context.addLine(to: CGPoint(x: centre.x, y: bounds.maxY))
            context.strokePath()
        case nil:
            break
        }

        if let pulse {
            let centre = local(pulse.point)
            let box = CGRect(x: centre.x - pulse.radius, y: centre.y - pulse.radius,
                             width: pulse.radius * 2, height: pulse.radius * 2)
            if look.clickStyle != .ring {
                // A dot on its own carries the colour; under a ring it is a
                // wash, or the outline would be lost inside it.
                let fill = look.clickStyle == .both ? 0.3 : 0.75
                context.setFillColor(pulse.color.withAlphaComponent(pulse.opacity * fill).cgColor)
                context.fillEllipse(in: box)
            }
            if look.clickStyle != .dot {
                context.setStrokeColor(pulse.color.withAlphaComponent(pulse.opacity).cgColor)
                context.setLineWidth(look.clickLineWidth)
                context.strokeEllipse(in: box)
            }
        }
    }
}
