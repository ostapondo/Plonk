import SwiftUI

// Every binding in one place. Editing happens on the page that owns the
// shortcut, so there is only ever one editor per action; this reads the same
// live bindings, which is what keeps the two views in step. A row carries the
// page it is set on and goes there when clicked.

struct ShortcutsPage: View {
    @ObservedObject var model: AppModel

    private var groups: [(name: LocalizedStringResource, actions: [HotkeyAction])] {
        var order: [HotkeyAction.Group] = []
        var byGroup: [HotkeyAction.Group: [HotkeyAction]] = [:]
        // The Guide has its own editable section above; listing it again here
        // would show the same row twice.
        for action in HotkeyAction.allCases where action.page != "shortcuts" {
            if !order.contains(action.group) { order.append(action.group) }
            byGroup[action.group, default: []].append(action)
        }
        return order.map { ($0.title, byGroup[$0] ?? []) }
    }

    private func pageTitle(_ id: String) -> String {
        guard let title = model.settingsPages.first(where: { $0.id == id })?.title else { return id }
        return String(localized: title)
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: model.binding(\.hotkeysEnabled, set: { $0.setHotkeys($1) })) {
                    Text(LocalizedStringResource.keysHotkeys)
                    Text(.keysHotkeysDetail)
                }
            }
            Section {
                ShortcutRows(model: model, actions: [.shortcutGuide])
            } header: {
                Text(.shortcutGroupGuide)
            } footer: {
                Text(.keysGuideHelp)
            }
            Section {
                ShortcutRows(model: model, actions: [.commandPalette])
            } header: {
                Text(.keysPalette)
            } footer: {
                Text(.keysPaletteHelp)
            }
            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                Section(String(localized: group.name)) {
                    ForEach(group.actions) { row($0) }
                }
            }
            Section {
                Button(String(localized: .keysRestoreDefaults)) { model.actions?.resetHotkeys() }
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
                        .help(String(localized: .shortcutAlreadyTaken))
                }
                KeyCaps(parts: model.hotkeyParts[action.rawValue] ?? [], showsNone: true)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(String(localized: .keysSetOnPage(pageTitle(action.page))))
    }

}
