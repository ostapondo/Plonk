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

    static func grid(columns: Int, rows: Int) -> [ZoneRect] {
        let cols = max(1, columns), rws = max(1, rows)
        var zones: [ZoneRect] = []
        for r in 0..<rws {
            for c in 0..<cols {
                zones.append(ZoneRect(
                    Double(c) / Double(cols), Double(r) / Double(rws),
                    1.0 / Double(cols), 1.0 / Double(rws)
                ))
            }
        }
        return zones
    }
}

// Pure zone-set math shared by the editor and covered by unit tests.
enum ZoneGeometry {
    static let grid = 0.05
    static let minSide = 0.1

    static func snapValue(_ v: Double) -> Double {
        (v / grid).rounded() * grid
    }

    static func snap(_ zone: ZoneRect) -> ZoneRect {
        let w = max(snapValue(zone.w), minSide)
        let h = max(snapValue(zone.h), minSide)
        return ZoneRect(
            min(max(snapValue(zone.x), 0), 1 - w),
            min(max(snapValue(zone.y), 0), 1 - h),
            w,
            h
        )
    }

    /// Smallest rect covering both zones, which is what dropping a window
    /// across two of them means. Rounded up to a rectangle, so spanning an
    /// L-shaped pair takes the corner with it.
    static func union(_ a: ZoneRect, _ b: ZoneRect) -> FracRect {
        let x = min(a.x, b.x)
        let y = min(a.y, b.y)
        return FracRect(x, y, max(a.x + a.w, b.x + b.w) - x, max(a.y + a.h, b.y + b.h) - y)
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
