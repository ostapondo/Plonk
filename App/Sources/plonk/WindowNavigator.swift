import CoreGraphics

// Choosing a window by where it sits rather than by when it was last used.
//
// Two moves live here, both pure so they can be tested without a desktop:
// stepping focus to the neighbour in a direction, and cycling between the
// windows stacked in one zone. Everything is AX space — origin top-left, y
// grows downward — matching WindowManager.

enum WindowNavigator {
    enum Direction: String, CaseIterable {
        case left, right, up, down
    }

    /// Index of the window to focus when stepping from `origin` in a
    /// direction, or nil when nothing lies that way.
    ///
    /// Candidates must be strictly beyond the origin along the axis of travel.
    /// Among those, the closest wins, with sideways distance counted double so
    /// a window straight ahead beats a nearer one off to the side.
    static func target(from origin: CGRect, candidates: [CGRect], direction: Direction) -> Int? {
        let from = CGPoint(x: origin.midX, y: origin.midY)
        var best: (index: Int, score: CGFloat)?
        for (index, frame) in candidates.enumerated() {
            let to = CGPoint(x: frame.midX, y: frame.midY)
            let along: CGFloat
            let across: CGFloat
            switch direction {
            case .left:  along = from.x - to.x; across = abs(from.y - to.y)
            case .right: along = to.x - from.x; across = abs(from.y - to.y)
            case .up:    along = from.y - to.y; across = abs(from.x - to.x)
            case .down:  along = to.y - from.y; across = abs(from.x - to.x)
            }
            // A window centred within a point of the origin is the origin
            // itself, or a duplicate stacked on it; neither is a step.
            guard along > 1 else { continue }
            let score = along + 2 * across
            if best == nil || score < best!.score { best = (index, score) }
        }
        return best?.index
    }

    /// Index of the next window sharing a zone with the one at `current`,
    /// wrapping around. Membership is by centre point, which is what the drag
    /// overlay uses to decide a drop, so a window counts as being in the zone
    /// it looks like it is in even when it overhangs.
    ///
    /// Returns nil when the zone holds nothing else to switch to.
    static func nextInZone(after current: Int, candidates: [CGRect], zone: CGRect,
                           backwards: Bool = false) -> Int? {
        let members = candidates.indices.filter { zone.contains(CGPoint(x: candidates[$0].midX,
                                                                       y: candidates[$0].midY)) }
        guard members.count > 1 else { return nil }
        guard let position = members.firstIndex(of: current) else { return members.first }
        let step = backwards ? members.count - 1 : 1
        return members[(position + step) % members.count]
    }

    /// Keeps a restored frame on screen: a window remembered on a display that
    /// has since been unplugged would otherwise come back somewhere invisible.
    /// Only nudged into view — the size is what the user asked to get back.
    static func clamped(_ frame: CGRect, into visible: CGRect) -> CGRect {
        guard visible.width > 0, visible.height > 0 else { return frame }
        let size = CGSize(width: min(frame.width, visible.width),
                          height: min(frame.height, visible.height))
        let x = min(max(frame.minX, visible.minX), visible.maxX - size.width)
        let y = min(max(frame.minY, visible.minY), visible.maxY - size.height)
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }
}
