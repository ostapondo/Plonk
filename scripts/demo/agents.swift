// docs/agents.gif — the picture at the top of docs/agents.md.
//
// The part that page opens by claiming no other Mac window manager has: the
// whole surface over MCP. Four sentences and six real tools — get_state,
// apply_layout, save_workspace, set_awake, launch_workspace, extract_text —
// with the tool row ticking each one off and Plonk's own top-right notice
// confirming it.
//
// The middle beat is the one worth the seconds: the desk is saved, closed to
// nothing, and rebuilt from the workspace. Windows appear first and jump into
// place a moment later, because that is what macOS actually does — an app
// cannot be opened straight into a position.

themeBlend = 0

let margin: CGFloat = 24
desk = CGRect(x: margin, y: 156, width: size.width - margin * 2,
              height: (size.height - 34 - margin) - 156)

let gap: CGFloat = 5

/// "browser left 60%, terminal, notes and mail down the right" — the fractions
/// that sentence turns into, origin top-left, exactly as apply_layout takes
/// them.
let set = [
    Frac(x: 0, y: 0, w: 0.6, h: 1),
    Frac(x: 0.6, y: 0, w: 0.4, h: 0.34),
    Frac(x: 0.6, y: 0.34, w: 0.4, h: 0.33),
    Frac(x: 0.6, y: 0.67, w: 0.4, h: 0.33),
]

let green = rgb(0.36, 0.85, 0.55)
let pink = rgb(1.0, 0.45, 0.62)

struct Item {
    var title: String
    var tint: NSColor
    var body: Body
    var messy: CGRect
    var zone: Int
}

let items = [
    Item(title: "Safari", tint: Ink.accent, body: .browser,
         messy: CGRect(x: 178, y: 268, width: 604, height: 392), zone: 0),
    Item(title: "Terminal", tint: green, body: .terminal,
         messy: CGRect(x: 520, y: 214, width: 552, height: 336), zone: 1),
    Item(title: "Notes", tint: Ink.amber, body: .notes,
         messy: CGRect(x: 92, y: 176, width: 470, height: 310), zone: 2),
    Item(title: "Mail", tint: pink, body: .mail,
         messy: CGRect(x: 690, y: 320, width: 494, height: 330), zone: 3),
]

// MARK: - The tool row

/// Every tool the sentences reach for, in the order they are called. Dim until
/// its moment, then accent with a tick — the row doubles as a table of contents
/// for the nineteen the server actually exposes.
let tools: [(name: String, at: Double)] = [
    ("get_state", 2.2),
    ("apply_layout", 2.5),
    ("save_workspace", 6.05),
    ("set_awake", 6.3),
    ("launch_workspace", 9.6),
    ("extract_text", 12.8),
]

func drawTools(at t: Double, alpha: CGFloat, in ctx: CGContext) {
    faded(alpha, in: ctx) {
        let widths = tools.map { width(of: $0.name, size: 13, weight: .medium, mono: true) + 44 }
        let total = widths.reduce(0, +) + CGFloat(tools.count - 1) * 8
        var x = size.width / 2 - total / 2
        for (index, tool) in tools.enumerated() {
            let live = phase(t, from: tool.at, to: tool.at + 0.3)
            let chip = CGRect(x: x, y: 116, width: widths[index], height: 28)
            fill(chip, mix(Ink.faint, Ink.accent.withAlphaComponent(0.92), live), radius: 8, in: ctx)
            stroke(chip, mix(Ink.line, Ink.accent, live), radius: 8, in: ctx)
            // A tick that draws itself as the call returns.
            let mark = CGPoint(x: chip.minX + 15, y: chip.midY)
            ctx.saveGState()
            ctx.setStrokeColor(mix(Ink.dim, .white, live).cgColor)
            ctx.setLineWidth(2)
            ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: mark.x - 5, y: mark.y))
            ctx.addLine(to: CGPoint(x: mark.x - 1.5, y: mark.y - 3.5 * live))
            ctx.addLine(to: CGPoint(x: mark.x + 5, y: mark.y + 4.5 * live))
            ctx.strokePath()
            ctx.restoreGState()
            text(tool.name, at: CGPoint(x: chip.minX + 28, y: chip.midY - 5), size: 13,
                 color: mix(Ink.dim, .white, live), weight: .medium, mono: true, in: ctx)
            x += widths[index] + 8
        }
    }
}

// MARK: - Plonk's notice

/// The panel in the top-right corner — the app's own, not Notification Center.
/// Slots stack downward, because two tools can return at once.
func drawNotice(_ title: String, _ detail: String, tint: NSColor, slot: Int,
                alpha: Double, slide: Double, in ctx: CGContext) {
    faded(CGFloat(alpha), in: ctx) {
        let box = CGRect(x: size.width - 24 - 348 + CGFloat(1 - slide) * 44,
                         y: size.height - 34 - 18 - 60 - CGFloat(slot) * 70, width: 348, height: 60)
        panel(box, radius: 13, border: Ink.line, blur: 26, in: ctx)
        fill(CGRect(x: box.minX, y: box.minY + 12, width: 3, height: box.height - 24), tint,
             radius: 1.5, in: ctx)
        drawCube(at: CGPoint(x: box.minX + 30, y: box.midY), scale: 1, glow: 0, in: ctx)
        text(title, at: CGPoint(x: box.minX + 52, y: box.midY + 3), size: 14.5, color: Ink.text,
             weight: .semibold, in: ctx)
        text(detail, at: CGPoint(x: box.minX + 52, y: box.midY - 17), size: 12.5, color: Ink.dim,
             in: ctx)
    }
}

/// The marquee extract_text draws round the region it read, with the words it
/// lifted out shown under it.
func drawExtract(_ region: CGRect, line: String, progress: Double, alpha: Double,
                 in ctx: CGContext) {
    faded(CGFloat(alpha), in: ctx) {
        fill(region, Ink.accent.withAlphaComponent(0.2), radius: 5, in: ctx)
        stroke(region, Ink.accent, radius: 5, width: 2, in: ctx)
        for corner in [CGPoint(x: region.minX, y: region.minY), CGPoint(x: region.maxX, y: region.minY),
                       CGPoint(x: region.minX, y: region.maxY), CGPoint(x: region.maxX, y: region.maxY)] {
            fill(CGRect(x: corner.x - 4, y: corner.y - 4, width: 8, height: 8), Ink.accent,
                 radius: 4, in: ctx)
        }
        let box = CGRect(x: region.minX, y: region.minY - 56,
                         width: width(of: line, size: 15, mono: true) + 36, height: 40)
        panel(box, radius: 10, border: Ink.accent.withAlphaComponent(0.55), lift: 6, blur: 20, in: ctx)
        text(typed(line, progress), at: CGPoint(x: box.minX + 18, y: box.midY - 6), size: 15,
             color: Ink.text, mono: true, in: ctx)
    }
}

// MARK: - The frame

let duration = 16.1

/// Beat 3: everything closes, and the workspace opens it again from nothing.
let vanish = (from: 8.9, to: 9.35)
let reopen = 9.75
/// Where a freshly launched window lands before Plonk moves it. macOS cannot
/// open an app straight into a position, so the jump is the honest picture.
func fresh(_ index: Int) -> CGRect {
    CGRect(x: desk.midX - 300 + CGFloat(index) * 34, y: desk.midY - 150 - CGFloat(index) * 26,
           width: 560, height: 360)
}

func frame(at t: Double) -> CGImage {
    let ctx = newFrame()
    drawDesk(in: ctx)
    // set_awake changes the menu bar rather than the desk, so the cube picks up
    // a ring the moment the call returns and keeps it for the rest of the run.
    drawCube(at: CGPoint(x: size.width - 112, y: size.height - 17), scale: 1,
             glow: phase(t, from: 6.3, to: 6.6), in: ctx)

    for (index, item) in items.enumerated() {
        let home = set[item.zone].rect.insetBy(dx: gap, dy: gap)
        var rect = lerp(item.messy, home, settle(t, from: 2.6 + Double(index) * 0.12,
                                                 to: 3.45 + Double(index) * 0.12))
        var alpha = 1.0
        var recede = t < 2.6 ? 0.09 * Double(index) : 0

        // Closed, then launched again: the window appears where macOS put it and
        // jumps to its frame a moment later.
        let closing = phase(t, from: vanish.from, to: vanish.to)
        let opens = reopen + Double(index) * 0.14
        let opened = phase(t, from: opens, to: opens + 0.16)
        if t >= vanish.from {
            rect = lerp(fresh(index), home, settle(t, from: opens + 0.3, to: opens + 0.95))
            alpha = opened
            if t < vanish.to + 0.05 {
                rect = lerp(home, home.insetBy(dx: home.width * 0.06, dy: home.height * 0.06),
                            closing)
                alpha = 1 - closing
            }
            recede = 0
        }
        draw(Pane(title: item.title, rect: rect, tint: item.tint, body: item.body, recede: recede),
             alpha: CGFloat(alpha), in: ctx)
    }

    // The zone set the sentence resolved to, flashed over the move so the
    // rearrangement reads as a layout and not as four windows deciding to go.
    drawZones(set.map(\.rect), highlighted: [], alpha: CGFloat(pulse(t, 2.5, 2.7, 3.9, 4.2)),
              numbers: false, in: ctx)

    // Beat 4: the region read off the screen, and the words that came back.
    let terminal = set[1].rect
    drawExtract(CGRect(x: terminal.minX + 40, y: terminal.midY - 13,
                       width: terminal.width - 100, height: 26),
                line: "error: assertion failed at line 42",
                progress: phase(t, from: 13.0, to: 13.7),
                alpha: pulse(t, 12.8, 13.0, 14.6, 14.9), in: ctx)

    // Four sentences, each replacing the last in the same bar. Written the way
    // someone would type them, not as commands.
    let lines: [(String, Double, Double, Double)] = [
        ("browser left 60%, terminal, notes and mail down the right", 0.4, 0.7, 3.9),
        ("save this as “review”, keep awake till the build ends", 4.1, 4.35, 7.5),
        ("close it all, then launch review", 7.7, 7.95, 11.4),
        ("read the error out of the terminal", 11.6, 11.85, 14.7),
    ]
    for (line, appear, typeFrom, leave) in lines {
        drawPrompt(line, progress: phase(t, from: typeFrom,
                                         to: typeFrom + Double(line.count) * 0.024),
                   alpha: CGFloat(pulse(t, appear, appear + 0.2, leave, leave + 0.25)),
                   frame: CGRect(x: size.width / 2 - 396, y: 42, width: 792, height: 64),
                   label: "Claude Code", in: ctx)
    }

    drawTools(at: t, alpha: CGFloat(pulse(t, 0.3, 0.7, 15.0, 15.3)), in: ctx)

    // One notice per call, in the corner the app puts them in.
    let notices: [(String, String, NSColor, Int, Double)] = [
        ("Layout applied", "4 windows across 1 screen", Ink.accent, 0, 2.8),
        ("Workspace saved", "“review” — 4 apps, 4 frames", green, 0, 6.15),
        ("Keeping awake", "until “npm run build” exits", Ink.amber, 1, 6.45),
        ("Workspace launched", "“review” — rebuilt from nothing", Ink.accent, 0, 10.9),
        ("Text copied", "34 characters, read on-device", Ink.accent, 0, 13.8),
    ]
    for (title, detail, tint, slot, at) in notices {
        drawNotice(title, detail, tint: tint, slot: slot,
                   alpha: pulse(t, at, at + 0.25, at + 1.8, at + 2.1),
                   slide: phase(t, from: at, to: at + 0.35), in: ctx)
    }

    drawCaption("Nineteen tools. A desk in a sentence.",
                "Plonk — the Mac window manager your agent can drive.",
                alpha: CGFloat(pulse(t, 15.0, 15.3, 15.85, 16.1)), at: 84, in: ctx)

    return ctx.makeImage()!
}

render(duration: duration, frame)
