import AppKit

// Where a grab took hold and what the frame becomes as it moves: which edges
// the pointer grabbed, and the rect after pulling them by that much.
//
// Same file-split rule as elsewhere: the constants here are not private only
// because Swift lets an extension see one just in its declaring file.

extension GrabMove {
    /// Which edges a right-drag starting at this point takes hold of. The
    /// middle third of a side is that edge alone; the ends are its corners.
    static func handle(for point: CGPoint, in frame: CGRect) -> Handle {
        guard frame.width > 0, frame.height > 0 else { return Handle() }
        let fx = (point.x - frame.minX) / frame.width
        let fy = (point.y - frame.minY) / frame.height
        var handle = Handle()
        handle.left = fx < cornerFraction
        handle.right = fx > 1 - cornerFraction
        handle.top = fy < cornerFraction
        handle.bottom = fy > 1 - cornerFraction
        // Dead centre still resizes — from the nearest side, so a drag in the
        // middle of a window is never a no-op the user has to think about.
        if handle.isEmpty {
            if min(fx, 1 - fx) < min(fy, 1 - fy) {
                handle.left = fx < 0.5
                handle.right = !handle.left
            } else {
                handle.top = fy < 0.5
                handle.bottom = !handle.top
            }
        }
        return handle
    }

    /// The frame after pulling those edges by that much, never smaller than
    /// the minimum and never inside out.
    static func resized(_ frame: CGRect, by delta: CGVector, pulling handle: Handle) -> CGRect {
        var result = frame
        if handle.left {
            let dx = min(delta.dx, frame.width - minimumSide)
            result.origin.x += dx
            result.size.width -= dx
        } else if handle.right {
            result.size.width = max(frame.width + delta.dx, minimumSide)
        }
        if handle.top {
            let dy = min(delta.dy, frame.height - minimumSide)
            result.origin.y += dy
            result.size.height -= dy
        } else if handle.bottom {
            result.size.height = max(frame.height + delta.dy, minimumSide)
        }
        return result
    }
}
