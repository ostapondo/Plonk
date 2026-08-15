import Foundation

// The window's own furniture: sidebar, top bar, and the names of the
// destinations and pages. English values live in
// Resources/en.lproj/Localizable.strings.

extension LocalizedStringResource {
    static let appName = Self.key("app.name")
    static let appRunACommand = Self.key("app.runACommand")
    static let appWorkspaces = Self.key("app.workspaces")
    static let appReportBug = Self.key("app.reportBug")
    static let appReport = Self.key("app.report")
    static let appThemePicker = Self.key("app.themePicker")
    static let appAllPermissionsGranted = Self.key("app.allPermissionsGranted")
    static let appAccessibility = Self.key("app.accessibility")
    static let appScreenRecording = Self.key("app.screenRecording")

    static func appVersion(_ version: String) -> LocalizedStringResource {
        Self.key("app.version \(version)")
    }

    static func appLaunchWorkspace(_ name: String) -> LocalizedStringResource {
        Self.key("app.launchWorkspace \(name)")
    }

    static func appTitle(_ group: String, _ page: String) -> LocalizedStringResource {
        Self.key("app.title \(group) \(page)")
    }

    static func appAgentCount(_ count: Int) -> LocalizedStringResource {
        Self.key("app.agentCount \(count)")
    }

    static let groupHome = Self.key("group.home")
    static let groupLayout = Self.key("group.layout")
    static let groupCapture = Self.key("group.capture")
    static let groupAutomation = Self.key("group.automation")
    static let groupSettings = Self.key("group.settings")

    static let pageHome = Self.key("page.home")
    static let pageZones = Self.key("page.zones")
    static let pageWorkspaces = Self.key("page.workspaces")
    static let pageShot = Self.key("page.shot")
    static let pageMouse = Self.key("page.mouse")
    static let pageRuler = Self.key("page.ruler")
    static let pageAI = Self.key("page.ai")
    static let pageVoice = Self.key("page.voice")
    static let pageAppearance = Self.key("page.appearance")
    static let pageShortcuts = Self.key("page.shortcuts")
    static let pageAwake = Self.key("page.awake")
    static let pageUpdate = Self.key("page.update")
}
