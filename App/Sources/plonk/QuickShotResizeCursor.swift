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
        return handle.x == 0 ? .resizeUpDown : .resizeLeftRight
    }
}
