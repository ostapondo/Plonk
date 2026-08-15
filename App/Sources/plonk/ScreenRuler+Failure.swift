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
                return String(localized: .rulerErrorNoScreenRecording)
            case .captureFailed: return String(localized: .rulerErrorCaptureFailed)
            case .noScreen: return String(localized: .rulerErrorNoScreen)
            case .cancelled: return String(localized: .rulerErrorCancelled)
            }
        }

        /// Somebody pressing Escape is not news; the other three are.
        var isWorthSaying: Bool {
            if case .cancelled = self { return false }
            return true
        }
    }
}
