import AppKit

// Menu bar glyph: an isometric Rubik's cube. Two variants — a monochrome
// template for the idle state, and a warm one lit from behind (sun glow) for
// the keep-awake state, which must keep its color, so it is not a template.
enum StatusIcon {

    static let idle: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            drawCube(faceColors: [
                NSColor.black.withAlphaComponent(0.5),
                NSColor.black.withAlphaComponent(1.0),
                NSColor.black.withAlphaComponent(0.8),
            ], stickerColor: .black, outlineColor: .black, punchOut: true)
            return true
        }
        image.isTemplate = true
        return image
    }()

    static let awake: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            drawGlow()
            drawCube(faceColors: [
                NSColor(calibratedRed: 1.0, green: 0.86, blue: 0.30, alpha: 1),
                NSColor(calibratedRed: 0.95, green: 0.45, blue: 0.10, alpha: 1),
                NSColor(calibratedRed: 0.99, green: 0.66, blue: 0.16, alpha: 1),
            ], stickerColor: NSColor(calibratedRed: 0.35, green: 0.14, blue: 0.0, alpha: 0.55),
               outlineColor: NSColor(calibratedRed: 0.45, green: 0.18, blue: 0.0, alpha: 0.7),
               punchOut: false)
            return true
        }
        image.isTemplate = false
        return image
    }()

    // Cube coordinates: du along the right edge, dv along the left edge,
    // dk straight down. Each in [0, 1].
    private static let side: CGFloat = 5.4
    private static let apex = NSPoint(x: 9, y: 15.0)

    private static func pt(_ du: CGFloat, _ dv: CGFloat, _ dk: CGFloat) -> NSPoint {
        NSPoint(
            x: apex.x + 0.866 * side * du - 0.866 * side * dv,
            y: apex.y - 0.5 * side * du - 0.5 * side * dv - side * dk
        )
    }

    /// Radial warm halo behind the cube.
    private static func drawGlow() {
        let center = NSPoint(x: 9, y: 9)
        for step in stride(from: 9.0, to: 4.0, by: -1.0) {
            let alpha = 0.055 * (10.0 - step)
            NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.25, alpha: alpha).setFill()
            NSBezierPath(ovalIn: NSRect(x: center.x - step, y: center.y - step,
                                        width: step * 2, height: step * 2)).fill()
        }
    }

    /// faceColors: top, left, right.
    private static func drawCube(faceColors: [NSColor], stickerColor: NSColor,
                                 outlineColor: NSColor, punchOut: Bool) {
        func face(_ points: [NSPoint], _ color: NSColor) {
            let path = NSBezierPath()
            path.move(to: points[0])
            points.dropFirst().forEach { path.line(to: $0) }
            path.close()
            color.setFill()
            path.fill()
        }
        face([pt(0, 0, 0), pt(1, 0, 0), pt(1, 1, 0), pt(0, 1, 0)], faceColors[0])
        face([pt(0, 1, 0), pt(1, 1, 0), pt(1, 1, 1), pt(0, 1, 1)], faceColors[1])
        face([pt(1, 0, 0), pt(1, 1, 0), pt(1, 1, 1), pt(1, 0, 1)], faceColors[2])

        // Sticker gaps: thirds of each face. The template variant punches them
        // out so the menu bar shows through; the colored one draws them dark.
        if punchOut { NSGraphicsContext.current?.compositingOperation = .destinationOut }
        let cut = NSBezierPath()
        cut.lineWidth = 0.9
        for t: CGFloat in [1.0 / 3.0, 2.0 / 3.0] {
            cut.move(to: pt(t, 0, 0)); cut.line(to: pt(t, 1, 0))
            cut.move(to: pt(0, t, 0)); cut.line(to: pt(1, t, 0))
            cut.move(to: pt(t, 1, 0)); cut.line(to: pt(t, 1, 1))
            cut.move(to: pt(0, 1, t)); cut.line(to: pt(1, 1, t))
            cut.move(to: pt(1, t, 0)); cut.line(to: pt(1, t, 1))
            cut.move(to: pt(1, 0, t)); cut.line(to: pt(1, 1, t))
        }
        stickerColor.setStroke()
        cut.stroke()
        if punchOut { NSGraphicsContext.current?.compositingOperation = .sourceOver }

        // Crisp silhouette so the glyph reads at menu bar size.
        let outline = NSBezierPath()
        outline.move(to: pt(0, 0, 0))
        outline.line(to: pt(1, 0, 0)); outline.line(to: pt(1, 0, 1))
        outline.line(to: pt(1, 1, 1)); outline.line(to: pt(0, 1, 1))
        outline.line(to: pt(0, 1, 0)); outline.close()
        outline.lineWidth = 1.3
        outlineColor.setStroke()
        outline.stroke()
    }
}
