import Foundation

// The menu bar item and the Updates page. English values live in
// Resources/en.lproj/Localizable.strings.

extension LocalizedStringResource {
    static let menuOpenPlonk = Self.key("menu.openPlonk")
    static let menuLaunchWorkspace = Self.key("menu.launchWorkspace")
    static let menuNoWorkspaces = Self.key("menu.noWorkspaces")
    static let menuActiveAgent = Self.key("menu.activeAgent")
    static let menuNoAgents = Self.key("menu.noAgents")
    static let menuAnyAgent = Self.key("menu.anyAgent")
    static let menuOnlySelectedAgent = Self.key("menu.onlySelectedAgent")
    static let menuCaptureRegion = Self.key("menu.captureRegion")
    static let menuKeepAwake = Self.key("menu.keepAwake")
    static let menuUpdateAvailable = Self.key("menu.updateAvailable")
    static let menuReportBug = Self.key("menu.reportBug")
    static let menuQuit = Self.key("menu.quit")
    static let menuFeatures = Self.key("menu.features")

    static func menuUpdateTo(_ version: String) -> LocalizedStringResource {
        Self.key("menu.updateTo \(version)")
    }

    static let updateInstalled = Self.key("update.installed")
    static let updateUnbundled = Self.key("update.unbundled")
    static let updateAvailable = Self.key("update.available")
    static let updateInstallAndRelaunch = Self.key("update.installAndRelaunch")
    static let updateCheckNow = Self.key("update.checkNow")
    static let updateReleaseNotes = Self.key("update.releaseNotes")
    static let updateInstallHelp = Self.key("update.installHelp")
    static let updateAutomatically = Self.key("update.automatically")
    static let updateAutomaticallyDetail = Self.key("update.automaticallyDetail")
    static let updatePrivacy = Self.key("update.privacy")
    static let updateChecking = Self.key("update.checking")
    static let updateCheckRunning = Self.key("update.checkRunning")
    static let updateVerifying = Self.key("update.verifying")
    static let updateInstalling = Self.key("update.installing")

    static func updateWhatsNew(_ version: String) -> LocalizedStringResource {
        Self.key("update.whatsNew \(version)")
    }

    static func updateUpToDate(_ version: String) -> LocalizedStringResource {
        Self.key("update.upToDate \(version)")
    }

    static func updateIsAvailable(_ version: String) -> LocalizedStringResource {
        Self.key("update.isAvailable \(version)")
    }

    static func updateDownloading(_ version: String) -> LocalizedStringResource {
        Self.key("update.downloading \(version)")
    }

    static let updateErrorDigestMismatch = Self.key("updateError.digestMismatch")
    static let updateErrorAdHocCopy = Self.key("updateError.adHocCopy")
    static let updateErrorNotInstalled = Self.key("updateError.notInstalled")

    static func updateErrorMalformedFeed(_ why: String) -> LocalizedStringResource {
        Self.key("updateError.malformedFeed \(why)")
    }

    static func updateErrorNetwork(_ why: String) -> LocalizedStringResource {
        Self.key("updateError.network \(why)")
    }

    static func updateErrorUnpackFailed(_ why: String) -> LocalizedStringResource {
        Self.key("updateError.unpackFailed \(why)")
    }

    static func updateErrorSignatureRejected(_ why: String) -> LocalizedStringResource {
        Self.key("updateError.signatureRejected \(why)")
    }

    static func updateErrorNotWritable(_ path: String) -> LocalizedStringResource {
        Self.key("updateError.notWritable \(path)")
    }

    static func updateErrorWrongPayload(_ why: String) -> LocalizedStringResource {
        Self.key("updateError.wrongPayload \(why)")
    }
}
