import Foundation

// Stay active. English values live in Resources/en.lproj/Localizable.strings.

extension LocalizedStringResource {
    static let activeSubtitle = Self.key("active.subtitle")
    static let activeStayActive = Self.key("active.stayActive")
    static let activeStayActiveHelp = Self.key("active.stayActiveHelp")
    static let activeTurnOffAfter = Self.key("active.turnOffAfter")
    static let activeNever = Self.key("active.never")
    static let activeAfter30Minutes = Self.key("active.after30Minutes")
    static let activeAfter1Hour = Self.key("active.after1Hour")
    static let activeAfter4Hours = Self.key("active.after4Hours")
    static let activeAfter8Hours = Self.key("active.after8Hours")

    static let activeSchedule = Self.key("active.schedule")
    static let activeOnASchedule = Self.key("active.onASchedule")
    static let activeOnAScheduleHelp = Self.key("active.onAScheduleHelp")
    static let activeFrom = Self.key("active.from")
    static let activeTo = Self.key("active.to")
    static let activeDays = Self.key("active.days")
    static let activeSameTimeHelp = Self.key("active.sameTimeHelp")

    static let activeApps = Self.key("active.apps")
    static let activeAppsHelp = Self.key("active.appsHelp")
    static let activeNoApps = Self.key("active.noApps")
    static let activeChooseApp = Self.key("active.chooseApp")
    static let activeAddRunning = Self.key("active.addRunning")
    static let activeUnnamed = Self.key("active.unnamed")
    static let activePrompt = Self.key("active.prompt")
    static let activeRemove = Self.key("active.remove")

    static let activePower = Self.key("active.power")
    static let activeAllowOnBattery = Self.key("active.allowOnBattery")
    static let activeAllowOnBatteryHelp = Self.key("active.allowOnBatteryHelp")

    static let activeNeedsAccessibility = Self.key("active.needsAccessibility")
    static let activeOpenSettings = Self.key("active.openSettings")

    static let activeStatusOn = Self.key("active.statusOn")
    static let activeStatusOff = Self.key("active.statusOff")
    static let activeStatusSchedule = Self.key("active.statusSchedule")
    static let activeStatusApp = Self.key("active.statusApp")
    static let activeStatusPausedOnBattery = Self.key("active.statusPausedOnBattery")
    static let activeStatusNoAccessibility = Self.key("active.statusNoAccessibility")

    static func activeStatusUntil(_ clock: String) -> LocalizedStringResource {
        Self.key("active.statusUntil \(clock)")
    }
}
