import Foundation

// The pages under Settings that have no module of their own.
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

    static func menuTooltip(_ status: String) -> LocalizedStringResource {
        Self.key("menu.tooltip \(status)")
    }
}
