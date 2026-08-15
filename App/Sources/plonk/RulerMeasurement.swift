import CoreGraphics
import Foundation

// One answer from the ruler, and how it is written down.
//
// Two numbers matter and they are not the same number: points are what a
// designer, a stylesheet and every frame in this app are counted in, pixels are
// what the display actually lights up. On a Retina screen the second is twice
// the first, and saying only one of them is how a 44-point tap target gets
// built 22 points tall. Both are shown, unless the screen makes them equal.

struct RulerMeasurement {
    enum Kind: String {
        /// The box of one colour under the pointer, found by EdgeDetector.
        case bounds
        /// A straight line the user dragged out.
        case line
    }

    let kind: Kind
    let screen: Int
    /// CG space, points: origin at the top-left of the primary display, y
    /// downward — the space captures and window frames use here.
    let rect: CGRect
    /// Pixels per point on the screen this was measured on.
    let scale: CGFloat
    /// Where a line ran from and to. Nil for a box.
    var from: CGPoint?
    var to: CGPoint?

    var pixelWidth: Double { Double(rect.width * scale) }
    var pixelHeight: Double { Double(rect.height * scale) }

    /// Length of the line, in points. Nil for a box, whose size is its answer.
    var distance: Double? {
        guard kind == .line, let from, let to else { return nil }
        return Double(hypot(to.x - from.x, to.y - from.y))
    }

    /// What the overlay writes beside the pointer, one fact a line.
    var label: String {
        var lines: [String] = []
        if let distance {
            lines.append("\(Self.round(distance)) pt")
            if scale != 1 { lines.append("\(Self.round(distance * Double(scale))) px") }
            lines.append("dx \(Self.round(Double(abs((to?.x ?? 0) - (from?.x ?? 0))))) · "
                         + "dy \(Self.round(Double(abs((to?.y ?? 0) - (from?.y ?? 0)))))")
        } else {
            lines.append("\(Self.round(Double(rect.width))) × \(Self.round(Double(rect.height))) pt")
            if scale != 1 { lines.append("\(Self.round(pixelWidth)) × \(Self.round(pixelHeight)) px") }
        }
        return lines.joined(separator: "\n")
    }

    /// The HUD gets one line rather than three.
    var summary: String { label.replacingOccurrences(of: "\n", with: "  ") }

    /// What a click puts on the clipboard: the measurement and nothing else, so
    /// it can be pasted straight into a stylesheet or a message.
    var clipboardText: String {
        if let distance { return String(Self.round(distance)) }
        return "\(Self.round(Double(rect.width))) × \(Self.round(Double(rect.height)))"
    }

    /// `visible` is the screen's visible area in the same space as `rect`, so
    /// what was measured can be handed back as a fraction the layout tools
    /// take. It can fall outside 0..1: the menu bar and the Dock are measurable
    /// and are not inside it.
    func asDict(visible: CGRect) -> [String: Any] {
        // CGFloat is its own type, and anything crossing [String: Any] that is
        // read back as a Double has to be converted here or it reads as nil.
        var result: [String: Any] = [
            "kind": kind.rawValue,
            "screen": screen,
            "points": ["x": Double(rect.minX), "y": Double(rect.minY),
                       "w": Double(rect.width), "h": Double(rect.height)],
            "pixels": ["w": pixelWidth, "h": pixelHeight],
            "scale": Double(scale),
            "text": summary,
        ]
        if visible.width > 0, visible.height > 0 {
            result["fraction"] = [
                "x": Double((rect.minX - visible.minX) / visible.width),
                "y": Double((rect.minY - visible.minY) / visible.height),
                "w": Double(rect.width / visible.width),
                "h": Double(rect.height / visible.height),
            ]
        }
        if let distance {
            result["distance"] = distance
            result["distance_pixels"] = distance * Double(scale)
        }
        if let from, let to {
            result["from"] = ["x": Double(from.x), "y": Double(from.y)]
            result["to"] = ["x": Double(to.x), "y": Double(to.y)]
        }
        return result
    }

    /// Whole points. Half a pixel is not a measurement anybody wants read out,
    /// and a trailing ".0" in the middle of a label is worse.
    static func round(_ value: Double) -> Int {
        Int(value.rounded())
    }
}
