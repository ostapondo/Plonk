import SwiftUI

// The Ruler page: the one button, the shortcut, and the single knob the
// measurement depends on.

struct RulerPage: View {
    @ObservedObject var model: AppModel

    private static let range =
        Double(EdgeDetector.toleranceRange.lowerBound)...Double(EdgeDetector.toleranceRange.upperBound)

    var body: some View {
        PageShell(title: .pageRuler, subtitle: .rulerHelp) {
            SettingsCard(title: .rulerTitle) {
                SettingBlock {
                    Button(String(localized: .rulerMeasure)) { model.actions?.startRuler() }
                        .buttonStyle(.borderedProminent)
                }
            }
            SettingsCard(title: .rulerShortcut) {
                SettingBlock {
                    ShortcutRows(model: model, actions: HotkeyAction.owned(by: "ruler"))
                }
            }
            SettingsCard(title: .rulerDetection, note: .rulerDetectionHelp) {
                // A count of grey levels, so no unit: "10 pt" would be a lie
                // and "10 %" a different one.
                MeasureRow(title: .rulerSensitivity, help: .rulerSensitivityHelp,
                           range: Self.range, unit: .plain,
                           value: Double(model.config.rulerEdgeTolerance)) {
                    model.actions?.update(\.rulerEdgeTolerance, to: Int($0))
                }
            }
        }
    }
}
