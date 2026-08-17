// Renders the app icon into App/Resources/AppIcon.icns. Run from the repo root:
//   swift scripts/make-icon.swift
//
// The mark is the one on the site and in the README: a cube seen from above,
// white top, rose left face, blue right, black outline, flat fills, on warm
// white. Coordinates are the design's own 100 x 112 grid — the same numbers as
// the SVG — flipped in y, because AppKit draws upward and the drawing was
// written for a screen that draws downward.
//
// It replaced a dark tile holding a Rubik's cube, which shared nothing with the
// rest of the design: three faces of nine stickers each is a different object
// from one flat cube, and at 16 points the stickers were mush.
import AppKit

let grid = (w: CGFloat(100), h: CGFloat(112))

func poly(_ points: [(CGFloat, CGFloat)], size: CGFloat, unit: CGFloat,
          originX: CGFloat, originY: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    for (index, point) in points.enumerated() {
        let mapped = NSPoint(x: originX + point.0 * unit, y: originY + (grid.h - point.1) * unit)
        index == 0 ? path.move(to: mapped) : path.line(to: mapped)
    }
    path.close()
    return path
}

func drawIcon(size: CGFloat) {
    let inset = size * 0.05
    let tile = NSBezierPath(
        roundedRect: NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset),
        xRadius: size * 0.21, yRadius: size * 0.21
    )
    NSColor(srgbRed: 1, green: 0.992, blue: 0.976, alpha: 1).setFill()
    tile.fill()

    // The cube fills about two thirds of the tile, centred.
    let unit = (size * 0.66) / grid.h
    let originX = (size - grid.w * unit) / 2
    let originY = (size - grid.h * unit) / 2

    let map = { (points: [(CGFloat, CGFloat)]) in
        poly(points, size: size, unit: unit, originX: originX, originY: originY)
    }

    NSColor(srgbRed: 1, green: 0.992, blue: 0.976, alpha: 1).setFill()
    map([(12, 34), (50, 12), (88, 34), (50, 56)]).fill()
    NSColor(srgbRed: 1, green: 0x4F / 255, blue: 0x81 / 255, alpha: 1).setFill()
    map([(12, 34), (50, 56), (50, 100), (12, 78)]).fill()
    NSColor(srgbRed: 0x3A / 255, green: 0x6B / 255, blue: 1, alpha: 1).setFill()
    map([(88, 34), (50, 56), (50, 100), (88, 78)]).fill()

    let outline = map([(12, 34), (50, 12), (88, 34), (88, 78), (50, 100), (12, 78)])
    let inner = NSBezierPath()
    let point = { (x: CGFloat, y: CGFloat) in
        NSPoint(x: originX + x * unit, y: originY + (grid.h - y) * unit)
    }
    inner.move(to: point(12, 34))
    inner.line(to: point(50, 56))
    inner.line(to: point(88, 34))
    inner.move(to: point(50, 56))
    inner.line(to: point(50, 100))
    NSColor(srgbRed: 0.071, green: 0.063, blue: 0.11, alpha: 1).setStroke()
    for path in [outline, inner] {
        path.lineWidth = 2.6 * unit
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.stroke()
    }
}

let repoRoot = FileManager.default.currentDirectoryPath
let iconsetPath = NSTemporaryDirectory() + "plonk-\(ProcessInfo.processInfo.processIdentifier).iconset"
try FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let px = points * scale
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { fatalError("rep \(px)") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawIcon(size: CGFloat(px))
    NSGraphicsContext.restoreGraphicsState()
    let suffix = scale == 2 ? "@2x" : ""
    let url = URL(fileURLWithPath: "\(iconsetPath)/icon_\(points)x\(points)\(suffix).png")
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

let outDir = repoRoot + "/App/Resources"
try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetPath, "-o", outDir + "/AppIcon.icns"]
try task.run()
task.waitUntilExit()
try? FileManager.default.removeItem(atPath: iconsetPath)
print(task.terminationStatus == 0 ? "wrote App/Resources/AppIcon.icns" : "iconutil failed")
