import SwiftUI

// The field the settings pages measure with. The pages themselves live one per
// file, beside the module each belongs to.

/// A whole number of points, with a knob for the rough shape of it and a field
/// for the exact value. Dragging is quicker when the answer is "a bit more";
/// typing is the only way when the answer is 12.
///
/// Deliberately not a `LabeledContent`: that renders its content as a value
/// rather than a control, so the field looked like static text and never took
/// focus. A bordered box that is plainly a box is the point.
///
/// Nothing invalid reaches config. Only digits can be typed at all, so a stray
/// letter never lands in the field; anything still wrong once it is — out of
/// range, or long enough to overflow — says so and stays put to be corrected
/// rather than silently rounded into something nobody asked for. An empty
/// field is zero.
struct PointsField: View {
    let title: LocalizedStringResource
    let help: LocalizedStringResource
    let placeholder: String
    let range: ClosedRange<Int>
    let value: Double
    let commit: (Double) -> Void

    @State private var draft = ""
    @State private var knob = 0.0
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        // Two lines rather than one: a form row splits itself into a label and
        // a control, and a row holding a label, a slider and a field made that
        // split guess wrong — the field wrapped onto its own line and the
        // placeholder came out as a stray label beside it. The name and the
        // exact value share the top line, the knob gets the width of the row,
        // which is what the system's own sliders do.
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                Text(title)
                Spacer(minLength: 12)
                // `prompt`, not the title argument: on macOS the title is drawn
                // beside the box, so a placeholder passed there becomes a label.
                TextField(text: $draft, prompt: Text(placeholder)) { EmptyView() }
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 56)
                    .focused($focused)
                    .onSubmit(commitDraft)
                    .onChange(of: draft) { typed in
                        let digits = typed.filter(\.isNumber)
                        if digits != typed { draft = digits }
                    }
                Text(.commonPoints).foregroundStyle(.secondary)
            }
            // onEditingChanged spelled out rather than trailing, and no `step:`
            // — that draws tick marks, and the rounding belongs to the value.
            Slider(value: $knob,
                   in: Double(range.lowerBound)...Double(range.upperBound),
                   onEditingChanged: { editing in
                       guard !editing else { return }
                       error = nil
                       commit(knob.rounded())
                   })
                .labelsHidden()
                .controlSize(.small)
            Text(help)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .onAppear { adopt(value) }
        .onChange(of: value) { adopt($0) }
        // The field follows the knob as it moves, so the number being chosen is
        // always readable; nothing is written until the knob is let go.
        .onChange(of: knob) { draft = String(Int($0.rounded())) }
        // Committed when the field is left or Return is pressed, not per
        // keystroke: "1" on the way to "16" is a valid number, and saving it
        // would rewrite config twice and move every snapped window through a
        // size nobody asked for.
        .onChange(of: focused) { if !$0 { commitDraft() } }
    }

    private func adopt(_ number: Double) {
        knob = min(max(number, Double(range.lowerBound)), Double(range.upperBound))
        draft = String(Int(number))
    }

    private func commitDraft() {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            error = nil
            adopt(0)
            commit(0)
            return
        }
        guard let number = Int(trimmed) else {
            error = String(localized: .pointsNotWhole(String(localized: title)))
            return
        }
        guard range.contains(number) else {
            error = String(localized: .pointsOutOfRange(String(localized: title),
                                                        range.lowerBound, range.upperBound))
            return
        }
        error = nil
        knob = Double(number)
        commit(Double(number))
    }
}
