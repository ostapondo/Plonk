import Foundation

// The fixed placements a hotkey, a URL or a spoken command can ask for.
// Each is a FracRect, so a preset lands the same way a zone does.

enum Preset: String, CaseIterable {
    case leftHalf = "left-half"
    case rightHalf = "right-half"
    case topHalf = "top-half"
    case bottomHalf = "bottom-half"
    case topLeft = "top-left"
    case topRight = "top-right"
    case bottomLeft = "bottom-left"
    case bottomRight = "bottom-right"
    case maximize = "maximize"
    case center = "center"

    var frac: FracRect {
        switch self {
        case .leftHalf: return FracRect(0, 0, 0.5, 1)
        case .rightHalf: return FracRect(0.5, 0, 0.5, 1)
        case .topHalf: return FracRect(0, 0, 1, 0.5)
        case .bottomHalf: return FracRect(0, 0.5, 1, 0.5)
        case .topLeft: return FracRect(0, 0, 0.5, 0.5)
        case .topRight: return FracRect(0.5, 0, 0.5, 0.5)
        case .bottomLeft: return FracRect(0, 0.5, 0.5, 0.5)
        case .bottomRight: return FracRect(0.5, 0.5, 0.5, 0.5)
        case .maximize: return FracRect(0, 0, 1, 1)
        case .center: return FracRect(0.2, 0.15, 0.6, 0.7)
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .leftHalf: return .shortcutLeftHalf
        case .rightHalf: return .shortcutRightHalf
        case .topHalf: return .shortcutTopHalf
        case .bottomHalf: return .shortcutBottomHalf
        case .topLeft: return .shortcutTopLeft
        case .topRight: return .shortcutTopRight
        case .bottomLeft: return .shortcutBottomLeft
        case .bottomRight: return .shortcutBottomRight
        case .maximize: return .shortcutMaximize
        case .center: return .shortcutCenter
        }
    }
}

extension Preset {
    /// The widths a half steps through when its key is pressed again: the
    /// half, then two thirds, then a third, then the half again. Rectangle's
    /// cycle, because the keys are Rectangle's too.
    static let cycle: [Double] = [0.5, 2.0 / 3.0, 1.0 / 3.0]
    /// How close a window has to be to a step, on every side, to count as
    /// sitting on it. An app that sizes to a character grid lands a few
    /// points off, and that still has to count.
    static let cycleTolerance = 0.03

    /// Where this preset puts a window that is at `current` now: the next
    /// step of the cycle for a half the window is already on, the preset
    /// itself for anything else. Nil is a window nothing is known about.
    func next(after current: FracRect?) -> FracRect {
        guard let current, isHalf else { return frac }
        for (index, step) in Self.cycle.enumerated() where Self.close(current, share(of: step)) {
            return share(of: Self.cycle[(index + 1) % Self.cycle.count])
        }
        return frac
    }

    private var isHalf: Bool {
        [.leftHalf, .rightHalf, .topHalf, .bottomHalf].contains(self)
    }

    /// This half's side of the screen, taking `fraction` of it.
    func share(of fraction: Double) -> FracRect {
        switch self {
        case .leftHalf: return FracRect(0, 0, fraction, 1)
        case .rightHalf: return FracRect(1 - fraction, 0, fraction, 1)
        case .topHalf: return FracRect(0, 0, 1, fraction)
        case .bottomHalf: return FracRect(0, 1 - fraction, 1, fraction)
        default: return frac
        }
    }

    static func close(_ a: FracRect, _ b: FracRect) -> Bool {
        abs(a.x - b.x) < cycleTolerance && abs(a.y - b.y) < cycleTolerance
            && abs(a.w - b.w) < cycleTolerance && abs(a.h - b.h) < cycleTolerance
    }
}
