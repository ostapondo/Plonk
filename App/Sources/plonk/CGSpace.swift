import AppKit

/// AppKit's global space has its origin at the bottom-left of the primary
/// display with y growing upward; CG, and the AX API with it, put the origin
/// at the top-left with y growing downward. Same x, y mirrored about the
/// primary screen's height, so the flip is its own inverse and one function
/// converts either way.
enum CGSpace {
    static var primaryMaxY: CGFloat { NSScreen.screens.first?.frame.maxY ?? 0 }

    static func flip(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: primaryMaxY - point.y)
    }

    static func flip(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: primaryMaxY - rect.maxY, width: rect.width, height: rect.height)
    }
}

extension CGRect {
    /// The smallest rect with both points as corners.
    init(spanning a: CGPoint, _ b: CGPoint) {
        self.init(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }
}
