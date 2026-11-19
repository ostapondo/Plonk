import CoreGraphics

/// The selection is an integral rectangle in the display image, with a top-left origin.
struct ShotSelection {
    let pixels: CGSize
    let view: CGSize

    var bounds: CGRect { CGRect(origin: .zero, size: pixels) }

    func pixelPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: (point.x / view.width * pixels.width).rounded().clamped(to: 0...pixels.width),
                y: (point.y / view.height * pixels.height).rounded().clamped(to: 0...pixels.height))
    }

    func viewRect(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX / pixels.width * view.width, y: rect.minY / pixels.height * view.height,
               width: rect.width / pixels.width * view.width, height: rect.height / pixels.height * view.height)
    }

    func move(_ rect: CGRect, by delta: CGPoint) -> CGRect {
        contained(rect.offsetBy(dx: delta.x, dy: delta.y))
    }

    func resize(_ rect: CGRect, dimension: CGFloat, horizontal: Bool, ratio: CGFloat?) -> CGRect {
        let size = resized(rect.size, dimension: dimension, horizontal: horizontal, ratio: ratio, limit: pixels)
        return contained(CGRect(x: rect.minX, y: rect.maxY - size.height, width: size.width, height: size.height))
    }

    func drag(_ rect: CGRect, handle: CGPoint, delta: CGPoint, ratio: CGFloat?) -> CGRect {
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
        return contained(CGRect(x: handle.x < 0 ? fixedX - size.width : fixedX,
                                y: handle.y < 0 ? fixedY - size.height : fixedY,
                                width: size.width, height: size.height))
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

    private func contained(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX.clamped(to: 0...(pixels.width - rect.width)),
               y: rect.minY.clamped(to: 0...(pixels.height - rect.height)),
               width: rect.width, height: rect.height)
    }
}
