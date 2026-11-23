import CoreGraphics

/// A selection uses integral pixels relative to the display image's top-left.
struct ShotSelection {
    static let handleLength: CGFloat = 25
    private static let edgeTolerance: CGFloat = 5

    let pixels: CGSize
    let view: CGSize

    func pixelPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: (point.x / view.width * pixels.width).rounded().clamped(to: 0...pixels.width),
                y: (point.y / view.height * pixels.height).rounded().clamped(to: 0...pixels.height))
    }

    func selection(from start: CGPoint, to end: CGPoint) -> CGRect? {
        let rect = CGRect(spanning: pixelPoint(start), pixelPoint(end))
        return rect.isEmpty ? nil : rect
    }

    func viewRect(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX / pixels.width * view.width, y: rect.minY / pixels.height * view.height,
               width: rect.width / pixels.width * view.width, height: rect.height / pixels.height * view.height)
    }

    func unitRect(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX / pixels.width, y: rect.minY / pixels.height,
               width: rect.width / pixels.width, height: rect.height / pixels.height)
    }

    func move(_ rect: CGRect, by delta: CGPoint) -> CGRect {
        CGRect(x: (rect.minX + delta.x).clamped(to: 0...(pixels.width - rect.width)),
               y: (rect.minY + delta.y).clamped(to: 0...(pixels.height - rect.height)),
               width: rect.width, height: rect.height)
    }

    func resize(_ rect: CGRect, handle: CGPoint, by delta: CGPoint) -> CGRect {
        func edges(_ low: CGFloat, _ high: CGFloat, direction: CGFloat, offset: CGFloat, max: CGFloat)
            -> (CGFloat, CGFloat) {
            if direction < 0 { return ((low + offset).clamped(to: 0...(high - 1)), high) }
            if direction > 0 { return (low, (high + offset).clamped(to: (low + 1)...max)) }
            return (low, high)
        }
        let x = edges(rect.minX, rect.maxX, direction: handle.x, offset: delta.x, max: pixels.width)
        let y = edges(rect.minY, rect.maxY, direction: handle.y, offset: delta.y, max: pixels.height)
        return CGRect(x: x.0, y: y.0, width: x.1 - x.0, height: y.1 - y.0)
    }

    func handle(at point: CGPoint, of rect: CGRect) -> CGPoint {
        let frame = viewRect(rect)
        let tolerance = Self.edgeTolerance
        guard frame.insetBy(dx: -tolerance, dy: -tolerance).contains(point) else { return .zero }
        let x: CGFloat = point.x <= frame.midX ? -1 : 1
        let y: CGFloat = point.y <= frame.midY ? -1 : 1
        let dx = abs(point.x - (x < 0 ? frame.minX : frame.maxX))
        let dy = abs(point.y - (y < 0 ? frame.minY : frame.maxY))
        if (dx <= tolerance && dy <= min(Self.handleLength, frame.height / 2)) ||
            (dy <= tolerance && dx <= min(Self.handleLength, frame.width / 2)) {
            return CGPoint(x: x, y: y)
        }
        return CGPoint(x: dx <= tolerance ? x : 0, y: dy <= tolerance ? y : 0)
    }
}
