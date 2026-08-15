import SwiftUI

// The pieces a settings page is built from now that pages are cards on a page
// rather than a macOS grouped Form.
//
// A Form gives every row the same split between a label and a control, which is
// why the old pages had sliders wrapping onto their own line and 84-point
// fields stretched across the window. These rows decide their own layout, and
// the card decides where the lines between them go.

/// A card of rows with an optional heading and a note underneath.
struct SettingsCard<Content: View>: View {
    var title: LocalizedStringResource?
    var note: LocalizedStringResource?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            VStack(spacing: 0) {
                if let title {
                    HStack {
                        Text(String(localized: title).uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .kerning(0.8)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .padding(.horizontal, 13)
                    .padding(.top, 11)
                    .padding(.bottom, 9)
                }
                content
            }
            .card()
            if let note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 3)
            }
        }
    }
}

/// One row: a name, an optional second line, and whatever control belongs on
/// the right. The hairline is drawn above, so a card never ends with one.
struct SettingRow<Trailing: View>: View {
    let title: LocalizedStringResource
    var detail: LocalizedStringResource?
    /// Rows that hold a wide control put it under the title instead of beside it.
    var stacked = false
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            if stacked {
                VStack(alignment: .leading, spacing: 8) {
                    labels
                    trailing
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
            } else {
                HStack(spacing: 12) {
                    labels
                    Spacer(minLength: 12)
                    trailing
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
            }
        }
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 12.5))
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ToggleRow: View {
    let title: LocalizedStringResource
    var detail: LocalizedStringResource?
    @Binding var isOn: Bool

    var body: some View {
        SettingRow(title: title, detail: detail) {
            Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
    }
}

/// A choice small enough to show every option at once.
struct SegmentedRow<Tag: Hashable>: View {
    let title: LocalizedStringResource
    var detail: LocalizedStringResource?
    @Binding var selection: Tag
    let options: [(label: LocalizedStringResource, tag: Tag)]
    /// Long option labels need the width of the row rather than the right-hand
    /// third of it.
    var stacked = false

    var body: some View {
        SettingRow(title: title, detail: detail, stacked: stacked) {
            Picker("", selection: $selection) {
                ForEach(options, id: \.tag) { option in
                    Text(option.label).tag(option.tag)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize(horizontal: !stacked, vertical: false)
        }
    }
}

/// Anything that is not a row: a shortcut list, a colour picker, an editor.
/// Keeps the padding and the hairline consistent with the rows around it.
struct SettingBlock<Content: View>: View {
    var inset = true
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(alignment: .leading, spacing: 8) { content }
                .padding(.horizontal, inset ? 13 : 0)
                .padding(.vertical, 10)
        }
    }
}
