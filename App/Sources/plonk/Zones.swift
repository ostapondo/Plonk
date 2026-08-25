import Foundation

// A zone set is a template of fractional rects (origin top-left, 0..1 of a
// screen's visible area). Sets are screen-agnostic; config assigns a set name
// per screen. User-defined sets live in config; built-ins are always available.

struct ZoneRect: Codable {
    var x: Double
    var y: Double
    var w: Double
    var h: Double

    init(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        self.x = x; self.y = y; self.w = w; self.h = h
    }

    init?(dict: [String: Any]) {
        guard let x = (dict["x"] as? NSNumber)?.doubleValue,
              let y = (dict["y"] as? NSNumber)?.doubleValue,
              let w = (dict["w"] as? NSNumber)?.doubleValue,
              let h = (dict["h"] as? NSNumber)?.doubleValue,
              w > 0, h > 0, x >= 0, y >= 0,
              x + w <= 1.0001, y + h <= 1.0001 else { return nil }
        self.x = x; self.y = y; self.w = w; self.h = h
    }

    var frac: FracRect { FracRect(x, y, w, h) }
    var asDict: [String: Double] { ["x": x, "y": y, "w": w, "h": h] }
}

enum BuiltinZoneSets {
    static let defaultName = "Halves"

    static let all: [String: [ZoneRect]] = [
        "Halves": [ZoneRect(0, 0, 0.5, 1), ZoneRect(0.5, 0, 0.5, 1)],
        "Thirds": [ZoneRect(0, 0, 1.0 / 3, 1), ZoneRect(1.0 / 3, 0, 1.0 / 3, 1), ZoneRect(2.0 / 3, 0, 1.0 / 3, 1)],
        "60 / 40": [ZoneRect(0, 0, 0.6, 1), ZoneRect(0.6, 0, 0.4, 1)],
        "Quarters": [
            ZoneRect(0, 0, 0.5, 0.5), ZoneRect(0.5, 0, 0.5, 0.5),
            ZoneRect(0, 0.5, 0.5, 0.5), ZoneRect(0.5, 0.5, 0.5, 0.5),
        ],
        "Priority": [ZoneRect(0, 0, 0.6, 1), ZoneRect(0.6, 0, 0.4, 0.5), ZoneRect(0.6, 0.5, 0.4, 0.5)],
    ]
}

// Pure zone-set math shared by the editor and covered by unit tests.
enum ZoneGeometry {
    static let grid = 0.05
    static let minSide = 0.1

    /// The frame a window ends up with: the fraction's share of the visible
    /// area, less the gap on every side.
    ///
    /// One function on purpose. A zone reached by ⌃⌥3 and the same zone reached
    /// over MCP have to land in the same place, and they did not: the agent path
    /// built this rect and placed the window without ever insetting it, so the
    /// gap was a setting that only worked when a person pressed the key.
    static func frame(for frac: FracRect, in visible: CGRect, gap: CGFloat = 0) -> CGRect {
        inset(CGRect(x: visible.minX + frac.x * visible.width,
                     y: visible.minY + frac.y * visible.height,
                     width: frac.w * visible.width,
                     height: frac.h * visible.height),
              by: gap)
    }

    /// The other way: where a frame sits as a share of the visible area. Nil
    /// when the area has no size to measure against. Not clamped; a window
    /// hanging over an edge reads as hanging over it, and the caller decides
    /// whether that is a fraction it will accept.
    static func fraction(of frame: CGRect, in visible: CGRect) -> FracRect? {
        guard visible.width > 0, visible.height > 0 else { return nil }
        return FracRect(Double((frame.minX - visible.minX) / visible.width),
                        Double((frame.minY - visible.minY) / visible.height),
                        Double(frame.width / visible.width),
                        Double(frame.height / visible.height))
    }

    /// Insets a rect by the zone gap without ever turning it inside out: a wide
    /// gap on a narrow zone would otherwise produce a null rect, and the window
    /// would be sent to an infinite origin.
    static func inset(_ rect: CGRect, by gap: CGFloat) -> CGRect {
        guard gap > 0, rect.width > 0, rect.height > 0 else { return rect }
        let minimumSide: CGFloat = 120
        let room = min(gap, max((rect.width - minimumSide) / 2, 0), max((rect.height - minimumSide) / 2, 0))
        return room > 0 ? rect.insetBy(dx: room, dy: room) : rect
    }

    /// Rounds to the grid, which is what a keyboard step and a click-split use:
    /// both want a tidy fraction rather than the exact pixel asked for.
    static func snapValue(_ v: Double) -> Double {
        (v / grid).rounded() * grid
    }

    /// The fractions a dragged divider is drawn to: halves, thirds, quarters,
    /// fifths and sixths of the screen.
    static let stops: [Double] = {
        var values: Set<Double> = []
        for parts in 2...6 {
            for step in 1..<parts { values.insert(Double(step) / Double(parts)) }
        }
        return values.sorted()
    }()

    /// Where a dragged edge lands: the nearest stop, or an edge another zone
    /// already keeps so columns line up, but only when one of them is within
    /// `tolerance`. Anything further away stays exactly where it was put.
    ///
    /// A magnet rather than a grid, because the editor used to round every edge
    /// to a twentieth of the screen once the mouse came up. On a 5120-point
    /// display that is a 256-point step: the divider jumped away from the
    /// pointer on release, and half the positions on the screen could not be
    /// asked for at all. Tolerance is in the same fractions as the value and
    /// the caller works it out from points, so the pull is the same distance on
    /// a laptop as on an ultrawide.
    static func magnet(_ value: Double, to edges: [Double] = [], tolerance: Double) -> Double {
        var best = value
        var closest = tolerance
        for candidate in stops + edges where abs(candidate - value) < closest {
            closest = abs(candidate - value)
            best = candidate
        }
        return best
    }

    /// Smallest rect covering both zones, which is what dropping a window
    /// across two of them means. Rounded up to a rectangle, so spanning an
    /// L-shaped pair takes the corner with it.
    static func union(_ a: ZoneRect, _ b: ZoneRect) -> FracRect {
        let x = min(a.x, b.x)
        let y = min(a.y, b.y)
        return FracRect(x, y, max(a.x + a.w, b.x + b.w) - x, max(a.y + a.h, b.y + b.h) - y)
    }

    /// The zone whose shared edge the cursor is hovering, so a drop can cover
    /// both without any modifier — the other way PowerToys lets two zones be
    /// taken at once.
    ///
    /// Tolerances are per axis because a fraction of a wide screen is not the
    /// same distance as a fraction of a tall one; the caller converts points
    /// into both. Nil when nothing else is close enough, which is the common
    /// case: this runs on every mouse event of a drag.
    static func neighbour(_ zones: [ZoneRect], of hovered: Int, atX x: Double, y: Double,
                          toleranceX: Double, toleranceY: Double) -> Int? {
        guard zones.indices.contains(hovered), toleranceX > 0 || toleranceY > 0 else { return nil }
        var best: (index: Int, distance: Double)?
        for (index, zone) in zones.enumerated() where index != hovered {
            let dx = max(zone.x - x, x - (zone.x + zone.w), 0)
            let dy = max(zone.y - y, y - (zone.y + zone.h), 0)
            guard dx <= toleranceX, dy <= toleranceY else { continue }
            // Normalized so the two axes can be compared at all.
            let distance = (toleranceX > 0 ? dx / toleranceX : 0) + (toleranceY > 0 ? dy / toleranceY : 0)
            if best == nil || distance < best!.distance { best = (index, distance) }
        }
        return best?.index
    }

    /// Which zone a saved frame came out of, by how much of the two rectangles
    /// is the same rectangle. Used to colour a workspace by the zones its
    /// windows return to: a desk stores frames, not zone numbers, so the number
    /// has to be read back off the geometry.
    ///
    /// Intersection over union rather than nearest centre: a window filling the
    /// whole screen has its centre inside every zone of a set, and picking one
    /// of them would be arbitrary. Below half the same rectangle it is nobody's
    /// zone, and saying so is better than colouring it a lie.
    static func nearest(to frame: FracRect, in zones: [ZoneRect]) -> Int? {
        var best: (index: Int, score: Double)?
        for (index, zone) in zones.enumerated() {
            let ix = min(zone.x + zone.w, frame.x + frame.w) - max(zone.x, frame.x)
            let iy = min(zone.y + zone.h, frame.y + frame.h) - max(zone.y, frame.y)
            guard ix > 0, iy > 0 else { continue }
            let intersection = ix * iy
            let union = zone.w * zone.h + frame.w * frame.h - intersection
            guard union > 0 else { continue }
            let score = intersection / union
            if best == nil || score > best!.score { best = (index, score) }
        }
        guard let best, best.score >= 0.5 else { return nil }
        return best.index
    }

    /// Which zones a spanning rect swallows, by centre point — the same test
    /// the drag overlay uses to pick one, so what lights up is what a drop
    /// would land on.
    static func covered(_ zones: [ZoneRect], by rect: FracRect) -> Set<Int> {
        Set(zones.indices.filter {
            let cx = zones[$0].x + zones[$0].w / 2
            let cy = zones[$0].y + zones[$0].h / 2
            return cx >= rect.x && cx <= rect.x + rect.w && cy >= rect.y && cy <= rect.y + rect.h
        })
    }

    /// True when any zone at the given indices intersects another zone by
    /// more than a hairline (touching edges are fine).
    static func overlaps(_ zones: [ZoneRect], at indices: [Int]) -> Bool {
        for index in indices where zones.indices.contains(index) {
            let z = zones[index]
            for (i, other) in zones.enumerated() where i != index {
                let ix = min(z.x + z.w, other.x + other.w) - max(z.x, other.x)
                let iy = min(z.y + z.h, other.y + other.h) - max(z.y, other.y)
                if ix > 0.001 && iy > 0.001 { return true }
            }
        }
        return false
    }

    /// Split a zone at a fractional position (snapped to the grid). Returns
    /// nil when the cut would leave either side under the minimum size.
    static func split(_ zones: [ZoneRect], at index: Int, fraction: Double, vertical: Bool) -> [ZoneRect]? {
        guard zones.indices.contains(index) else { return nil }
        let z = zones[index]
        var result = zones
        let cut = snapValue(fraction)
        if vertical {
            guard cut - z.x >= minSide, z.x + z.w - cut >= minSide else { return nil }
            result[index] = ZoneRect(z.x, z.y, cut - z.x, z.h)
            result.append(ZoneRect(cut, z.y, z.x + z.w - cut, z.h))
        } else {
            guard cut - z.y >= minSide, z.y + z.h - cut >= minSide else { return nil }
            result[index] = ZoneRect(z.x, z.y, z.w, cut - z.y)
            result.append(ZoneRect(z.x, cut, z.w, z.y + z.h - cut))
        }
        return result
    }

    /// Move or resize one zone by a step, for editing without a mouse.
    /// `resizing` grows the zone from its right and bottom edges instead of
    /// moving it. Returns nil when the result would leave the screen, fall
    /// under the minimum size, or land on top of another zone — the same rules
    /// the mouse is held to.
    static func adjust(_ zones: [ZoneRect], at index: Int, dx: Double, dy: Double,
                       resizing: Bool) -> [ZoneRect]? {
        guard zones.indices.contains(index) else { return nil }
        let z = zones[index]
        var result = zones
        if resizing {
            let w = snapValue(z.w + dx)
            let h = snapValue(z.h + dy)
            guard w >= minSide, h >= minSide, z.x + w <= 1.0001, z.y + h <= 1.0001 else { return nil }
            result[index] = ZoneRect(z.x, z.y, w, h)
        } else {
            let x = snapValue(z.x + dx)
            let y = snapValue(z.y + dy)
            guard x >= -0.0001, y >= -0.0001, x + z.w <= 1.0001, y + z.h <= 1.0001 else { return nil }
            result[index] = ZoneRect(max(x, 0), max(y, 0), z.w, z.h)
        }
        guard !overlaps(result, at: [index]) else { return nil }
        return result
    }

    /// Remove a zone and let cleanly abutting neighbors absorb the freed
    /// space (single neighbor or a full row/column of them). Falls back to
    /// leaving a gap when no clean fill exists.
    static func removeAndHeal(_ zones: [ZoneRect], at index: Int) -> [ZoneRect] {
        guard zones.indices.contains(index) else { return zones }
        let eps = 0.001
        let z = zones[index]
        var result = zones
        result.remove(at: index)

        struct Direction {
            let matches: (ZoneRect) -> Bool
            let span: (ZoneRect) -> Double
            let target: Double
            let expand: (inout ZoneRect) -> Void
        }
        let directions: [Direction] = [
            Direction(matches: { abs($0.x + $0.w - z.x) < eps && $0.y >= z.y - eps && $0.y + $0.h <= z.y + z.h + eps },
                      span: { $0.h }, target: z.h, expand: { $0.w += z.w }),
            Direction(matches: { abs($0.x - (z.x + z.w)) < eps && $0.y >= z.y - eps && $0.y + $0.h <= z.y + z.h + eps },
                      span: { $0.h }, target: z.h, expand: { $0.x -= z.w; $0.w += z.w }),
            Direction(matches: { abs($0.y + $0.h - z.y) < eps && $0.x >= z.x - eps && $0.x + $0.w <= z.x + z.w + eps },
                      span: { $0.w }, target: z.w, expand: { $0.h += z.h }),
            Direction(matches: { abs($0.y - (z.y + z.h)) < eps && $0.x >= z.x - eps && $0.x + $0.w <= z.x + z.w + eps },
                      span: { $0.w }, target: z.w, expand: { $0.y -= z.h; $0.h += z.h }),
        ]
        for direction in directions {
            let indices = result.indices.filter { direction.matches(result[$0]) }
            let covered = indices.reduce(0.0) { $0 + direction.span(result[$1]) }
            if !indices.isEmpty && abs(covered - direction.target) < 0.01 {
                for i in indices { direction.expand(&result[i]) }
                return result
            }
        }
        return result
    }
}
