// docs/demo.gif — the README's hero.
//
// "Three ways to put a window somewhere", which is the README's own headline,
// animated: the same job done by dragging, by a key, by voice, and then by an
// agent. One zone set for the whole run, so the eye never has to relearn the
// screen; each beat places exactly one window, and the desk is finished when
// the sentence lands.
//
// Dark throughout, and no theme switch — a loop that flashes white every twelve
// seconds is the first thing anyone notices about a README GIF, and it is not
// the thing worth noticing.

themeBlend = 0

let margin: CGFloat = 24
desk = CGRect(x: margin, y: 132, width: size.width - margin * 2,
              height: (size.height - 34 - margin) - 132)

let gap: CGFloat = 5

/// Five zones, big enough that each one still shows a window rather than a
/// swatch. Numbered the way the overlay numbers them.
let set = [
    Frac(x: 0, y: 0, w: 0.44, h: 1),
    Frac(x: 0.44, y: 0, w: 0.32, h: 0.56),
    Frac(x: 0.44, y: 0.56, w: 0.32, h: 0.44),
    Frac(x: 0.76, y: 0, w: 0.24, h: 0.5),
    Frac(x: 0.76, y: 0.5, w: 0.24, h: 0.5),
]
let zoneRects = set.map(\.rect)

/// The pile the app exists to end: five windows, cascaded, two of them running
/// off the edge of the screen.
struct Item {
    var title: String
    var tint: NSColor
    var body: Body
    var messy: CGRect
    var zone: Int
    var from: Double
    var to: Double
}

let violet = rgb(0.68, 0.55, 1.0)
let green = rgb(0.36, 0.85, 0.55)
let teal = rgb(0.30, 0.80, 0.82)
let pink = rgb(1.0, 0.45, 0.62)

let items = [
    Item(title: "Safari", tint: Ink.accent, body: .browser,
         messy: CGRect(x: 150, y: 246, width: 620, height: 404), zone: 0, from: 1.15, to: 2.6),
    Item(title: "Xcode", tint: violet, body: .code,
         messy: CGRect(x: 372, y: 186, width: 660, height: 424), zone: 1, from: 3.75, to: 4.45),
    Item(title: "Terminal", tint: green, body: .terminal,
         messy: CGRect(x: 604, y: 140, width: 540, height: 322), zone: 2, from: 6.25, to: 6.95),
    Item(title: "Messages", tint: teal, body: .chat,
         messy: CGRect(x: 44, y: 152, width: 452, height: 306), zone: 3, from: 9.0, to: 9.8),
    Item(title: "Mail", tint: pink, body: .mail,
         messy: CGRect(x: 742, y: 296, width: 486, height: 344), zone: 4, from: 9.15, to: 9.95),
]

// MARK: - The two devices that live in the bottom-right of the stage

/// Hold-to-talk, as the HUD shows it: a live level meter and the words as they
/// are recognised. Bars are a function of t, so the meter moves without any
/// state carried between frames.
func drawVoice(_ heard: String, progress: Double, at t: Double, alpha: CGFloat, in ctx: CGContext) {
    faded(alpha, in: ctx) {
        let box = CGRect(x: size.width - 46 - 470, y: 40, width: 470, height: 64)
        panel(box, radius: 32, border: Ink.accent.withAlphaComponent(0.5), borderWidth: 1.5, in: ctx)

        // The mic: a capsule with a stand, small enough to read as an icon.
        let mic = CGPoint(x: box.minX + 34, y: box.midY)
        fill(CGRect(x: mic.x - 6, y: mic.y - 3, width: 12, height: 18), Ink.accent, radius: 6, in: ctx)
        fill(CGRect(x: mic.x - 1.5, y: mic.y - 13, width: 3, height: 8), Ink.accent, radius: 1.5, in: ctx)
        fill(CGRect(x: mic.x - 8, y: mic.y - 13, width: 16, height: 3), Ink.accent, radius: 1.5, in: ctx)

        for index in 0..<9 {
            let level = 0.35 + 0.65 * abs(sin(t * 7.5 + Double(index) * 0.85))
            let height = CGFloat(7 + 21 * level) * (progress < 1 ? 1 : 0.35)
            fill(CGRect(x: box.minX + 62 + CGFloat(index) * 8, y: box.midY - height / 2,
                        width: 3.5, height: height),
                 Ink.accent.withAlphaComponent(0.75), radius: 1.75, in: ctx)
        }
        text("“\(typed(heard, progress))”", at: CGPoint(x: box.minX + 148, y: box.midY - 7),
             size: 18, color: Ink.text, weight: .medium, in: ctx)
    }
}

// MARK: - The frame

let duration = 12.4

func frame(at t: Double) -> CGImage {
    let ctx = newFrame()
    drawDesk(in: ctx)

    // Beat 1 (1.15-2.6): dragged by hand. The window keeps its size while it
    // travels and only takes the zone's shape on the drop, which is what a real
    // drag looks like — snapping early would be a lie about the interaction.
    let carry = phase(t, from: 1.15, to: 2.2)
    let hover = CGRect(x: zoneRects[0].midX - items[0].messy.width / 2,
                       y: zoneRects[0].midY - items[0].messy.height / 2,
                       width: items[0].messy.width, height: items[0].messy.height)
    let drop = settle(t, from: 2.2, to: 2.6)

    let placed = items.map { phase(t, from: $0.from, to: $0.to) }
    var rects = items.enumerated().map { index, item -> CGRect in
        if index == 0 {
            return lerp(lerp(item.messy, hover, carry), zoneRects[0].insetBy(dx: gap, dy: gap), drop)
        }
        return lerp(item.messy, zoneRects[item.zone].insetBy(dx: gap, dy: gap),
                    settle(t, from: item.from, to: item.to))
    }
    // Nothing left on the pile after the last beat, so the closing frames are
    // the finished desk and not a caption over a mess.
    if t > 10.2 { rects[0] = zoneRects[0].insetBy(dx: gap, dy: gap) }

    // Back to front: the pile in reverse order so the next window to move is on
    // top of it, then whatever has landed, then whatever is in flight.
    let order = items.indices.sorted { a, b in
        func layer(_ index: Int) -> Int {
            if placed[index] >= 1 { return 0 }
            return placed[index] > 0 ? 2 : 1
        }
        return layer(a) == layer(b) ? a > b : layer(a) < layer(b)
    }
    for index in order {
        draw(Pane(title: items[index].title, rect: rects[index], tint: items[index].tint,
                  body: items[index].body,
                  // On the pile the ones further down are a shade darker, so
                  // five overlapping windows read as a stack with a depth.
                  recede: placed[index] > 0 ? 0 : 0.1 * Double(index)),
             in: ctx)
    }

    // The overlay, shown exactly when the app shows it: while a window is being
    // placed, with the zone it is going to lit.
    let overlays: [(Double, Double, Double, Double, Set<Int>)] = [
        (1.3, 1.5, 2.55, 2.85, [0]),
        (3.45, 3.6, 4.5, 4.8, [1]),
        (5.95, 6.1, 7.0, 7.3, [2]),
        (8.7, 8.85, 9.95, 10.25, [3, 4]),
    ]
    for (inFrom, inTo, outFrom, outTo, lit) in overlays {
        drawZones(zoneRects, highlighted: t > inFrom + 0.35 ? lit : [],
                  alpha: CGFloat(pulse(t, inFrom, inTo, outFrom, outTo)), in: ctx)
    }

    // The pointer: over to the window, then riding its title bar to the zone.
    let cursorAlpha = pulse(t, 0.35, 0.6, 2.7, 2.95)
    let approach = phase(t, from: 0.5, to: 1.15)
    let gripStart = CGPoint(x: items[0].messy.midX - 70, y: items[0].messy.maxY - 15)
    let grip = CGPoint(x: rects[0].midX - 70 * (rects[0].width / items[0].messy.width),
                       y: rects[0].maxY - 15)
    drawCursor(at: CGPoint(x: lerp(size.width - 210, gripStart.x, approach),
                           y: lerp(size.height - 190, gripStart.y, approach)),
               alpha: CGFloat(cursorAlpha) * CGFloat(1 - carry), in: ctx)
    drawCursor(at: grip, alpha: CGFloat(cursorAlpha) * CGFloat(carry), in: ctx)

    // Beat 2: the shortcut that placed the second window.
    drawKeys(["⌃", "⌥", "2"], centeredAt: CGPoint(x: size.width - 280, y: 46),
             alpha: CGFloat(pulse(t, 3.45, 3.65, 4.9, 5.15)), in: ctx)

    // Beat 3: hold-to-talk.
    drawVoice("zone three", progress: phase(t, from: 5.95, to: 6.55), at: t,
              alpha: CGFloat(pulse(t, 5.6, 5.85, 7.4, 7.65)), in: ctx)

    // Beat 4: the agent, which is the one no other Mac window manager has.
    // Right-aligned in the stage so it shares the band with the chapter label
    // rather than covering it.
    drawPrompt("messages top right, mail under it",
               progress: phase(t, from: 8.0, to: 8.85),
               alpha: CGFloat(pulse(t, 7.75, 8.0, 10.2, 10.45)),
               frame: CGRect(x: size.width - 46 - 616, y: 40, width: 616, height: 64), in: ctx)

    // The chapter label rides the bottom-left of the stage the whole way, so
    // there is never a moment where the picture is unlabelled.
    let chapters: [(Double, Double, String, String, String)] = [
        (0.35, 2.95, "Drag it", "Zones light up as you move a window", "One"),
        (3.05, 5.3, "Press a key", "⌃⌥1–9 for the numbered zones on this screen", "Two"),
        (5.4, 7.6, "Say it", "Hold ⌃⌥V and name where it goes — on-device", "Three"),
        (7.7, 10.5, "Or ask your agent", "Plonk speaks MCP: a whole desk in one sentence", "And"),
    ]
    for (start, end, title, sub, step) in chapters {
        drawChapter(step, title, sub,
                    alpha: CGFloat(pulse(t, start, start + 0.25, end, end + 0.22)),
                    rise: phase(t, from: start, to: start + 0.35), in: ctx)
    }

    drawCaption("Three ways to put a window anywhere.",
                "Plonk — zones you draw yourself, and your agent can drive.",
                alpha: CGFloat(pulse(t, 10.7, 11.0, 12.2, 12.4)), at: 84, in: ctx)

    return ctx.makeImage()!
}

render(duration: duration, frame)
