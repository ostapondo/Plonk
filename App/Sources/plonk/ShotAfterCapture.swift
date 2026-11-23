enum ShotAfterCapture: String, Codable {
    case quickActions
    case editor

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: value) ?? .quickActions
    }

    func usesOverlay(for mode: CaptureMode) -> Bool {
        self == .quickActions && mode == .region
    }
}
