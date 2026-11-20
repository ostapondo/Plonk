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

    func resize(_ rect: CGRect, dimension: CGFloat, horizontal: Bool, ratio: CGFloat?) -> CGRect {
        let size = resized(rect.size, dimension: dimension, horizontal: horizontal, ratio: ratio, limit: pixels)
        // The bottom edge is maxY because bitmap coordinates grow downward.
        let resized = CGRect(x: rect.minX, y: rect.maxY - size.height, width: size.width, height: size.height)
        return move(resized, by: .zero)
    }

    func resize(_ rect: CGRect, handle: CGPoint, by delta: CGPoint, ratio: CGFloat? = nil) -> CGRect {
        let fixedX = handle.x < 0 ? rect.maxX : rect.minX
        let fixedY = handle.y < 0 ? rect.maxY : rect.minY
        let limit = CGSize(width: handle.x < 0 ? fixedX : handle.x > 0 ? pixels.width - fixedX : pixels.width,
                           height: handle.y < 0 ? fixedY : handle.y > 0 ? pixels.height - fixedY : pixels.height)
        var size = CGSize(width: (rect.width + delta.x * handle.x).clamped(to: 1...limit.width),
                          height: (rect.height + delta.y * handle.y).clamped(to: 1...limit.height))
        if let ratio {
            let horizontal = handle.y == 0 ||
                (handle.x != 0 && abs(delta.x) / rect.width >= abs(delta.y) / rect.height)
            size = resized(size, dimension: horizontal ? size.width : size.height,
                           horizontal: horizontal, ratio: ratio, limit: limit)
        }
        return move(CGRect(x: handle.x < 0 ? fixedX - size.width : fixedX,
                           y: handle.y < 0 ? fixedY - size.height : fixedY,
                           width: size.width, height: size.height), by: .zero)
    }

    private func resized(_ size: CGSize, dimension: CGFloat, horizontal: Bool,
                         ratio: CGFloat?, limit: CGSize) -> CGSize {
        var width = horizontal ? dimension : size.width
        var height = horizontal ? size.height : dimension
        if let ratio {
            if horizontal { height = width / ratio } else { width = height * ratio }
            let scale = min(1, limit.width / width, limit.height / height)
            width *= scale
            height *= scale
        }
        return CGSize(width: width.rounded().clamped(to: 1...limit.width),
                      height: height.rounded().clamped(to: 1...limit.height))
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
