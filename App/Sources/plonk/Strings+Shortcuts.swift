import Foundation

// What every bindable action is called, and the headings they are filed under.
// English values live in Resources/en.lproj/Localizable.strings.

extension LocalizedStringResource {
    static let shortcutLeftHalf = Self.key("shortcut.leftHalf")
    static let shortcutRightHalf = Self.key("shortcut.rightHalf")
    static let shortcutTopHalf = Self.key("shortcut.topHalf")
    static let shortcutBottomHalf = Self.key("shortcut.bottomHalf")
    static let shortcutTopLeft = Self.key("shortcut.topLeft")
    static let shortcutTopRight = Self.key("shortcut.topRight")
    static let shortcutBottomLeft = Self.key("shortcut.bottomLeft")
    static let shortcutBottomRight = Self.key("shortcut.bottomRight")
    static let shortcutMaximize = Self.key("shortcut.maximize")
    static let shortcutCenter = Self.key("shortcut.center")
    static let shortcutFlashZones = Self.key("shortcut.flashZones")
    static let shortcutCaptureRegion = Self.key("shortcut.captureRegion")
    static let shortcutCaptureText = Self.key("shortcut.captureText")
    static let shortcutPushToTalk = Self.key("shortcut.pushToTalk")
    static let shortcutPutItBack = Self.key("shortcut.putItBack")
    static let shortcutNextInZone = Self.key("shortcut.nextInZone")
    static let shortcutPreviousInZone = Self.key("shortcut.previousInZone")
    static let shortcutFocusLeft = Self.key("shortcut.focusLeft")
    static let shortcutFocusRight = Self.key("shortcut.focusRight")
    static let shortcutFocusUp = Self.key("shortcut.focusUp")
    static let shortcutFocusDown = Self.key("shortcut.focusDown")
    static let shortcutFindPointer = Self.key("shortcut.findPointer")
    static let shortcutJumpPointer = Self.key("shortcut.jumpPointer")
    static let shortcutCropLive = Self.key("shortcut.cropLive")
    static let shortcutCropStill = Self.key("shortcut.cropStill")
    static let shortcutRuler = Self.key("shortcut.ruler")
    static let shortcutGuide = Self.key("shortcut.guide")
    static let shortcutCommandPalette = Self.key("shortcut.commandPalette")
    static let shortcutZoneSetPalette = Self.key("shortcut.zoneSetPalette")
    static let shortcutNextDisplay = Self.key("shortcut.nextDisplay")
    static let shortcutPreviousDisplay = Self.key("shortcut.previousDisplay")
    static let shortcutLarger = Self.key("shortcut.larger")
    static let shortcutSmaller = Self.key("shortcut.smaller")
    static let shortcutUnbound = Self.key("shortcut.unbound")
    static let shortcutPressKeys = Self.key("shortcut.pressKeys")
    static let shortcutAlreadyTaken = Self.key("shortcut.alreadyTaken")

    static let shortcutGroupHalves = Self.key("shortcut.group.halves")
    static let shortcutGroupQuarters = Self.key("shortcut.group.quarters")
    static let shortcutGroupWholeScreen = Self.key("shortcut.group.wholeScreen")
    static let shortcutGroupNumberedZones = Self.key("shortcut.group.numberedZones")
    static let shortcutGroupZoneSets = Self.key("shortcut.group.zoneSets")
    static let shortcutGroupDisplays = Self.key("shortcut.group.displays")
    static let shortcutGroupSize = Self.key("shortcut.group.size")
    static let shortcutGroupFocus = Self.key("shortcut.group.focus")
    static let shortcutGroupPointer = Self.key("shortcut.group.pointer")
    static let shortcutGroupGuide = Self.key("shortcut.group.guide")
    static let shortcutGroupCrop = Self.key("shortcut.group.crop")
    static let shortcutGroupRuler = Self.key("shortcut.group.ruler")
    static let shortcutGroupOther = Self.key("shortcut.group.other")

    static func shortcutZone(_ number: Int) -> LocalizedStringResource {
        Self.key("shortcut.zone \(number)")
    }

    static func shortcutZoneSet(_ number: Int) -> LocalizedStringResource {
        Self.key("shortcut.zoneSet \(number)")
    }

    static let keysHotkeys = Self.key("keys.hotkeys")
    static let keysHotkeysDetail = Self.key("keys.hotkeysDetail")
    static let keysGuide = Self.key("keys.guide")
    static let keysGuideHelp = Self.key("keys.guideHelp")
    static let keysPalette = Self.key("keys.palette")
    static let keysPaletteHelp = Self.key("keys.paletteHelp")
    static let keysRestoreDefaults = Self.key("keys.restoreDefaults")
    static let keysFromRectangle = Self.key("keys.fromRectangle")
    static let keysImportRectangle = Self.key("keys.importRectangle")
    static let keysImportRectangleButton = Self.key("keys.importRectangleButton")
    static let keysImportRectangleHelp = Self.key("keys.importRectangleHelp")
    static let keysRectangleURLs = Self.key("keys.rectangleURLs")
    static let keysRectangleURLsHelp = Self.key("keys.rectangleURLsHelp")

    static func keysSetOnPage(_ page: String) -> LocalizedStringResource {
        Self.key("keys.setOnPage \(page)")
    }
}
