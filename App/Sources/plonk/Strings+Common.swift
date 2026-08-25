import Foundation

// Words that belong to no one module, and the settings field every page is
// built from. English values live in Resources/en.lproj/Localizable.strings.

extension LocalizedStringResource {
    static let commonShortcuts = Self.key("common.shortcuts")
    static let commonChoose = Self.key("common.choose")
    static let commonCancel = Self.key("common.cancel")
    static let commonSave = Self.key("common.save")
    static let commonDelete = Self.key("common.delete")
    static let commonDone = Self.key("common.done")
    static let commonPoints = Self.key("common.points")
    static let commonPercent = Self.key("common.percent")
    static let commonSeparator = Self.key("common.separator")

    static func pointsNotWhole(_ field: String) -> LocalizedStringResource {
        Self.key("points.notWhole \(field)")
    }

    static func pointsOutOfRange(_ field: String, _ low: Int, _ high: Int) -> LocalizedStringResource {
        Self.key("points.outOfRange \(field) \(low) \(high)")
    }

    static let directionLeft = Self.key("direction.left")
    static let directionRight = Self.key("direction.right")
    static let directionUp = Self.key("direction.up")
    static let directionDown = Self.key("direction.down")
    static let captureRegion = Self.key("capture.region")
    static let captureWindow = Self.key("capture.window")
    static let captureScreen = Self.key("capture.screen")
}
