import Foundation

// The Ruler page and the exclusion list. English values live in
// Resources/en.lproj/Localizable.strings.

extension LocalizedStringResource {
    static let rulerTitle = Self.key("ruler.title")
    static let rulerMeasure = Self.key("ruler.measure")
    static let rulerHelp = Self.key("ruler.help")
    static let rulerShortcut = Self.key("ruler.shortcut")
    static let rulerDetection = Self.key("ruler.detection")
    static let rulerSensitivity = Self.key("ruler.sensitivity")
    static let rulerSensitivityHelp = Self.key("ruler.sensitivityHelp")
    static let rulerDetectionHelp = Self.key("ruler.detectionHelp")

    static let excludedNone = Self.key("excluded.none")
    static let excludedChooseApp = Self.key("excluded.chooseApp")
    static let excludedAddRunning = Self.key("excluded.addRunning")
    static let excludedUnnamed = Self.key("excluded.unnamed")
    static let excludedOrType = Self.key("excluded.orType")
    static let excludedAdd = Self.key("excluded.add")
    static let excludedMatchedAnywhere = Self.key("excluded.matchedAnywhere")
    static let excludedStopExcluding = Self.key("excluded.stopExcluding")
    static let excludedPrompt = Self.key("excluded.prompt")

    static let rulerHint = Self.key("ruler.hint")
    static let rulerRephotographFailed = Self.key("ruler.rephotographFailed")
    static let rulerRephotographed = Self.key("ruler.rephotographed")

    static func rulerCopied(_ what: String) -> LocalizedStringResource {
        Self.key("ruler.copied \(what)")
    }

    static func rulerPoints(_ points: Int) -> LocalizedStringResource {
        Self.key("ruler.points \(points)")
    }

    static func rulerPixels(_ pixels: Int) -> LocalizedStringResource {
        Self.key("ruler.pixels \(pixels)")
    }

    static func rulerPointsAndPixels(_ points: Int, _ pixels: Int) -> LocalizedStringResource {
        Self.key("ruler.pointsAndPixels \(points) \(pixels)")
    }

    static func rulerDelta(_ dx: Int, _ dy: Int) -> LocalizedStringResource {
        Self.key("ruler.delta \(dx) \(dy)")
    }

    static func rulerAcrossAndDown(_ across: String, _ down: String) -> LocalizedStringResource {
        Self.key("ruler.acrossAndDown \(across) \(down)")
    }

    static let warningApiDidNotStart = Self.key("warning.apiDidNotStart")

    static func warningNoToken(_ path: String) -> LocalizedStringResource {
        Self.key("warning.noToken \(path)")
    }

    static func warningPortTaken(_ port: Int) -> LocalizedStringResource {
        Self.key("warning.portTaken \(port)")
    }

    static func warningSettingsReset(_ path: String) -> LocalizedStringResource {
        Self.key("warning.settingsReset \(path)")
    }
}
