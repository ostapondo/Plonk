import CoreGraphics

extension ZoneGeometry {
    /// The empty zone a new window should fill, preferring the one it already
    /// sits in. A window occupies a zone when either one's centre is in the
    /// other, so a window spanning several zones holds each one it covers.
    static func firstEmpty(_ zones: [ZoneRect], in visible: CGRect, occupied windows: [CGRect],
                           preferring point: CGPoint? = nil) -> Int? {
        let empty = zones.indices.filter { index in
            let frame = frame(for: zones[index].frac, in: visible)
            let centre = CGPoint(x: frame.midX, y: frame.midY)
            return !windows.contains { window in
                frame.contains(CGPoint(x: window.midX, y: window.midY)) || window.contains(centre)
            }
        }
        if let point,
           let own = empty.first(where: { frame(for: zones[$0].frac, in: visible).contains(point) }) {
            return own
        }
        return empty.first
    }
}
