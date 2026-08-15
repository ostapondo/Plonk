import Foundation

// Keep awake, and the pages under Settings that have no module of their own.
// English values live in Resources/en.lproj/Localizable.strings.

extension LocalizedStringResource {
    static let awakeKeepNow = Self.key("awake.keepNow")
    static let awakePausedOnBattery = Self.key("awake.pausedOnBattery")
    static let awakeMenuBarGlow = Self.key("awake.menuBarGlow")
    static let awakeTurnOffAfter = Self.key("awake.turnOffAfter")
    static let awakeNever = Self.key("awake.never")
    static let awakeAfter15Minutes = Self.key("awake.after15Minutes")
    static let awakeAfter30Minutes = Self.key("awake.after30Minutes")
    static let awakeAfter1Hour = Self.key("awake.after1Hour")
    static let awakeAfter2Hours = Self.key("awake.after2Hours")
    static let awakePower = Self.key("awake.power")
    static let awakeKeepDisplayOn = Self.key("awake.keepDisplayOn")
    static let awakeKeepDisplayOnHelp = Self.key("awake.keepDisplayOnHelp")
    static let awakeAllowOnBattery = Self.key("awake.allowOnBattery")
    static let awakeAllowOnBatteryHelp = Self.key("awake.allowOnBatteryHelp")
    static let awakeAutoWhileCharging = Self.key("awake.autoWhileCharging")
    static let awakeAutoWhileChargingHelp = Self.key("awake.autoWhileChargingHelp")

    static let awakeStatusOn = Self.key("awake.statusOn")
    static let awakeStatusOff = Self.key("awake.statusOff")
    static let awakeStatusAutoCharging = Self.key("awake.statusAutoCharging")
    static let awakeStatusPausedOnBattery = Self.key("awake.statusPausedOnBattery")

    static func awakeStatusUntilProcess(_ pid: Int) -> LocalizedStringResource {
        Self.key("awake.statusUntilProcess \(pid)")
    }

    static func menuTooltip(_ status: String) -> LocalizedStringResource {
        Self.key("menu.tooltip \(status)")
    }
}
