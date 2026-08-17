import SwiftUI

// The Ruler page: the one button, the shortcut, and the single knob the
// measurement depends on.

struct RulerPage: View {
    @ObservedObject var model: AppModel
    /// The slider's own value while it is being dragged. Committing per frame
    /// would rewrite config a hundred times on the way to one number.
    @State private var knob = Double(EdgeDetector.defaultTolerance)

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
                SettingRow(title: .rulerSensitivity, detail: .rulerSensitivityHelp, stacked: true) {
                    HStack(spacing: 10) {
                        Slider(value: $knob, in: Self.range,
                               onEditingChanged: { editing in
                                   guard !editing else { return }
                                   model.actions?.update(\.rulerEdgeTolerance, to: Int(knob.rounded()))
                               })
                            .labelsHidden()
                            .controlSize(.small)
                        Text("\(Int(knob.rounded()))")
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }
        }
        .onAppear { knob = Double(model.config.rulerEdgeTolerance) }
        .onChange(of: model.config.rulerEdgeTolerance) { knob = Double($0) }
    }
}
