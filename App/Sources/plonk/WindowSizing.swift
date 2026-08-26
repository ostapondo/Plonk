import CoreGraphics

// Growing and shrinking a window by a step, the way Rectangle's Larger and
// Smaller do, so a window can be sized without a zone. AX space, like every
// frame here: origin top-left, y grows downward.

enum WindowSizing {
    /// Points added to the width and to the height per press, half on each
    /// side. Rectangle's number, since the keys are Rectangle's.
    static let step: CGFloat = 30
    /// Under this on a side a window is a title bar, and shrinking stops.
    static let minimumSide: CGFloat = 120
    /// A side this close to the screen's edge is against it, and stays there.
    static let edgeTolerance: CGFloat = 5

    /// `frame` grown about its centre by `step`, or shrunk by a negative one,
    /// held inside `visible`. A side against the screen's edge stays against
    /// it, so a window filling the left half grows to the right rather than
    /// off the screen, shrinks away from the edge it is not on, and keeps
    /// its full height either way. Only a window filling the whole screen
    /// shrinks from every side, since there is nowhere else for it to go. A
    /// window that would end up under `minimumSide` is handed back as it was.
    static func resized(_ frame: CGRect, by step: CGFloat, within visible: CGRect) -> CGRect {
        let whole = abs(frame.minX - visible.minX) <= edgeTolerance && abs(frame.maxX - visible.maxX) <= edgeTolerance
            && abs(frame.minY - visible.minY) <= edgeTolerance && abs(frame.maxY - visible.maxY) <= edgeTolerance
        let (minX, maxX) = axis(frame.minX, frame.maxX, by: step, within: visible.minX, visible.maxX,
                                fromBothEnds: whole)
        let (minY, maxY) = axis(frame.minY, frame.maxY, by: step, within: visible.minY, visible.maxY,
                                fromBothEnds: whole)
        let result = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        guard result.width >= minimumSide, result.height >= minimumSide else { return frame }
        return result
    }

    /// One axis: both ends move half the step apart, unless one is pinned to
    /// the screen's edge, in which case the other takes the whole step. With
    /// both pinned the window spans the screen on this axis and stays that
    /// way, except that a window filling the whole screen may shrink from
    /// both ends at once (`fromBothEnds`).
    private static func axis(_ low: CGFloat, _ high: CGFloat, by step: CGFloat,
                             within lowest: CGFloat, _ highest: CGFloat,
                             fromBothEnds: Bool) -> (CGFloat, CGFloat) {
        let pinnedLow = abs(low - lowest) <= edgeTolerance
        let pinnedHigh = abs(high - highest) <= edgeTolerance
        var a = low
        var b = high
        switch (pinnedLow, pinnedHigh) {
        case (true, true):
            if step < 0, fromBothEnds { a -= step / 2; b += step / 2 }
        case (true, false):
            b += step
        case (false, true):
            a -= step
        case (false, false):
            a -= step / 2
            b += step / 2
        }
        return (max(a, lowest), min(b, highest))
    }
}
