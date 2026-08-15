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
        Form {
            Section {
                Button(String(localized: .rulerMeasure)) { model.actions?.startRuler() }
            } header: {
                Text(.rulerTitle)
            } footer: {
                Text(.rulerHelp)
            }
            Section {
                ShortcutRows(model: model, actions: HotkeyAction.owned(by: "ruler"))
            } header: {
                Text(.rulerShortcut)
            }
            Section {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(.rulerSensitivity)
                        Spacer()
                        Text("\(Int(knob.rounded()))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $knob, in: Self.range,
                           onEditingChanged: { editing in
                               guard !editing else { return }
                               model.actions?.setRulerTolerance(Int(knob.rounded()))
                           })
                        .labelsHidden()
                        .controlSize(.small)
                    Text(.rulerSensitivityHelp)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(.rulerDetection)
            } footer: {
                Text(.rulerDetectionHelp)
            }
        }
        .formStyle(.grouped)
        .onAppear { knob = Double(model.rulerEdgeTolerance) }
        .onChange(of: model.rulerEdgeTolerance) { knob = Double($0) }
    }
}
