import SwiftUI

// Keep awake: hold the Mac up, and say when to let it go again.

struct AwakePage: View {
    @ObservedObject var model: AppModel

    private var timeout: Binding<Int> {
        model.binding(\.awakeTimeoutMinutes, set: { $0.setAwakeTimeout(minutes: $1) })
    }

    var body: some View {
        PageShell(title: .pageAwake, subtitle: .awakeMenuBarGlow) {
            SettingsCard {
                ToggleRow(title: .awakeKeepNow,
                          detail: model.awakeRequested && !model.awakeOn
                              ? LocalizedStringResource.awakePausedOnBattery : nil,
                          isOn: model.binding(\.awakeRequested, set: { $0.setAwake($1) }))
                SettingRow(title: .awakeTurnOffAfter) {
                    Picker("", selection: timeout) {
                        Text(.awakeNever).tag(0)
                        Text(.awakeAfter15Minutes).tag(15)
                        Text(.awakeAfter30Minutes).tag(30)
                        Text(.awakeAfter1Hour).tag(60)
                        Text(.awakeAfter2Hours).tag(120)
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
            SettingsCard(title: .awakePower) {
                ToggleRow(title: .awakeKeepDisplayOn,
                          detail: .awakeKeepDisplayOnHelp,
                          isOn: model.binding(\.awakeKeepDisplayOn,
                                              set: { $0.setAwakeKeepDisplayOn($1) }))
                ToggleRow(title: .awakeAllowOnBattery,
                          detail: .awakeAllowOnBatteryHelp,
                          isOn: model.binding(\.awakeAllowOnBattery,
                                              set: { $0.setAwakeAllowOnBattery($1) }))
                ToggleRow(title: .awakeAutoWhileCharging,
                          detail: .awakeAutoWhileChargingHelp,
                          isOn: model.binding(\.awakeAutoWhileCharging,
                                              set: { $0.setAwakeAutoWhileCharging($1) }))
            }
        }
    }
}
