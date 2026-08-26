import CoreGraphics

extension ZoneGeometry {
    /// Where a frame sits as a share of the visible area. Nil when the area
    /// has no size to measure against. Not clamped: a window hanging over an
    /// edge reads as hanging over it, and the caller decides whether to keep it.
    static func fraction(of frame: CGRect, in visible: CGRect) -> FracRect? {
        guard visible.width > 0, visible.height > 0 else { return nil }
        return FracRect(Double((frame.minX - visible.minX) / visible.width),
                        Double((frame.minY - visible.minY) / visible.height),
                        Double(frame.width / visible.width),
                        Double(frame.height / visible.height))
    }
}
