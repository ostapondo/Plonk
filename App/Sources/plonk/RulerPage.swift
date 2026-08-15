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
                Text("Hover and Plonk measures how far the pointer can travel each way before it meets an edge: the width of a row, the height of a bar, the gap between two things. Two numbers, drawn on the two lines they belong to, because the run across and the run down are separate answers. Drag instead for a straight-line distance. Click copies, Space takes a fresh picture of the screen, Escape finishes. Needs Screen Recording access, the same as a screenshot.")
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
                    Text("Lower stops at fainter borders and finds smaller things; higher "
                         + "walks through more before it calls anything an edge.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Detection")
            } footer: {
                Text("How different one pixel has to be from the pixel beside it, on a scale of 255, before Plonk calls that boundary an edge. Ten suits most interfaces: gradients and shadows step by less, borders by more. Raise it for a photograph or a noisy video, where every pixel differs a little from the last.")
            }
        }
        .formStyle(.grouped)
        .onAppear { knob = Double(model.rulerEdgeTolerance) }
        .onChange(of: model.rulerEdgeTolerance) { knob = Double($0) }
    }
}
