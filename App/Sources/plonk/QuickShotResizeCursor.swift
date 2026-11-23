import AppKit

enum QuickShotResizeCursor {
    static func forHandle(_ handle: CGPoint) -> NSCursor {
        if #available(macOS 15, *) {
            if handle.x == 0 { return .rowResize(directions: .all) }
            if handle.y == 0 { return .columnResize(directions: .all) }
            let corner: NSCursor.FrameResizePosition = handle.y < 0
                ? (handle.x < 0 ? .topLeft : .topRight)
                : (handle.x < 0 ? .bottomLeft : .bottomRight)
            return .frameResize(position: corner, directions: .all)
        }
        if handle.x == 0 { return .resizeUpDown }
        if handle.y == 0 { return .resizeLeftRight }
        return handle.x == handle.y ? descending : ascending
    }

    private static let descending = diagonal(descending: true)
    private static let ascending = diagonal(descending: false)

    private static func diagonal(descending: Bool) -> NSCursor {
        let size = CGSize(width: 20, height: 20)
        let image = NSImage(size: size, flipped: true) { _ in
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: x, y: descending ? y : size.height - y)
            }
            let arrow = NSBezierPath()
            arrow.move(to: point(4, 10))
            arrow.line(to: point(4, 4))
            arrow.line(to: point(10, 4))
            arrow.move(to: point(4, 4))
            arrow.line(to: point(16, 16))
            arrow.move(to: point(10, 16))
            arrow.line(to: point(16, 16))
            arrow.line(to: point(16, 10))
            arrow.lineCapStyle = .round
            arrow.lineJoinStyle = .round
            NSColor.white.setStroke()
            arrow.lineWidth = 4
            arrow.stroke()
            NSColor.black.setStroke()
            arrow.lineWidth = 2
            arrow.stroke()
            return true
        }
        return NSCursor(image: image, hotSpot: CGPoint(x: size.width / 2, y: size.height / 2))
    }
}
