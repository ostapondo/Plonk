import Foundation

// The Screenshot, Pointer and Ruler pages, and the panels they open. English
// values live in Resources/en.lproj/Localizable.strings.

extension LocalizedStringResource {
    static let shotCapture = Self.key("shot.capture")
    static let shotCaptureRegion = Self.key("shot.captureRegion")
    static let shotCaptureWindow = Self.key("shot.captureWindow")
    static let shotCaptureScreen = Self.key("shot.captureScreen")
    static let shotCaptureHelp = Self.key("shot.captureHelp")
    static let shotPinPart = Self.key("shot.pinPart")
    static let shotPinPartHelp = Self.key("shot.pinPartHelp")
    static let shotLanguage = Self.key("shot.language")
    static let shotLanguageAutomatic = Self.key("shot.languageAutomatic")
    static let shotText = Self.key("shot.text")
    static let shotTextHelp = Self.key("shot.textHelp")
    static let shotOutput = Self.key("shot.output")
    static let shotCopyOnSave = Self.key("shot.copyOnSave")
    static let shotSaveFolder = Self.key("shot.saveFolder")

    static let mousePointer = Self.key("mouse.pointer")
    static let mousePointerHelp = Self.key("mouse.pointerHelp")
    static let mouseRingClicks = Self.key("mouse.ringClicks")
    static let mouseRingClicksHelp = Self.key("mouse.ringClicksHelp")
    static let mouseCrosshairs = Self.key("mouse.crosshairs")
    static let mouseCrosshairsHelp = Self.key("mouse.crosshairsHelp")
    static let mouseShortcutsHelp = Self.key("mouse.shortcutsHelp")
}
