import Foundation

// The HUD, and the failures that reach it from voice and the ruler. English
// values live in Resources/en.lproj/Localizable.strings.

extension LocalizedStringResource {
    static let hudNoTextFound = Self.key("hud.noTextFound")
    static let hudOneScreenOnly = Self.key("hud.oneScreenOnly")
    static let hudListening = Self.key("hud.listening")
    static let hudGuideNeedsAccessibility = Self.key("hud.guideNeedsAccessibility")
    static let hudNoActiveAgent = Self.key("hud.noActiveAgent")
    static let hudWentNowhere = Self.key("hud.wentNowhere")

    static func hudSavedTo(_ path: String) -> LocalizedStringResource {
        Self.key("hud.savedTo \(path)")
    }

    static func hudCopied(_ text: String) -> LocalizedStringResource {
        Self.key("hud.copied \(text)")
    }

    static func hudHotkeyTaken(_ keys: String, _ owner: String) -> LocalizedStringResource {
        Self.key("hud.hotkeyTaken \(keys) \(owner)")
    }

    static let hudRectangleImported = Self.key("hud.rectangleImported")
    static let hudRectangleNothing = Self.key("hud.rectangleNothing")
    static let hudRectangleGridOnly = Self.key("hud.rectangleGridOnly")
    static let hudUrlUnreadable = Self.key("hud.urlUnreadable")

    static func hudRectangleTook(_ owner: String) -> LocalizedStringResource {
        Self.key("hud.rectangleTook \(owner)")
    }

    static func hudUrlHeldDown(_ name: String) -> LocalizedStringResource {
        Self.key("hud.urlHeldDown \(name)")
    }

    static func hudUrlUnknown(_ name: String) -> LocalizedStringResource {
        Self.key("hud.urlUnknown \(name)")
    }

    static func hudUrlZoneSet(_ name: String) -> LocalizedStringResource {
        Self.key("hud.urlZoneSet \(name)")
    }

    static func hudWaitingFor(_ agent: String, _ note: String) -> LocalizedStringResource {
        Self.key("hud.waitingFor \(agent) \(note)")
    }

    static func hudSentTo(_ agent: String, _ text: String) -> LocalizedStringResource {
        Self.key("hud.sentTo \(agent) \(text)")
    }

    static func hudWorking(_ agent: String, _ dots: String, _ seconds: Int) -> LocalizedStringResource {
        Self.key("hud.working \(agent) \(dots) \(seconds)")
    }

    static func hudFinished(_ agent: String, _ seconds: Int) -> LocalizedStringResource {
        Self.key("hud.finished \(agent) \(seconds)")
    }

    static func hudFailed(_ agent: String, _ code: Int) -> LocalizedStringResource {
        Self.key("hud.failed \(agent) \(code)")
    }

    static func hudWouldNotStart(_ agent: String, _ why: String) -> LocalizedStringResource {
        Self.key("hud.wouldNotStart \(agent) \(why)")
    }

    static func hudRan(_ what: String) -> LocalizedStringResource {
        Self.key("hud.ran \(what)")
    }

    static let voiceErrorPermissions = Self.key("voiceError.permissions")
    static let voiceErrorNoLanguage = Self.key("voiceError.noLanguage")
    static let voiceErrorNoMicrophone = Self.key("voiceError.noMicrophone")
    static let voiceErrorHeardNothing = Self.key("voiceError.heardNothing")

    static func voiceErrorMicrophoneFailed(_ why: String) -> LocalizedStringResource {
        Self.key("voiceError.microphoneFailed \(why)")
    }

    static let rulerErrorNoScreenRecording = Self.key("rulerError.noScreenRecording")
    static let rulerErrorCaptureFailed = Self.key("rulerError.captureFailed")
    static let rulerErrorNoScreen = Self.key("rulerError.noScreen")
    static let rulerErrorCancelled = Self.key("rulerError.cancelled")

    static let hudEdgeSnappingScreen = Self.key("hud.edgeSnappingScreen")
    static let hudNeverMoved = Self.key("hud.neverMoved")
    static let hudNothingElseInZone = Self.key("hud.nothingElseInZone")
    static let hudNoZoneSets = Self.key("hud.noZoneSets")
    static let hudCopiedToClipboard = Self.key("hud.copiedToClipboard")
    static let hudSaved = Self.key("hud.saved")

    static func hudZoneRange(_ highest: Int) -> LocalizedStringResource {
        Self.key("hud.zoneRange \(highest)")
    }

    static func hudZoneSetCount(_ count: Int) -> LocalizedStringResource {
        Self.key("hud.zoneSetCount \(count)")
    }
}
