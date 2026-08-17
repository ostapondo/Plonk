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
