import Foundation

// Keep awake, and the pages under Settings that have no module of their own.
// English values live in Resources/en.lproj/Localizable.strings.

extension LocalizedStringResource {
    static let featuresHelp = Self.key("features.help")
    static let featuresSwitches = Self.key("features.switches")
    static let featureZonesDetail = Self.key("feature.zonesDetail")
    static let featureWorkspacesDetail = Self.key("feature.workspacesDetail")
    static let featureShotDetail = Self.key("feature.shotDetail")
    static let featureMouseDetail = Self.key("feature.mouseDetail")
    static let featureRulerDetail = Self.key("feature.rulerDetail")
    static let featureVoiceDetail = Self.key("feature.voiceDetail")
    static let featureAwakeDetail = Self.key("feature.awakeDetail")
    static let featureActiveDetail = Self.key("feature.activeDetail")

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
