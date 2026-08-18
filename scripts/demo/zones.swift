// docs/zones.gif — the picture at the top of docs/zones.md.
//
// What that page is about, as an action rather than a result: the zones are
// yours, cut by hand in a few clicks, and a whole set can be swapped under the
// windows already sitting in it.
//
// Light throughout, and deliberately so. The app has a theme of its own, the
// hero above it is dark, and two dark animations in a row on one page read as
// the same picture twice.

themeBlend = 1

let margin: CGFloat = 24
desk = CGRect(x: margin, y: 132, width: size.width - margin * 2,
              height: (size.height - 34 - margin) - 132)

let gap: CGFloat = 5

// MARK: - Five clicks

/// One click in the editor: where the pointer is, and whether ⇧ was down. A
/// plain click cuts across, ⇧ cuts down the way — the same two the editor has,
/// at the same place the pointer is. Written as clicks rather than as six
/// rectangles so the layout cannot drift into one the editor could not make.
struct Split {
    var at: Double
    var x: Double
    var y: Double
    var vertical: Bool
}

let splits = [
    Split(at: 0.95, x: 0.56, y: 0.45, vertical: true),
    Split(at: 1.55, x: 0.78, y: 0.50, vertical: false),
    Split(at: 2.15, x: 0.30, y: 0.62, vertical: false),
    Split(at: 2.75, x: 0.28, y: 0.82, vertical: true),
    Split(at: 3.35, x: 0.80, y: 0.25, vertical: false),
]
let splitTime = 0.26

struct Stage {
    var zones: [Frac]
    var parent: Frac
    var first: Frac
    var second: Frac
}

let stages: [Stage] = {
    var zones = [Frac(x: 0, y: 0, w: 1, h: 1)]
    var result: [Stage] = []
    for split in splits {
        guard let index = zones.firstIndex(where: { $0.contains(split.x, split.y) }) else { continue }
        let parent = zones[index]
        let first: Frac, second: Frac
        if split.vertical {
            let cut = split.x - parent.x
            first = Frac(x: parent.x, y: parent.y, w: cut, h: parent.h)
            second = Frac(x: split.x, y: parent.y, w: parent.w - cut, h: parent.h)
        } else {
            let cut = split.y - parent.y
            first = Frac(x: parent.x, y: parent.y, w: parent.w, h: cut)
            second = Frac(x: parent.x, y: split.y, w: parent.w, h: parent.h - cut)
        }
        zones.replaceSubrange(index...index, with: [first, second])
        result.append(Stage(zones: zones, parent: parent, first: first, second: second))
    }
    return result
}()

let drawn = stages.last!.zones
let zoneRects = drawn.map(\.rect)

/// The draft as it stands at `t`, with the split in progress half-done: the
/// half that keeps the origin shrinks into place, the other grows out of the
/// line the click drew.
func draftZones(at t: Double) -> [CGRect] {
    guard let index = splits.lastIndex(where: { t >= $0.at }) else {
        return [Frac(x: 0, y: 0, w: 1, h: 1).rect]
    }
    let stage = stages[index]
    let progress = phase(t, from: splits[index].at, to: splits[index].at + splitTime)
    guard progress < 1 else { return stage.zones.map(\.rect) }
    let sliver = splits[index].vertical
        ? Frac(x: stage.second.x, y: stage.second.y, w: 0.001, h: stage.second.h)
        : Frac(x: stage.second.x, y: stage.second.y, w: stage.second.w, h: 0.001)
    return stage.zones.map { zone in
        if zone.x == stage.first.x, zone.y == stage.first.y, zone.w == stage.first.w {
            return lerp(stage.parent.rect, stage.first.rect, progress)
        }
        if zone.x == stage.second.x, zone.y == stage.second.y {
            return lerp(sliver.rect, stage.second.rect, progress)
        }
        return zone.rect
    }
}

/// Where the pointer is during the editor beat: at the next click, having
/// travelled there from the last one.
func editorCursor(at t: Double) -> (point: CGPoint, shift: Bool) {
    var previous = CGPoint(x: desk.midX + 210, y: desk.minY + 90)
    for (index, split) in splits.enumerated() {
        let target = CGPoint(x: desk.minX + desk.width * split.x,
                             y: desk.maxY - desk.height * split.y)
        if t < split.at {
            let start = index == 0 ? 0.35 : splits[index - 1].at + splitTime
            let travel = phase(t, from: start, to: split.at)
            return (CGPoint(x: lerp(previous.x, target.x, travel),
                            y: lerp(previous.y, target.y, travel)), split.vertical)
        }
        previous = target
    }
    return (previous, false)
}

/// The editor: the screen dimmed, the draft on top, and the panel that names
/// the set and says what a click does.
func drawEditor(at t: Double, alpha: CGFloat, in ctx: CGContext) {
    faded(alpha, in: ctx) {
        fill(CGRect(origin: .zero, size: size), NSColor.black.withAlphaComponent(0.34), in: ctx)
        for zone in draftZones(at: t) {
            fill(zone.insetBy(dx: 3, dy: 3), Ink.accent.withAlphaComponent(0.22), radius: 9, in: ctx)
            stroke(zone.insetBy(dx: 3, dy: 3), Ink.accent.withAlphaComponent(0.95), radius: 9,
                   width: 2.5, in: ctx)
        }

        let card = CGRect(x: size.width / 2 - 300, y: 30, width: 600, height: 84)
        panel(card, radius: 14, border: Ink.line, shadow: NSColor.black.withAlphaComponent(0.4), in: ctx)
        text("Zone set — “Deep work”", at: CGPoint(x: card.minX + 24, y: card.maxY - 34),
             size: 18, color: Ink.text, weight: .semibold, in: ctx)
        text("Click a zone to split it · ⇧-click to split the other way",
             at: CGPoint(x: card.minX + 24, y: card.minY + 22), size: 14.5, color: Ink.dim, in: ctx)
        let save = CGRect(x: card.maxX - 156, y: card.midY - 19, width: 132, height: 38)
        // The button presses itself at the end of the beat, so the set applying has
        // a cause on screen.
        let press = pulse(t, 3.85, 3.95, 4.05, 4.15)
        fill(save, Ink.accent.withAlphaComponent(0.92 - 0.25 * press), radius: 9, in: ctx)
        text("Save & Apply", at: CGPoint(x: save.midX, y: save.midY - 6), size: 14.5,
             color: .white, weight: .semibold, align: .centre, in: ctx)
    }
}

/// The ⇧ badge that rides the pointer when the next click is a vertical split.
func drawShiftBadge(at point: CGPoint, alpha: CGFloat, in ctx: CGContext) {
    faded(alpha, in: ctx) {
        let badge = CGRect(x: point.x + 24, y: point.y - 50, width: 36, height: 32)
        fill(badge, Ink.panel, radius: 8, in: ctx)
        stroke(badge, Ink.line, radius: 8, in: ctx)
        text("⇧", at: CGPoint(x: badge.midX, y: badge.midY - 8), size: 17, color: Ink.text,
             weight: .semibold, align: .centre, in: ctx)
    }
}

// MARK: - The windows

let violet = rgb(0.55, 0.42, 0.95)
let green = rgb(0.20, 0.68, 0.42)
let teal = rgb(0.13, 0.60, 0.66)
let pink = rgb(0.90, 0.32, 0.50)
let orange = rgb(0.93, 0.55, 0.16)

struct Item {
    var title: String
    var tint: NSColor
    var body: Body
    var messy: CGRect
    var from: Double
}

/// Six windows on a pile, and six zones just cut for them. They go in the order
/// the splits made the zones, one every fifth of a second, which is what one
/// apply_layout call looks like.
let items = [
    Item(title: "Safari", tint: Ink.accent, body: .browser,
         messy: CGRect(x: 168, y: 254, width: 596, height: 388), from: 4.5),
    Item(title: "Finder", tint: teal, body: .files,
         messy: CGRect(x: 62, y: 172, width: 452, height: 300), from: 4.68),
    Item(title: "Notes", tint: orange, body: .notes,
         messy: CGRect(x: 286, y: 148, width: 470, height: 304), from: 4.86),
    Item(title: "Numbers", tint: green, body: .chart,
         messy: CGRect(x: 690, y: 306, width: 482, height: 330), from: 5.04),
    Item(title: "Messages", tint: pink, body: .chat,
         messy: CGRect(x: 560, y: 196, width: 440, height: 316), from: 5.22),
    Item(title: "Xcode", tint: violet, body: .code,
         messy: CGRect(x: 392, y: 262, width: 640, height: 400), from: 5.40),
]

/// The set ⌃⌥⇧2 switches to. Four zones and six windows, so the last two stack
/// behind the first two — offset the way the app offsets windows sharing a
/// zone, and `⌃⌥\`` cycles them.
let focus = [
    Frac(x: 0, y: 0, w: 0.62, h: 1),
    Frac(x: 0.62, y: 0, w: 0.38, h: 0.34),
    Frac(x: 0.62, y: 0.34, w: 0.38, h: 0.33),
    Frac(x: 0.62, y: 0.67, w: 0.38, h: 0.33),
]

// MARK: - The frame

let duration = 12.3

func frame(at t: Double) -> CGImage {
    let ctx = newFrame()
    drawDesk(in: ctx)

    // Beat 4 (7.9-9.2): the whole set is swapped under the windows already in
    // it. Windows sitting in a numbered zone move to wherever that number is in
    // the new set, which is exactly what the app does.
    let switching = settle(t, from: 7.9, to: 9.2)

    let placed = items.map { settle(t, from: $0.from, to: $0.from + 0.85) }
    let panes = items.enumerated().map { index, item -> Pane in
        var rect = lerp(item.messy, zoneRects[index].insetBy(dx: gap, dy: gap), placed[index])
        if switching > 0 {
            // Two windows share a zone, so the one behind is offset far enough
            // to be visibly there — `⌃⌥`` cycles them — rather than hidden.
            let step = CGFloat(index / focus.count) * 26
            rect = lerp(rect, focus[index % focus.count].rect
                .insetBy(dx: gap, dy: gap).offsetBy(dx: step, dy: -step), switching)
        }
        return Pane(title: item.title, rect: rect, tint: item.tint, body: item.body,
                    recede: placed[index] > 0 ? 0 : 0.06 * Double(index))
    }
    // Back to front: the pile in reverse, then what has landed, then what is in
    // flight. Once the sets swap, the stacked copies go behind the four that own
    // a zone.
    let order = panes.indices.sorted { a, b in
        func layer(_ index: Int) -> Int {
            if switching > 0.01 { return index < focus.count ? 1 : 0 }
            if placed[index] <= 0 { return 0 }
            return placed[index] >= 1 ? 1 : 2
        }
        return layer(a) == layer(b) ? a > b : layer(a) < layer(b)
    }
    for index in order { draw(panes[index], in: ctx) }

    // Beat 1 (0.3-4.25): the grid gets cut, five clicks, over the pile it is
    // about to sort out.
    let editing = pulse(t, 0.3, 0.55, 4.15, 4.4)
    drawEditor(at: t, alpha: CGFloat(editing), in: ctx)

    // Beat 3: the set, lit as each window lands in it.
    var landing: Set<Int> = []
    for (index, item) in items.enumerated() where t >= item.from && t < item.from + 0.85 {
        landing.insert(index)
    }
    drawZones(zoneRects, highlighted: landing, alpha: CGFloat(pulse(t, 4.3, 4.5, 6.3, 6.7)),
              in: ctx)
    // And once more over the new set, so the switch reads as a set arriving and
    // not as six windows deciding to move.
    drawZones(focus.map(\.rect), highlighted: [],
              alpha: CGFloat(pulse(t, 7.75, 7.95, 9.1, 9.5)), in: ctx)

    if editing > 0.01 {
        let (point, shift) = editorCursor(at: t)
        for split in splits {
            drawClick(at: CGPoint(x: desk.minX + desk.width * split.x,
                                  y: desk.maxY - desk.height * split.y),
                      progress: phase(t, from: split.at, to: split.at + 0.35), in: ctx)
        }
        drawShiftBadge(at: point, alpha: CGFloat(editing) * (shift ? 1 : 0), in: ctx)
        drawCursor(at: point, alpha: CGFloat(editing), in: ctx)
    }

    // Beat 4: the shortcut that swapped the set.
    drawKeys(["⌃", "⌥", "⇧", "2"], centeredAt: CGPoint(x: size.width / 2, y: 46),
             alpha: CGFloat(pulse(t, 7.55, 7.75, 9.4, 9.7)), in: ctx)

    drawCaption("Cut your own zones. Swap the whole set.",
                "Five clicks, per monitor — and the windows already in it follow.",
                alpha: CGFloat(pulse(t, 5.9, 6.2, 7.35, 7.6)), at: 84, in: ctx)
    drawCaption("Plonk",
                "A Mac window manager with zones you draw — and an agent can drive.",
                alpha: CGFloat(pulse(t, 9.8, 10.15, 12.0, 12.3)), at: 84, in: ctx)

    return ctx.makeImage()!
}

render(duration: duration, frame)
