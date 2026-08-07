// Renders the app icon — an isometric Rubik's cube on a dark rounded square —
// into App/Resources/AppIcon.icns. Run from the repo root:
//   swift scripts/make-icon.swift
import AppKit

struct Vec {
    let x: CGFloat
    let y: CGFloat
    static func + (a: Vec, b: Vec) -> Vec { Vec(x: a.x + b.x, y: a.y + b.y) }
    static func * (a: Vec, s: CGFloat) -> Vec { Vec(x: a.x * s, y: a.y * s) }
    var point: NSPoint { NSPoint(x: x, y: y) }
}

func quad(_ p0: Vec, _ e1: Vec, _ e2: Vec) -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: p0.point)
    path.line(to: (p0 + e1).point)
    path.line(to: (p0 + e1 + e2).point)
    path.line(to: (p0 + e2).point)
    path.close()
    return path
}

func drawFace(origin: Vec, e1: Vec, e2: Vec, sticker: NSColor, gapColor: NSColor) {
    gapColor.setFill()
    quad(origin, e1, e2).fill()
    let g: CGFloat = 0.045
    sticker.setFill()
    for i in 0..<3 {
        for j in 0..<3 {
            let p = origin + e1 * ((CGFloat(i) + g) / 3) + e2 * ((CGFloat(j) + g) / 3)
            quad(p, e1 * ((1 - 2 * g) / 3), e2 * ((1 - 2 * g) / 3)).fill()
        }
    }
}

func drawIcon(size: CGFloat) {
    let inset = size * 0.05
    let bg = NSBezierPath(
        roundedRect: NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset),
        xRadius: size * 0.21, yRadius: size * 0.21
    )
    NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.14, alpha: 1).setFill()
    bg.fill()

    let s = size * 0.31
    let apex = Vec(x: size / 2, y: size * 0.815)
    let u = Vec(x: 0.866 * s, y: -0.5 * s)
    let v = Vec(x: -0.866 * s, y: -0.5 * s)
    let k = Vec(x: 0, y: -s)
    let gap = NSColor(calibratedRed: 0.07, green: 0.075, blue: 0.09, alpha: 1)

    drawFace(origin: apex, e1: u, e2: v,
             sticker: NSColor(calibratedRed: 0.96, green: 0.96, blue: 0.95, alpha: 1), gapColor: gap)
    drawFace(origin: apex + v, e1: u, e2: k,
             sticker: NSColor(calibratedRed: 0.90, green: 0.28, blue: 0.30, alpha: 1), gapColor: gap)
    drawFace(origin: apex + u, e1: v, e2: k,
             sticker: NSColor(calibratedRed: 0.18, green: 0.51, blue: 0.97, alpha: 1), gapColor: gap)
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
