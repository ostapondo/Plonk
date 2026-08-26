import Foundation

// A window frame as fractions of a screen's visible area: origin top-left,
// each side in 0...1. The space itself, and how it relates to AX
// coordinates, is documented at the top of WindowManager.swift.

struct FracRect: Equatable {
    let x, y, w, h: Double
    init(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        self.x = x; self.y = y; self.w = w; self.h = h
    }

    /// Parses a `{x,y,w,h}` frame from an API body. Must stay inside the screen
    /// it is a fraction of; the epsilon absorbs rounding from `get_state`.
    static func parse(_ value: Any?) -> FracRect? {
        guard let frame = value as? [String: Any],
              let x = (frame["x"] as? NSNumber)?.doubleValue,
              let y = (frame["y"] as? NSNumber)?.doubleValue,
              let w = (frame["w"] as? NSNumber)?.doubleValue,
              let h = (frame["h"] as? NSNumber)?.doubleValue,
              x.isFinite, y.isFinite, w.isFinite, h.isFinite,
              w > 0, h > 0, x >= 0, y >= 0,
              x + w <= 1.0001, y + h <= 1.0001 else { return nil }
        return FracRect(x, y, w, h)
    }
}
