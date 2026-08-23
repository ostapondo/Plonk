import Foundation

// Pulse. English values live in Resources/en.lproj/Localizable.strings.

extension LocalizedStringResource {
    static let awakeSubtitle = Self.key("awake.subtitle")
    static let awakeKeepNow = Self.key("awake.keepNow")
    static let awakeAvailable = Self.key("awake.available")
    static let awakeAvailableHelp = Self.key("awake.availableHelp")
    static let awakeTurnOffAfter = Self.key("awake.turnOffAfter")
    static let awakeNever = Self.key("awake.never")
    static let awakeAfter15Minutes = Self.key("awake.after15Minutes")
    static let awakeAfter30Minutes = Self.key("awake.after30Minutes")
    static let awakeAfter1Hour = Self.key("awake.after1Hour")
    static let awakeAfter2Hours = Self.key("awake.after2Hours")
    static let awakeAfter4Hours = Self.key("awake.after4Hours")
    static let awakeAfter8Hours = Self.key("awake.after8Hours")

    static let awakeSchedule = Self.key("awake.schedule")
    static let awakeOnASchedule = Self.key("awake.onASchedule")
    static let awakeOnAScheduleHelp = Self.key("awake.onAScheduleHelp")
    static let awakeFrom = Self.key("awake.from")
    static let awakeTo = Self.key("awake.to")
    static let awakeDays = Self.key("awake.days")
    static let awakeSameTimeHelp = Self.key("awake.sameTimeHelp")

    static let awakeApps = Self.key("awake.apps")
    static let awakeAppsHelp = Self.key("awake.appsHelp")
    static let awakeNoApps = Self.key("awake.noApps")
    static let awakeChooseApp = Self.key("awake.chooseApp")
    static let awakeAddRunning = Self.key("awake.addRunning")
    static let awakeUnnamed = Self.key("awake.unnamed")
    static let awakePrompt = Self.key("awake.prompt")
    static let awakeRemove = Self.key("awake.remove")

    static let awakePower = Self.key("awake.power")
    static let awakeKeepDisplayOn = Self.key("awake.keepDisplayOn")
    static let awakeKeepDisplayOnHelp = Self.key("awake.keepDisplayOnHelp")
    static let awakeAllowOnBattery = Self.key("awake.allowOnBattery")
    static let awakeAllowOnBatteryHelp = Self.key("awake.allowOnBatteryHelp")
    static let awakeAutoWhileCharging = Self.key("awake.autoWhileCharging")
    static let awakeAutoWhileChargingHelp = Self.key("awake.autoWhileChargingHelp")
    static let awakeLidClosed = Self.key("awake.lidClosed")
    static let awakeLidClosedHelp = Self.key("awake.lidClosedHelp")

    static let awakeNeedsAccessibility = Self.key("awake.needsAccessibility")
    static let awakeOpenSettings = Self.key("awake.openSettings")

    static let awakeStatusOn = Self.key("awake.statusOn")
    static let awakeStatusOff = Self.key("awake.statusOff")
    static let awakeStatusAvailable = Self.key("awake.statusAvailable")
    static let awakeStatusAutoCharging = Self.key("awake.statusAutoCharging")
    static let awakeStatusSchedule = Self.key("awake.statusSchedule")
    static let awakeStatusApp = Self.key("awake.statusApp")
    static let awakeStatusPausedOnBattery = Self.key("awake.statusPausedOnBattery")
    static let awakeStatusNoAccessibility = Self.key("awake.statusNoAccessibility")
    static let awakeStatusLidClosed = Self.key("awake.statusLidClosed")

    static func awakeStatusUntil(_ clock: String) -> LocalizedStringResource {
        Self.key("awake.statusUntil \(clock)")
    }

    static func awakeStatusUntilProcess(_ pid: Int) -> LocalizedStringResource {
        Self.key("awake.statusUntilProcess \(pid)")
    }
}
