import SwiftUI

// One switch per module. The same list as the Features submenu in the menu
// bar, with a line under each name saying what it covers; both read and write
// Config.disabledFeatures, so neither can disagree with the other.

struct FeaturesPage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        PageShell(title: .pageFeatures, subtitle: .featuresHelp) {
            SettingsCard(title: .featuresSwitches) {
                ForEach(Feature.allCases) { feature in
                    SettingRow(title: feature.title, detail: feature.detail) {
                        Toggle("", isOn: model.binding(feature))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                }
            }
        }
    }
}
