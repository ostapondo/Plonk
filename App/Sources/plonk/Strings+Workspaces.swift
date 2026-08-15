import Foundation

// Workspaces. English values live in Resources/en.lproj/Localizable.strings,
// and the counted ones in Localizable.stringsdict beside it, which is where a
// language states its own plural rules.

extension LocalizedStringResource {
    static let workspacesGrantAccessibility = Self.key("workspaces.grantAccessibility")
    static let workspacesName = Self.key("workspaces.name")
    static let workspacesSaveWhatIsOnScreen = Self.key("workspaces.saveWhatIsOnScreen")
    static let workspacesSaveHelp = Self.key("workspaces.saveHelp")
    static let workspacesNone = Self.key("workspaces.none")
    static let workspacesTitle = Self.key("workspaces.title")
    static let workspacesListHelp = Self.key("workspaces.listHelp")
    static let workspacesHideWindows = Self.key("workspaces.hideWindows")
    static let workspacesShowWindows = Self.key("workspaces.showWindows")
    static let workspacesLaunch = Self.key("workspaces.launch")
    static let workspacesLaunchOnMonitor = Self.key("workspaces.launchOnMonitor")
    static let workspacesRename = Self.key("workspaces.rename")
    static let workspacesRecapture = Self.key("workspaces.recapture")
    static let workspacesMoveExisting = Self.key("workspaces.moveExisting")
    static let workspacesOpenWith = Self.key("workspaces.openWith")
    static let workspacesRemove = Self.key("workspaces.remove")
    static let workspacesOpenWithField = Self.key("workspaces.openWithField")
    static let workspacesOpenWithHint = Self.key("workspaces.openWithHint")
    static let workspacesArguments = Self.key("workspaces.arguments")
    static let workspacesArgumentsHint = Self.key("workspaces.argumentsHint")

    static func workspacesMainDisplay(_ size: String) -> LocalizedStringResource {
        Self.key("workspaces.mainDisplay \(size)")
    }

    static func workspacesDisplay(_ number: Int, _ size: String) -> LocalizedStringResource {
        Self.key("workspaces.display \(number) \(size)")
    }

    static func workspacesAppCount(_ count: Int) -> LocalizedStringResource {
        Self.key("workspaces.appCount \(count)")
    }

    static func workspacesWindowCount(_ count: Int) -> LocalizedStringResource {
        Self.key("workspaces.windowCount \(count)")
    }

    static func workspacesMonitorCount(_ count: Int) -> LocalizedStringResource {
        Self.key("workspaces.monitorCount \(count)")
    }

    static func workspacesPlacement(_ width: Int, _ height: Int,
                                    _ x: Int, _ y: Int) -> LocalizedStringResource {
        Self.key("workspaces.placement \(width) \(height) \(x) \(y)")
    }

    static func workspacesOnScreen(_ screen: Int, _ placement: String) -> LocalizedStringResource {
        Self.key("workspaces.onScreen \(screen) \(placement)")
    }

    static let launchLaunched = Self.key("launch.launched")
    static let launchClose = Self.key("launch.close")
    static let launchPending = Self.key("launch.pending")
    static let launchOpening = Self.key("launch.opening")
    static let launchWaitingForWindow = Self.key("launch.waitingForWindow")

    static func launchLaunching(_ name: String) -> LocalizedStringResource {
        Self.key("launch.launching \(name)")
    }

    static let launchAlreadyOpen = Self.key("launch.alreadyOpen")
    static let launchCancelled = Self.key("launch.cancelled")

    static func launchNotInstalled(_ app: String) -> LocalizedStringResource {
        Self.key("launch.notInstalled \(app)")
    }

    static func launchNoWindow(_ seconds: Int) -> LocalizedStringResource {
        Self.key("launch.noWindow \(seconds)")
    }
}

/// Why an app in a workspace did not land where it was meant to. Resolved here
/// rather than at the call site: the launcher reports these to the panel and to
/// an agent as one string, and it should not have to know that it is text.
enum LaunchReason {
    static let alreadyOpen = String(localized: .launchAlreadyOpen)
    static let cancelled = String(localized: .launchCancelled)

    static func notInstalled(_ app: String) -> String {
        String(localized: .launchNotInstalled(app))
    }

    static func noWindow(_ seconds: Int) -> String {
        String(localized: .launchNoWindow(seconds))
    }
}
