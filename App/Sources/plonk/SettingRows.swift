import SwiftUI

// The pieces a settings page is built from now that pages are cards on a page
// rather than a macOS grouped Form.
//
// A Form gives every row the same split between a label and a control, which is
// why the old pages had sliders wrapping onto their own line and 84-point
// fields stretched across the window. These rows decide their own layout, and
// the card decides where the lines between them go.

/// Every page opens the same way: what it is, in display weight, and one line
/// saying what it is for. Zones names the set, Workspaces names itself, and the
/// rest follow — a page that opened straight into a list of switches gave no
/// answer to "what is this page", which is the question a sidebar entry asks.
struct PageShell<Content: View>: View {
    let title: LocalizedStringResource
    var subtitle: LocalizedStringResource?
    @ViewBuilder var content: Content

    var body: some View {
        // Lazy, here and on the pages that own their scroll view: a page is
        // laid out card by card as it scrolls into view, so opening it costs
        // the cards on screen and not the whole page. Zones went from half a
        // second to under a tenth.
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 26, weight: .heavy))
                        .kerning(-0.7)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }
}

/// A card of rows with an optional heading and a note underneath.
struct SettingsCard<Content: View>: View {
    var title: LocalizedStringResource?
    var note: LocalizedStringResource?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            // Leading, and stated: a bare VStack centres its children, so any
            // block narrower than the card drifted into the middle of it.
            VStack(alignment: .leading, spacing: 0) {
                if let title {
                    HStack {
                        Eyebrow(title)
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
                    .muted()
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
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(alignment: .leading, spacing: 8) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
        }
    }
}
