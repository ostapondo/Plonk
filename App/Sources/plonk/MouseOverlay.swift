import AppKit

// The window the mouse tools draw in: one borderless, click-through panel
// spanning every display, redrawn by a single layer-backed view.
//
// One window rather than one per screen, because a spotlight has to dim the
// whole desk at once and a crosshair has to cross all of it.

final class MouseOverlay {
    enum Mode: Equatable {
        /// Dim everything but a circle of this radius round the pointer.
        case spotlight(radius: CGFloat)
        case crosshairs
    }

    private var window: NSPanel?
    private let view = MouseOverlayView()
    private var pulseToken = 0

    var isSpotlighting: Bool {
        guard window?.isVisible == true, case .spotlight = view.mode else { return false }
        return true
    }

    func show(_ mode: Mode, at point: NSPoint, tint: NSColor) {
        let panel = window ?? makePanel()
        window = panel
        panel.setFrame(Self.desktopFrame(), display: false)
        view.frame = panel.contentLayoutRect
        let previous = view.mode == mode ? view.point : nil
        view.mode = mode
        view.point = point
        view.tint = tint
        view.pulse = nil
        // Crosshairs move with the pointer, so redrawing the whole desk on
        // every sample would be several megapixels a frame. Only the lines
        // that left and the ones that arrived are dirty.
        if case .crosshairs = mode, let previous {
            view.invalidateCrosshairs(at: previous)
            view.invalidateCrosshairs(at: point)
        } else {
            view.needsDisplay = true
        }
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    /// A ring that grows and fades where a click landed. Leaves whatever was
    /// on screen before it alone.
    func pulse(at point: NSPoint, radius: CGFloat, tint: NSColor) {
        let panel = window ?? makePanel()
        window = panel
        panel.setFrame(Self.desktopFrame(), display: false)
        view.frame = panel.contentLayoutRect
        view.tint = tint
        view.pulse = MouseOverlayView.Pulse(point: point, radius: radius, opacity: 1)
        view.needsDisplay = true
        if !panel.isVisible { panel.orderFrontRegardless() }

        pulseToken += 1
        let generation = pulseToken
        animatePulse(generation: generation, step: 0, radius: radius)
    }

    private func animatePulse(generation: Int, step: Int, radius: CGFloat) {
        let steps = 12
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            self?.animatePulse(generation: generation, step: step + 1, radius: radius)
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
    }

    var mode: MouseOverlay.Mode?
    var point: NSPoint = .zero
    var tint: NSColor = .controlAccentColor
    var pulse: Pulse?

    override var isFlipped: Bool { false }

    /// Marks only the two bands a crosshair at this point occupies.
    func invalidateCrosshairs(at point: NSPoint) {
        let origin = window?.frame.origin ?? .zero
        let centre = NSPoint(x: point.x - origin.x, y: point.y - origin.y)
        let thickness: CGFloat = 4
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
        case .spotlight(let radius):
            let centre = local(point)
            context.setFillColor(NSColor.black.withAlphaComponent(0.55).cgColor)
            context.fill(bounds)
            // Punch the circle out rather than drawing over it, so what is
            // underneath stays exactly as bright as it was.
            context.setBlendMode(.clear)
            context.fillEllipse(in: CGRect(x: centre.x - radius, y: centre.y - radius,
                                           width: radius * 2, height: radius * 2))
            context.setBlendMode(.normal)
            context.setStrokeColor(tint.withAlphaComponent(0.9).cgColor)
            context.setLineWidth(3)
            context.strokeEllipse(in: CGRect(x: centre.x - radius, y: centre.y - radius,
                                             width: radius * 2, height: radius * 2))
        case .crosshairs:
            let centre = local(point)
            context.setStrokeColor(tint.withAlphaComponent(0.7).cgColor)
            context.setLineWidth(1.5)
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
            context.setStrokeColor(tint.withAlphaComponent(pulse.opacity).cgColor)
            context.setLineWidth(3)
            context.strokeEllipse(in: CGRect(x: centre.x - pulse.radius, y: centre.y - pulse.radius,
                                             width: pulse.radius * 2, height: pulse.radius * 2))
        }
    }
}
