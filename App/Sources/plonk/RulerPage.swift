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
                Button("Measure the Screen") { model.actions?.startRuler() }
            } header: {
                Text("Ruler")
            } footer: {
                Text("Hover and Plonk finds the edges of whatever is under the pointer and gives you its size. Drag for a straight-line distance. Click to copy the number, Escape to finish. The screen is photographed once when the ruler opens, so what is being measured holds still; reopen it after the screen changes. Needs Screen Recording access, the same as a screenshot.")
            }
            Section {
                ShortcutRows(model: model, actions: HotkeyAction.owned(by: "ruler"))
            } header: {
                Text("Shortcut")
            }
            Section {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("Edge sensitivity")
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
                    Text("Lower finds smaller things and stops at fainter borders; higher walks "
                         + "through gradients and shadows to the edge you meant.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Detection")
            } footer: {
                Text("How different a pixel has to be from the one under the pointer, on a scale of 255, before Plonk calls it the edge. Text and thin borders want a low number; a window over a photograph wants a high one.")
            }
        }
        .formStyle(.grouped)
        .onAppear { knob = Double(model.rulerTolerance) }
        .onChange(of: model.rulerTolerance) { knob = Double($0) }
    }
}
