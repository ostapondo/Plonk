#!/usr/bin/env swift
// The desk, drawn: wallpaper, menu bar, windows, the zone overlay, and the bits
// of chrome the app puts on top of them. Every scene in this folder is this
// file plus a timeline, concatenated by scripts/make-demo.sh, so everything
// here is declared before a scene runs.
//
// Drawn rather than recorded, on purpose. A screen recording of a window
// manager is mostly other people's apps, it dates the moment any of them is
// redesigned, and nobody reading this repo can regenerate it. This they can:
// every frame is a pure function of time.

import AppKit
import CoreText

// MARK: - Canvas

let fps = 20.0
let size = CGSize(width: 1200, height: 750)

// MARK: - Timeline

/// 0 at `from`, 1 at `to`, eased so movement starts and stops softly.
func phase(_ t: Double, from: Double, to: Double) -> Double {
    guard to > from else { return t >= to ? 1 : 0 }
    let raw = min(max((t - from) / (to - from), 0), 1)
    return raw < 0.5 ? 4 * raw * raw * raw : 1 - pow(-2 * raw + 2, 3) / 2
}

/// Rises to 1 and comes back down: for anything that appears, holds, and goes.
func pulse(_ t: Double, _ inFrom: Double, _ inTo: Double, _ outFrom: Double, _ outTo: Double) -> Double {
    phase(t, from: inFrom, to: inTo) - phase(t, from: outFrom, to: outTo)
}

/// Overshoots a little before settling, which is what a window dropping into a
/// zone looks like when the app animates it.
func settle(_ t: Double, from: Double, to: Double) -> Double {
    let raw = min(max((t - from) / max(to - from, 0.0001), 0), 1)
    guard raw < 1 else { return 1 }
    let c = 1.70158 * 1.2
    let p = raw - 1
    return 1 + (c + 1) * pow(p, 3) + c * pow(p, 2)
}

func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

func lerp(_ a: CGRect, _ b: CGRect, _ t: Double) -> CGRect {
    CGRect(x: lerp(a.minX, b.minX, t), y: lerp(a.minY, b.minY, t),
           width: lerp(a.width, b.width, t), height: lerp(a.height, b.height, t))
}

// MARK: - Palette

/// 0 in the dark theme, 1 in the light one. Every colour is a blend of the two,
/// so a variant picks a look by setting one number.
var themeBlend = 0.0

func mix(_ dark: NSColor, _ light: NSColor, _ t: Double) -> NSColor {
    guard t > 0 else { return dark }
    let a = dark.usingColorSpace(.sRGB) ?? dark
    let b = light.usingColorSpace(.sRGB) ?? light
    return NSColor(srgbRed: a.redComponent + (b.redComponent - a.redComponent) * t,
                   green: a.greenComponent + (b.greenComponent - a.greenComponent) * t,
                   blue: a.blueComponent + (b.blueComponent - a.blueComponent) * t,
                   alpha: a.alphaComponent + (b.alphaComponent - a.alphaComponent) * t)
}

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}

/// Surfaces, in the same order the app stacks them: wallpaper behind, window
/// on top of it, chrome a step in front of that.
///
/// The values matter more than they look. The window fill has to be clearly
/// lighter than the wallpaper or eight windows read as one dark rectangle, and
/// the body lines have to be bright enough to survive a 256-colour palette.
enum Ink {
    static var wallTop: NSColor { mix(rgb(0.075, 0.075, 0.105), rgb(0.86, 0.87, 0.92), themeBlend) }
    static var wallBottom: NSColor { mix(rgb(0.035, 0.035, 0.055), rgb(0.94, 0.94, 0.97), themeBlend) }
    static var wallGlow: NSColor { mix(rgb(0.16, 0.14, 0.26, 0.85), rgb(1, 1, 1, 0.85), themeBlend) }
    static var bar: NSColor { mix(rgb(0.02, 0.02, 0.035, 0.85), rgb(1, 1, 1, 0.72), themeBlend) }

    /// Plonk's own accent, and its warmer neighbour.
    static let accent = rgb(0.545, 0.486, 0.965)
    static let warm = rgb(0.949, 0.475, 0.373)
    static let amber = rgb(1.0, 0.72, 0.30)

    static var pane: NSColor { mix(rgb(0.115, 0.125, 0.165), rgb(1, 1, 1), themeBlend) }
    static var chrome: NSColor { mix(rgb(0.155, 0.168, 0.215), rgb(0.965, 0.968, 0.978), themeBlend) }
    static var sunken: NSColor { mix(rgb(0.075, 0.082, 0.115), rgb(0.955, 0.958, 0.972), themeBlend) }
    static var panel: NSColor { mix(rgb(0.135, 0.145, 0.19, 0.99), rgb(1, 1, 1, 0.99), themeBlend) }

    static var text: NSColor { mix(NSColor(white: 0.96, alpha: 1), NSColor(white: 0.07, alpha: 1), themeBlend) }
    static var dim: NSColor { mix(NSColor(white: 0.66, alpha: 1), NSColor(white: 0.38, alpha: 1), themeBlend) }
    static var line: NSColor { mix(NSColor(white: 1, alpha: 0.14), NSColor(white: 0, alpha: 0.11), themeBlend) }
    static var body: NSColor { mix(NSColor(white: 1, alpha: 0.22), NSColor(white: 0, alpha: 0.16), themeBlend) }
    static var faint: NSColor { mix(NSColor(white: 1, alpha: 0.10), NSColor(white: 0, alpha: 0.07), themeBlend) }
    static var shadow: NSColor { mix(NSColor(white: 0, alpha: 0.55), NSColor(white: 0, alpha: 0.16), themeBlend) }
}

// MARK: - Drawing helpers

func fill(_ rect: CGRect, _ color: NSColor, radius: CGFloat = 0, in ctx: CGContext) {
    ctx.setFillColor(color.cgColor)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.fillPath()
}

func stroke(_ rect: CGRect, _ color: NSColor, radius: CGFloat = 0, width: CGFloat = 1,
            in ctx: CGContext) {
    ctx.setStrokeColor(color.cgColor)
    ctx.setLineWidth(width)
    ctx.addPath(CGPath(roundedRect: rect.insetBy(dx: width / 2, dy: width / 2),
                       cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.strokePath()
}

func clipped(_ rect: CGRect, radius: CGFloat, in ctx: CGContext, _ draw: () -> Void) {
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.clip()
    draw()
    ctx.restoreGState()
}

/// Draws at `alpha`, or not at all once it would be invisible.
func faded(_ alpha: CGFloat, in ctx: CGContext, _ draw: () -> Void) {
    guard alpha > 0.01 else { return }
    ctx.saveGState()
    ctx.setAlpha(alpha)
    draw()
    ctx.restoreGState()
}

/// A floating surface: the panel fill under a shadow, with a border on top.
/// The shadow is switched off again so what is drawn inside stays flat.
func panel(_ rect: CGRect, radius: CGFloat, border: NSColor, borderWidth: CGFloat = 1,
           lift: CGFloat = 8, blur: CGFloat = 30, shadow: NSColor = Ink.shadow, in ctx: CGContext) {
    ctx.setShadow(offset: CGSize(width: 0, height: -lift), blur: blur, color: shadow.cgColor)
    fill(rect, Ink.panel, radius: radius, in: ctx)
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    stroke(rect, border, radius: radius, width: borderWidth, in: ctx)
}

func gradient(_ rect: CGRect, _ from: NSColor, _ to: NSColor, in ctx: CGContext) {
    let ramp = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [from.cgColor, to.cgColor] as CFArray, locations: [0, 1])!
    ctx.saveGState()
    ctx.clip(to: rect)
    ctx.drawLinearGradient(ramp, start: CGPoint(x: rect.minX, y: rect.maxY),
                           end: CGPoint(x: rect.maxX, y: rect.minY), options: [])
    ctx.restoreGState()
}

enum Align { case left, centre, right }

func font(_ pointSize: CGFloat, _ weight: NSFont.Weight = .regular, mono: Bool = false) -> NSFont {
    mono ? NSFont.monospacedSystemFont(ofSize: pointSize, weight: weight)
         : NSFont.systemFont(ofSize: pointSize, weight: weight)
}

private func typeset(_ string: String, size fontSize: CGFloat, color: NSColor, weight: NSFont.Weight,
                  tracking: CGFloat, mono: Bool) -> (line: CTLine, advance: CGFloat) {
    var attributes: [NSAttributedString.Key: Any] = [
        .font: font(fontSize, weight, mono: mono), .foregroundColor: color,
    ]
    if tracking != 0 { attributes[.kern] = tracking }
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes))
    return (line, CTLineGetTypographicBounds(line, nil, nil, nil))
}

@discardableResult
func text(_ string: String, at point: CGPoint, size fontSize: CGFloat, color: NSColor,
          weight: NSFont.Weight = .regular, align: Align = .left, tracking: CGFloat = 0,
          mono: Bool = false, in ctx: CGContext) -> CGFloat {
    let (line, advance) = typeset(string, size: fontSize, color: color, weight: weight,
                                  tracking: tracking, mono: mono)
    var x = point.x
    if align == .centre { x -= advance / 2 }
    if align == .right { x -= advance }
    ctx.textPosition = CGPoint(x: x, y: point.y)
    CTLineDraw(line, ctx)
    return advance
}

func width(of string: String, size fontSize: CGFloat, weight: NSFont.Weight = .regular,
           tracking: CGFloat = 0, mono: Bool = false) -> CGFloat {
    typeset(string, size: fontSize, color: .black, weight: weight, tracking: tracking, mono: mono).advance
}

/// A character-by-character reveal that lands on whole characters, so the text
/// does not shimmer between frames.
func typed(_ line: String, _ progress: Double) -> String {
    let count = Int((Double(line.count) * min(max(progress, 0), 1)).rounded(.down))
    return String(line.prefix(count))
}

// MARK: - The desk

/// The wallpaper and the menu bar. Menu titles are drawn because a bare bar
/// reads as a rectangle; with them the frame is recognisably a Mac.
func drawDesk(in ctx: CGContext) {
    gradient(CGRect(origin: .zero, size: size), Ink.wallTop, Ink.wallBottom, in: ctx)
    let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [Ink.wallGlow.cgColor,
                                   Ink.wallGlow.withAlphaComponent(0).cgColor] as CFArray,
                          locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: size.width * 0.5, y: size.height * 0.72),
                           startRadius: 0, endCenter: CGPoint(x: size.width * 0.5, y: size.height * 0.72),
                           endRadius: size.width * 0.7, options: [])

    let bar = CGRect(x: 0, y: size.height - 34, width: size.width, height: 34)
    fill(bar, Ink.bar, in: ctx)
    fill(CGRect(x: 0, y: bar.minY, width: size.width, height: 1), Ink.faint, in: ctx)

    // Apple menu, drawn as a small rounded lozenge — near enough at this size.
    fill(CGRect(x: 22, y: size.height - 23, width: 11, height: 13), Ink.dim, radius: 5, in: ctx)
    var x: CGFloat = 48
    for (index, item) in ["Finder", "File", "Edit", "View", "Window", "Help"].enumerated() {
        let advance = text(item, at: CGPoint(x: x, y: size.height - 23), size: 13,
                           color: index == 0 ? Ink.text : Ink.dim,
                           weight: index == 0 ? .bold : .regular, in: ctx)
        x += advance + 22
    }

    // The right-hand side, ending in Plonk's cube: the icon this is all behind.
    text("Fri 9:41", at: CGPoint(x: size.width - 24, y: size.height - 23), size: 13,
         color: Ink.dim, align: .right, in: ctx)
    drawCube(at: CGPoint(x: size.width - 112, y: size.height - 17), scale: 1, glow: 0, in: ctx)
    for offset in [0.0, 30.0, 60.0] {
        fill(CGRect(x: size.width - 210 + offset, y: size.height - 22, width: 13, height: 11),
             Ink.dim.withAlphaComponent(0.55), radius: 2, in: ctx)
    }
}

/// Plonk's status icon: a cube, two faces and a top. `glow` rings it, for the
/// beats where the app itself is what changed.
func drawCube(at centre: CGPoint, scale: CGFloat, glow: Double, in ctx: CGContext) {
    faded(CGFloat(glow), in: ctx) {
        fill(CGRect(x: centre.x - 17 * scale, y: centre.y - 17 * scale,
                    width: 34 * scale, height: 34 * scale),
             Ink.amber.withAlphaComponent(0.22), radius: 10 * scale, in: ctx)
    }
    let body = CGRect(x: centre.x - 8 * scale, y: centre.y - 8 * scale,
                      width: 16 * scale, height: 11 * scale)
    fill(body, Ink.amber, radius: 2 * scale, in: ctx)
    fill(CGRect(x: body.minX + 3 * scale, y: body.minY + 8 * scale,
                width: 10 * scale, height: 6 * scale),
         Ink.amber.withAlphaComponent(0.55), radius: 2 * scale, in: ctx)
}

// MARK: - Windows

/// What a window has inside it. Eight identical grey wireframes read as a
/// mockup; a browser that looks like a browser and a terminal that looks like a
/// terminal read as a desk.
enum Body {
    case browser, code, terminal, chat, files, mail, notes, chart
}

struct Pane {
    var title: String
    var rect: CGRect
    var tint: NSColor
    var body: Body
    /// Windows behind the front one are dimmed rather than redrawn, the way a
    /// stack of them looks on a real screen.
    var recede: Double = 0
}

private let lineWidths: [CGFloat] = [0.92, 0.68, 0.84, 0.52, 0.76, 0.62, 0.88, 0.46, 0.8, 0.7]

func draw(_ pane: Pane, alpha: CGFloat = 1, in ctx: CGContext) {
    guard pane.rect.width > 8, pane.rect.height > 8 else { return }
    // Chrome and body scale with the window: full-size chrome on a small tile
    // reads as a toolbar rather than as a title bar.
    let scale = min(max(pane.rect.width / 560, 0.52), 1)
    let radius: CGFloat = 9 * scale + 3
    faded(alpha, in: ctx) {
        ctx.setShadow(offset: CGSize(width: 0, height: -7 * scale), blur: 26 * scale,
                      color: Ink.shadow.cgColor)
        fill(pane.rect, Ink.pane, radius: radius, in: ctx)
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        let chromeHeight = round(28 * scale)
        let chrome = CGRect(x: pane.rect.minX, y: pane.rect.maxY - chromeHeight,
                            width: pane.rect.width, height: chromeHeight)
        clipped(pane.rect, radius: radius, in: ctx) {
            fill(chrome, Ink.chrome, in: ctx)
            fill(CGRect(x: chrome.minX, y: chrome.minY, width: chrome.width, height: 1), Ink.faint, in: ctx)

            let light = 8.5 * scale
            for (index, colour) in [rgb(1, 0.37, 0.34), rgb(1, 0.74, 0.18), rgb(0.24, 0.79, 0.33)].enumerated() {
                fill(CGRect(x: chrome.minX + 13 * scale + CGFloat(index) * (light + 6.5 * scale),
                            y: chrome.midY - light / 2, width: light, height: light),
                     colour, radius: light / 2, in: ctx)
            }
            let titleSize = max(9.5, 12.5 * scale)
            let titleWidth = width(of: pane.title, size: titleSize, weight: .semibold)
            if titleWidth + 40 * scale < chrome.width {
                text(pane.title, at: CGPoint(x: chrome.midX, y: chrome.midY - titleSize * 0.36),
                     size: titleSize, color: Ink.dim, weight: .semibold, align: .centre, in: ctx)
            }
            drawBody(pane, in: CGRect(x: pane.rect.minX, y: pane.rect.minY,
                                      width: pane.rect.width, height: chrome.minY - pane.rect.minY),
                     scale: scale, in: ctx)
            if pane.recede > 0.01 {
                fill(pane.rect, Ink.wallBottom.withAlphaComponent(CGFloat(pane.recede)), in: ctx)
            }
        }
        stroke(pane.rect, Ink.line, radius: radius, in: ctx)
    }
}

private func drawBody(_ pane: Pane, in area: CGRect, scale: CGFloat, in ctx: CGContext) {
    let pad = 15 * scale
    let content = area.insetBy(dx: pad, dy: 0)
    switch pane.body {
    case .browser:
        // A tab strip and an address pill, then a hero block and text.
        let strip = CGRect(x: area.minX, y: area.maxY - 26 * scale, width: area.width, height: 26 * scale)
        fill(strip, Ink.sunken, in: ctx)
        var x = strip.minX + 10 * scale
        for index in 0..<3 {
            let tab = CGRect(x: x, y: strip.minY + 4 * scale,
                             width: min(74 * scale, (strip.width - 30 * scale) / 3),
                             height: strip.height - 7 * scale)
            fill(tab, index == 0 ? Ink.pane : Ink.faint, radius: 4 * scale, in: ctx)
            fill(CGRect(x: tab.minX + 7 * scale, y: tab.midY - 2.5 * scale,
                        width: min(tab.width - 14 * scale, 40 * scale), height: 5 * scale),
                 index == 0 ? pane.tint.withAlphaComponent(0.85) : Ink.body, radius: 2.5 * scale, in: ctx)
            x += tab.width + 5 * scale
        }
        let bar = CGRect(x: content.minX, y: strip.minY - 24 * scale,
                         width: content.width, height: 17 * scale)
        fill(bar, Ink.sunken, radius: bar.height / 2, in: ctx)
        fill(CGRect(x: bar.minX + 10 * scale, y: bar.midY - 2.5 * scale,
                    width: bar.width * 0.42, height: 5 * scale), Ink.body,
             radius: 2.5 * scale, in: ctx)
        let hero = CGRect(x: content.minX, y: bar.minY - 15 * scale - content.height * 0.3,
                          width: content.width, height: content.height * 0.3)
        if hero.height > 12 * scale {
            clipped(hero, radius: 6 * scale, in: ctx) {
                gradient(hero, pane.tint.withAlphaComponent(0.55),
                         pane.tint.withAlphaComponent(0.12), in: ctx)
            }
        }
        textLines(from: hero.minY - 16 * scale, in: content, scale: scale, in: ctx)
    case .code:
        // A gutter and indented token bars: code without pretending to be code.
        let gutter = CGRect(x: area.minX, y: area.minY, width: 26 * scale, height: area.height)
        fill(gutter, Ink.sunken, in: ctx)
        var y = area.maxY - 20 * scale
        var index = 0
        let indents: [CGFloat] = [0, 0, 1, 2, 2, 1, 0, 1, 2, 3, 2, 0]
        while y > area.minY + 8 * scale {
            let indent = indents[index % indents.count] * 14 * scale
            let start = gutter.maxX + 12 * scale + indent
            let room = area.maxX - 14 * scale - start
            if room > 20 * scale {
                let keyword = min(room * 0.22, 34 * scale)
                fill(CGRect(x: start, y: y, width: keyword, height: 5.5 * scale),
                     pane.tint.withAlphaComponent(0.85), radius: 2.75 * scale, in: ctx)
                fill(CGRect(x: start + keyword + 8 * scale, y: y,
                            width: (room - keyword - 8 * scale) * lineWidths[index % lineWidths.count],
                            height: 5.5 * scale), Ink.body, radius: 2.75 * scale, in: ctx)
            }
            fill(CGRect(x: gutter.midX - 4 * scale, y: y, width: 8 * scale, height: 5.5 * scale),
                 Ink.faint, radius: 2 * scale, in: ctx)
            y -= 15 * scale
            index += 1
        }
    case .terminal:
        fill(area, Ink.sunken, in: ctx)
        var y = area.maxY - 20 * scale
        var index = 0
        while y > area.minY + 8 * scale {
            let prompt = index % 4 == 0
            fill(CGRect(x: content.minX, y: y, width: 7 * scale, height: 5.5 * scale),
                 prompt ? pane.tint : Ink.faint, radius: 2 * scale, in: ctx)
            fill(CGRect(x: content.minX + 13 * scale, y: y,
                        width: (content.width - 13 * scale) * lineWidths[index % lineWidths.count],
                        height: 5.5 * scale),
                 prompt ? Ink.body : Ink.body.withAlphaComponent(Ink.body.alphaComponent * 0.6),
                 radius: 2.75 * scale, in: ctx)
            y -= 14 * scale
            index += 1
        }
    case .chat:
        var y = area.maxY - 24 * scale
        var index = 0
        while y > area.minY + 10 * scale {
            let mine = index % 2 == 1
            let bubbleWidth = content.width * (mine ? 0.52 : 0.66)
            let height = (index % 3 == 0 ? 34 : 22) * scale
            let bubble = CGRect(x: mine ? content.maxX - bubbleWidth : content.minX,
                                y: y - height, width: bubbleWidth, height: height)
            fill(bubble, mine ? pane.tint.withAlphaComponent(0.55) : Ink.faint,
                 radius: 8 * scale, in: ctx)
            y -= height + 10 * scale
            index += 1
        }
    case .files:
        let side = CGRect(x: area.minX, y: area.minY, width: min(70 * scale, area.width * 0.28),
                          height: area.height)
        fill(side, Ink.sunken, in: ctx)
        var y = side.maxY - 20 * scale
        var row = 0
        while y > side.minY + 8 * scale {
            fill(CGRect(x: side.minX + 10 * scale, y: y, width: 7 * scale, height: 7 * scale),
                 row == 1 ? pane.tint : Ink.faint, radius: 2 * scale, in: ctx)
            fill(CGRect(x: side.minX + 22 * scale, y: y + 1 * scale,
                        width: (side.width - 32 * scale) * lineWidths[row % lineWidths.count],
                        height: 5 * scale), Ink.body, radius: 2.5 * scale, in: ctx)
            y -= 17 * scale
            row += 1
        }
        // A grid of files, as big as fits.
        let grid = CGRect(x: side.maxX + 14 * scale, y: area.minY + 12 * scale,
                          width: area.maxX - side.maxX - 28 * scale, height: area.height - 24 * scale)
        let cell = 44 * scale
        let columns = max(Int(grid.width / cell), 1)
        let rows = max(Int(grid.height / cell), 1)
        for column in 0..<columns {
            for line in 0..<rows {
                let box = CGRect(x: grid.minX + CGFloat(column) * cell,
                                 y: grid.maxY - CGFloat(line + 1) * cell,
                                 width: cell - 12 * scale, height: cell - 16 * scale)
                fill(box, (column + line) % 5 == 0 ? pane.tint.withAlphaComponent(0.5) : Ink.faint,
                     radius: 4 * scale, in: ctx)
            }
        }
    case .mail:
        var y = area.maxY - 14 * scale
        var index = 0
        while y > area.minY + 20 * scale {
            let row = CGRect(x: area.minX, y: y - 32 * scale, width: area.width, height: 32 * scale)
            if index == 0 { fill(row, pane.tint.withAlphaComponent(0.16), in: ctx) }
            fill(CGRect(x: content.minX, y: row.midY + 3 * scale, width: 6 * scale, height: 6 * scale),
                 index == 0 ? pane.tint : Ink.faint, radius: 3 * scale, in: ctx)
            fill(CGRect(x: content.minX + 14 * scale, y: row.midY + 3 * scale,
                        width: (content.width - 14 * scale) * 0.5, height: 5.5 * scale),
                 Ink.body, radius: 2.75 * scale, in: ctx)
            fill(CGRect(x: content.minX + 14 * scale, y: row.midY - 8 * scale,
                        width: (content.width - 14 * scale) * lineWidths[index % lineWidths.count],
                        height: 5 * scale), Ink.faint, radius: 2.5 * scale, in: ctx)
            y -= 32 * scale
            index += 1
        }
    case .chart:
        let plot = area.insetBy(dx: 18 * scale, dy: 18 * scale)
        for step in 0...3 {
            let y = plot.minY + plot.height * CGFloat(step) / 3
            fill(CGRect(x: plot.minX, y: y, width: plot.width, height: 1), Ink.faint, in: ctx)
        }
        let heights: [CGFloat] = [0.42, 0.66, 0.5, 0.82, 0.6, 0.94, 0.72]
        let barWidth = plot.width / CGFloat(heights.count) - 8 * scale
        for (index, height) in heights.enumerated() where barWidth > 2 {
            let bar = CGRect(x: plot.minX + CGFloat(index) * (barWidth + 8 * scale), y: plot.minY,
                             width: barWidth, height: plot.height * height)
            fill(bar, pane.tint.withAlphaComponent(index == heights.count - 2 ? 0.95 : 0.4),
                 radius: 3 * scale, in: ctx)
        }
    case .notes:
        let heading = CGRect(x: content.minX, y: area.maxY - 24 * scale,
                             width: min(content.width * 0.45, 160 * scale), height: 8 * scale)
        fill(heading, pane.tint.withAlphaComponent(0.9), radius: 4 * scale, in: ctx)
        textLines(from: heading.minY - 20 * scale, in: content, scale: scale, in: ctx)
    }
}

/// Grey lines that fill whatever room is left. Filled to the bottom rather than
/// to a fixed count: a window with a third of its content drawn reads as one
/// that is still loading.
private func textLines(from top: CGFloat, in content: CGRect, scale: CGFloat, in ctx: CGContext) {
    var y = top
    var index = 0
    while y > content.minY + 12 * scale {
        fill(CGRect(x: content.minX, y: y, width: content.width * lineWidths[index % lineWidths.count],
                    height: 5.5 * scale),
             Ink.body, radius: 2.75 * scale, in: ctx)
        y -= ((index % 5 == 4) ? 25 : 14) * scale
        index += 1
    }
}

// MARK: - Zones

/// A zone as the app stores one: a fraction of the screen's visible area,
/// origin top-left. Every layout in these variants is written this way so the
/// numbers could be pasted into a zone set file unchanged.
struct Frac {
    var x: Double, y: Double, w: Double, h: Double

    func contains(_ px: Double, _ py: Double) -> Bool {
        px > x && px < x + w && py > y && py < y + h
    }
}

var desk = CGRect.zero

extension Frac {
    var rect: CGRect {
        CGRect(x: desk.minX + desk.width * x, y: desk.maxY - desk.height * (y + h),
               width: desk.width * w, height: desk.height * h)
    }
}

/// The overlay the app draws while a window is being dragged: rounded tiles,
/// numbered, the drop target lit.
func drawZones(_ zones: [CGRect], highlighted: Set<Int>, alpha: CGFloat,
               numbers: Bool = true, in ctx: CGContext) {
    faded(alpha, in: ctx) {
        for (index, zone) in zones.enumerated() {
            let lit = highlighted.contains(index)
            fill(zone, Ink.accent.withAlphaComponent(lit ? 0.30 : 0.11), radius: 10, in: ctx)
            stroke(zone, Ink.accent.withAlphaComponent(lit ? 1 : 0.45), radius: 10,
                   width: lit ? 3 : 1.5, in: ctx)
            guard numbers else { continue }
            let numberSize = max(24, min(58, min(zone.width, zone.height) * 0.32))
            text("\(index + 1)", at: CGPoint(x: zone.midX, y: zone.midY - numberSize * 0.37),
                 size: numberSize, color: Ink.accent.withAlphaComponent(lit ? 1 : 0.45),
                 weight: .bold, align: .centre, in: ctx)
        }
    }
}

// MARK: - Chrome the app puts on top

/// A row of key caps, e.g. ⌃⌥2. Big, because at 720px wide a small one is a
/// smudge.
func drawKeys(_ keys: [String], centeredAt point: CGPoint, alpha: CGFloat, in ctx: CGContext) {
    faded(alpha, in: ctx) {
        let capHeight: CGFloat = 52
        let caps = keys.map { max(capHeight, width(of: $0, size: 25, weight: .semibold) + 30) }
        let total = caps.reduce(0, +) + CGFloat(keys.count - 1) * 9
        var x = point.x - total / 2
        for (index, key) in keys.enumerated() {
            let rect = CGRect(x: x, y: point.y, width: caps[index], height: capHeight)
            panel(rect, radius: 11, border: Ink.line, borderWidth: 1.5, lift: 4, blur: 14, in: ctx)
            text(key, at: CGPoint(x: rect.midX, y: rect.midY - 10), size: 25, color: Ink.text,
                 weight: .semibold, align: .centre, in: ctx)
            x += caps[index] + 9
        }
    }
}

/// The pointer, drawn rather than screenshotted so it renders at any size.
func drawCursor(at point: CGPoint, alpha: CGFloat, in ctx: CGContext) {
    faded(alpha, in: ctx) {
        ctx.setShadow(offset: CGSize(width: 0, height: -2), blur: 7,
                      color: NSColor.black.withAlphaComponent(0.7).cgColor)
        let path = CGMutablePath()
        path.move(to: point)
        path.addLine(to: CGPoint(x: point.x, y: point.y - 29))
        path.addLine(to: CGPoint(x: point.x + 7.3, y: point.y - 21.8))
        path.addLine(to: CGPoint(x: point.x + 12.3, y: point.y - 31.3))
        path.addLine(to: CGPoint(x: point.x + 17.9, y: point.y - 28.5))
        path.addLine(to: CGPoint(x: point.x + 12.9, y: point.y - 19))
        path.addLine(to: CGPoint(x: point.x + 22.4, y: point.y - 17.9))
        path.closeSubpath()
        ctx.addPath(path)
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillPath()
        ctx.addPath(path)
        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.55).cgColor)
        ctx.setLineWidth(1.2)
        ctx.strokePath()
    }
}

/// The ring a click leaves, so fast clicks read as clicks.
func drawClick(at point: CGPoint, progress: Double, in ctx: CGContext) {
    guard progress > 0, progress < 1 else { return }
    faded(CGFloat(1 - progress), in: ctx) {
        let radius = 30 * CGFloat(progress)
        stroke(CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2),
               Ink.accent, radius: radius, width: 3, in: ctx)
    }
}

/// The line above the desk that says which of the app's three ways is being
/// shown. A step number, a title and a sentence, left-aligned in the bottom
/// band so it never covers a window.
func drawChapter(_ step: String, _ title: String, _ sub: String, alpha: CGFloat,
                 rise: Double = 0, in ctx: CGContext) {
    faded(alpha, in: ctx) {
        let baseline: CGFloat = 44 - CGFloat(1 - rise) * 12
        text(step.uppercased(), at: CGPoint(x: 46, y: baseline + 46), size: 13, color: Ink.accent,
             weight: .bold, tracking: 1.6, in: ctx)
        text(title, at: CGPoint(x: 46, y: baseline + 14), size: 30, color: Ink.text,
             weight: .semibold, in: ctx)
        text(sub, at: CGPoint(x: 46, y: baseline - 14), size: 16, color: Ink.dim, in: ctx)
    }
}

/// A centred title, for the frames that end a variant.
func drawCaption(_ line: String, _ sub: String, alpha: CGFloat, at y: CGFloat = 92,
                 in ctx: CGContext) {
    faded(alpha, in: ctx) {
        text(line, at: CGPoint(x: size.width / 2, y: y), size: 36, color: Ink.text,
             weight: .semibold, align: .centre, in: ctx)
        text(sub, at: CGPoint(x: size.width / 2, y: y - 36), size: 17, color: Ink.dim,
             align: .centre, in: ctx)
    }
}

/// The agent's line, typed a character at a time, with a dot that says who is
/// talking and a caret that stops when the sentence lands. Centred low on the
/// stage unless a scene hands it a `frame` of its own.
func drawPrompt(_ line: String, progress: Double, alpha: CGFloat, frame: CGRect? = nil,
                label: String = "", in ctx: CGContext) {
    faded(alpha, in: ctx) {
        let shown = typed(line, progress)
        let box = frame ?? CGRect(x: size.width / 2 - 396, y: 46, width: 792, height: 64)
        panel(box, radius: 15, border: Ink.accent.withAlphaComponent(0.55), borderWidth: 1.5, in: ctx)
        fill(CGRect(x: box.minX + 22, y: box.midY - 5, width: 10, height: 10), Ink.accent,
             radius: 5, in: ctx)
        let start = box.minX + 46
        let advance = text(shown, at: CGPoint(x: start, y: box.midY - 7), size: 16.5, color: Ink.text,
                           mono: true, in: ctx)
        if progress < 1 {
            fill(CGRect(x: start + advance + 2, y: box.midY - 10, width: 9, height: 20),
                 Ink.accent.withAlphaComponent(0.8), radius: 1.5, in: ctx)
        }
        if !label.isEmpty {
            text(label, at: CGPoint(x: box.maxX - 22, y: box.midY - 6), size: 13, color: Ink.dim,
                 weight: .medium, align: .right, in: ctx)
        }
    }
}

// MARK: - Output

func render(duration: Double, _ frame: (Double) -> CGImage) {
    let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/plonk-demo"
    try? FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
    let total = Int((duration * fps).rounded())
    for index in 0..<total {
        let image = frame(Double(index) / fps)
        guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else { continue }
        try? data.write(to: URL(fileURLWithPath: String(format: "%@/frame-%04d.png", output, index)))
    }
    print("wrote \(total) frames to \(output)")
}

func newFrame() -> CGContext {
    let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                        bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setAllowsAntialiasing(true)
    return ctx
}
