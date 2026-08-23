import AppKit

// Menu bar glyph: an isometric Rubik's cube. Three variants — a monochrome
// template for the idle state, a warm one lit from behind (sun glow) for the
// keep-awake state, and that one split down the middle with a red half while
// the lid-closed hold is on. The lit ones must keep their color, so they are
// not templates.
enum StatusIcon {

    /// One lit cube's worth of color: the three faces, what the sticker gaps
    /// and the silhouette are drawn in, and the halo behind it.
    private struct Palette {
        let faces: [NSColor]
        let sticker: NSColor
        let outline: NSColor
        let glow: NSColor
    }

    private static let amber = Palette(
        faces: [
            NSColor(calibratedRed: 1.0, green: 0.86, blue: 0.30, alpha: 1),
            NSColor(calibratedRed: 0.95, green: 0.45, blue: 0.10, alpha: 1),
            NSColor(calibratedRed: 0.99, green: 0.66, blue: 0.16, alpha: 1),
        ],
        sticker: NSColor(calibratedRed: 0.35, green: 0.14, blue: 0.0, alpha: 0.55),
        outline: NSColor(calibratedRed: 0.45, green: 0.18, blue: 0.0, alpha: 0.7),
        glow: NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.25, alpha: 1)
    )

    /// Deep red rather than a brighter one: at menu bar size the half has to
    /// read as a different state at a glance, not as a second shade of amber.
    private static let ember = Palette(
        faces: [
            NSColor(calibratedRed: 0.80, green: 0.16, blue: 0.20, alpha: 1),
            NSColor(calibratedRed: 0.42, green: 0.03, blue: 0.10, alpha: 1),
            NSColor(calibratedRed: 0.60, green: 0.08, blue: 0.15, alpha: 1),
        ],
        sticker: NSColor(calibratedRed: 0.20, green: 0.0, blue: 0.04, alpha: 0.6),
        outline: NSColor(calibratedRed: 0.26, green: 0.0, blue: 0.05, alpha: 0.75),
        glow: NSColor(calibratedRed: 0.85, green: 0.16, blue: 0.20, alpha: 1)
    )

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

    static let awake: NSImage = lit { drawLit(amber) }

    /// Keep-awake and the lid-closed hold at once: the same cube, split down
    /// the middle. Each half is drawn whole and clipped, so the halo halves
    /// meet instead of one being laid over the other.
    static let awakeLidClosed: NSImage = lit {
        clipped(to: NSRect(x: 0, y: 0, width: 9, height: 18)) { drawLit(ember) }
        clipped(to: NSRect(x: 9, y: 0, width: 9, height: 18)) { drawLit(amber) }
    }

    /// A colored variant: 18 points square and never a template, or the menu
    /// bar would flatten it back to one ink.
    private static func lit(_ draw: @escaping () -> Void) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            draw()
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func clipped(to rect: NSRect, _ draw: () -> Void) {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: rect).setClip()
        draw()
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawLit(_ palette: Palette) {
        drawGlow(palette.glow)
        drawCube(faceColors: palette.faces, stickerColor: palette.sticker,
                 outlineColor: palette.outline, punchOut: false)
    }

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

    /// Radial halo behind the cube.
    private static func drawGlow(_ color: NSColor) {
        let center = NSPoint(x: 9, y: 9)
        for step in stride(from: 9.0, to: 4.0, by: -1.0) {
            let alpha = 0.055 * (10.0 - step)
            color.withAlphaComponent(alpha).setFill()
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
