import SwiftUI

// Every binding in one place. Editing happens on the page that owns the
// shortcut, so there is only ever one editor per action; this reads the same
// live bindings, which is what keeps the two views in step. A row carries the
// page it is set on and goes there when clicked.

struct ShortcutsPage: View {
    @ObservedObject var model: AppModel

    private var groups: [(name: String, actions: [HotkeyAction])] {
        var order: [String] = []
        var byGroup: [String: [HotkeyAction]] = [:]
        for action in HotkeyAction.allCases {
            if !order.contains(action.group) { order.append(action.group) }
            byGroup[action.group, default: []].append(action)
        }
        return order.map { ($0, byGroup[$0] ?? []) }
    }

    private func pageTitle(_ id: String) -> String {
        model.settingsPages.first { $0.id == id }?.title ?? id
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: model.binding(\.hotkeysEnabled, set: { $0.setHotkeys($1) })) {
                    Text("Hotkeys")
                    Text("Click a shortcut to open the page where it is set.")
                }
            }
            Section {
                ShortcutRows(model: model, actions: HotkeyAction.owned(by: "shortcuts"))
            } header: {
                Text("Guide")
            } footer: {
                Text("Opens every shortcut the app in front actually has, read from its own menus — so it is never out of date, and it works for software with no documentation at all. Press it again to close.")
            }
            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                Section(group.name) {
                    ForEach(group.actions) { row($0) }
                }
            }
            Section {
                Button("Restore Defaults") { model.actions?.resetHotkeys() }
            }
        }
        .formStyle(.grouped)
        .opacity(model.hotkeysEnabled ? 1 : 0.5)
    }

    private func row(_ action: HotkeyAction) -> some View {
        Button {
            model.selectedPage = action.page
        } label: {
            HStack(spacing: 10) {
                Text(action.title)
                Spacer(minLength: 12)
                if model.unavailableHotkeys.contains(action.rawValue) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .help("Another app already owns this combination")
                }
                keyCaps(model.hotkeyParts[action.rawValue] ?? [])
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Set on the \(pageTitle(action.page)) page")
    }

    private func keyCaps(_ parts: [String]) -> some View {
        HStack(spacing: 3) {
            if parts.isEmpty {
                Text("None").font(.caption).foregroundStyle(.tertiary)
            }
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                Text(part)
                    .font(.system(size: 11, weight: .medium))
                    .frame(minWidth: 13)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.07)))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.primary.opacity(0.13)))
            }
        }
    }
}
