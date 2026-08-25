import SwiftUI

// The row every measurement on a settings page is drawn as.
//
// Three shapes were doing this job: a points field that took three lines for
// one number, a bare slider with nothing to read, and a slider hand-built
// beside its own label on the page that needed one. A column of settings that
// changes its mind about what a number looks like is the thing this replaces.
//
// Both affordances stay. Dragging is quicker when the answer is "a bit more";
// typing is the only way when the answer is 12.

/// A number with a range, on one line: the name, a knob, and the exact value.
///
/// Nothing invalid reaches config. Only digits can be typed at all, so a stray
/// letter never lands in the field; anything still wrong once it is — out of
/// range, or long enough to overflow — says so and stays put to be corrected
/// rather than silently rounded into something nobody asked for. An empty
/// field is the bottom of the range.
struct MeasureRow: View {
    /// What the number is counted in. Percent is the only one that is not the
    /// stored value: config keeps an opacity as a fraction and a person reads
    /// it as a percentage, so the field scales up and the commit scales back.
    enum Unit {
        case points, percent, plain

        var suffix: LocalizedStringResource? {
            switch self {
            case .points: return .commonPoints
            case .percent: return .commonPercent
            case .plain: return nil
            }
        }

        var scale: Double { self == .percent ? 100 : 1 }
    }

    let title: LocalizedStringResource
    /// What used to be a line of help under the row. A tooltip now: one
    /// sentence per measurement is most of what made these rows tall.
    var help: LocalizedStringResource?
    /// In stored units, not shown ones.
    let range: ClosedRange<Double>
    var unit = Unit.points
    let value: Double
    let commit: (Double) -> Void

    @State private var draft = ""
    @State private var knob = 0.0
    @State private var error: LocalizedStringResource?
    @FocusState private var focused: Bool

    /// The same range in the units the field and the knob work in.
    private var shown: ClosedRange<Double> {
        (range.lowerBound * unit.scale).rounded()...(range.upperBound * unit.scale).rounded()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Applied only when there is something to say: `.help("")` sets an
            // empty tooltip rather than none, which hovers as a bare box.
            if let help {
                line.help(String(localized: help))
            } else {
                line
            }
            if let error {
                Label { Text(error) } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.caption)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 13)
                .padding(.bottom, 9)
            }
        }
        .onAppear { adopt(value) }
        .onChange(of: value) { adopt($0) }
        // The field follows the knob as it moves, so the number being chosen is
        // always readable; nothing is written until the knob is let go.
        .onChange(of: knob) { draft = String(Int($0.rounded())) }
        .onChange(of: focused) { if !$0 { commitDraft() } }
    }

    private var line: some View {
        SettingRow(title: title) {
            HStack(spacing: 9) {
                // onEditingChanged spelled out rather than trailing, and no
                // `step:` — that draws tick marks, and the rounding belongs
                // to the value. Written when the knob is let go, not while
                // it moves: every write clamps, saves and hands the whole
                // config to every manager.
                Slider(value: $knob, in: shown,
                       onEditingChanged: { editing in
                           guard !editing else { return }
                           error = nil
                           commit(knob.rounded() / unit.scale)
                       })
                    .labelsHidden()
                    .frame(width: 132)
                // Committed when the field is left or Return is pressed,
                // not per keystroke: "1" on the way to "16" is a valid
                // number, and saving it would rewrite config twice and move
                // every snapped window through a size nobody asked for.
                TextField(text: $draft) { EmptyView() }
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 52)
                    .focused($focused)
                    .onSubmit(commitDraft)
                    .onChange(of: draft) { typed in
                        let digits = typed.filter(\.isNumber)
                        if digits != typed { draft = digits }
                    }
                if let suffix = unit.suffix {
                    Text(suffix)
                        .foregroundStyle(.secondary)
                        .frame(width: 15, alignment: .leading)
                }
            }
            .controlSize(.small)
        }
    }

    private func adopt(_ number: Double) {
        let scaled = (number * unit.scale).rounded()
        knob = scaled.clamped(to: shown)
        draft = String(Int(scaled))
    }

    private func commitDraft() {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            error = nil
            adopt(range.lowerBound)
            commit(range.lowerBound)
            return
        }
        guard let number = Int(trimmed) else {
            error = .pointsNotWhole(String(localized: title))
            return
        }
        guard shown.contains(Double(number)) else {
            error = .pointsOutOfRange(String(localized: title),
                                      Int(shown.lowerBound), Int(shown.upperBound))
            return
        }
        error = nil
        knob = Double(number)
        commit(Double(number) / unit.scale)
    }
}
