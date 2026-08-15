import Foundation

// The four ways a measurement can come to nothing, and what each is worth
// saying. Kept apart from ScreenRuler, which is at the line limit.

extension ScreenRuler {
    enum Failure: LocalizedError {
        case notPermitted
        case captureFailed
        case noScreen
        case cancelled

        var errorDescription: String? {
            switch self {
            case .notPermitted:
                return "Plonk does not have Screen Recording, so it cannot see the pixels it would "
                    + "measure. Grant it in System Settings › Privacy & Security › Screen Recording."
            case .captureFailed: return "the screen could not be photographed"
            case .noScreen: return "that point is not on any screen"
            case .cancelled: return "nothing was measured"
            }
        }

        /// Somebody pressing Escape is not news; the other three are.
        var isWorthSaying: Bool {
            if case .cancelled = self { return false }
            return true
        }
    }
}
