import CoreGraphics

/// A selection uses integral pixels relative to the display image's top-left.
struct ShotSelection {
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
}
