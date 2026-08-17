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
        PageShell(title: .pageShortcuts, subtitle: .keysHotkeysDetail) {
            SettingsCard {
                ToggleRow(title: .keysHotkeys,
                          isOn: model.binding(\.hotkeysEnabled, set: { $0.setHotkeys($1) }))
            }
            // Second on the page, not last. Someone who came from Rectangle is
            // here to move their setup over, and a button under nine groups of
            // shortcuts is a button they scroll past.
            fromRectangle
            Group {
                SettingsCard(title: .shortcutGroupGuide, note: .keysGuideHelp) {
                    SettingBlock {
                        ShortcutRows(model: model, actions: [.shortcutGuide])
                    }
                }
                SettingsCard(title: .keysPalette, note: .keysPaletteHelp) {
                    SettingBlock {
                        ShortcutRows(model: model, actions: [.commandPalette])
                    }
                }
                ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                    SettingsCard(title: group.name) {
                        ForEach(group.actions) { action in
                            SettingBlock { row(action) }
                        }
                    }
                }
                // Last, and only here: it throws away every binding above, so
                // it belongs after them rather than beside the way in.
                Button(String(localized: .keysRestoreDefaults)) { model.actions?.resetHotkeys() }
                    .controlSize(.small)
            }
            .opacity(model.hotkeysEnabled ? 1 : 0.5)
            .disabled(!model.hotkeysEnabled)
        }
    }

    /// The two halves of moving over, in one card.
    ///
    /// Only the import is dimmed with the keys. A URL runs its action whatever
    /// the keys are doing, so greying the switch would misdescribe the surface
    /// SECURITY.md documents.
    private var fromRectangle: some View {
        SettingsCard(title: .keysFromRectangle) {
            SettingRow(title: .keysImportRectangle, detail: .keysImportRectangleHelp) {
                Button(String(localized: .keysImportRectangleButton)) {
                    model.actions?.importFromRectangle()
                }
            }
            .opacity(model.hotkeysEnabled ? 1 : 0.5)
            .disabled(!model.hotkeysEnabled)
            ToggleRow(title: .keysRectangleURLs,
                      detail: .keysRectangleURLsHelp,
                      isOn: model.binding(\.handleRectangleURLs,
                                          set: { $0.setRectangleURLs($1) }))
        }
    }

    private func row(_ action: HotkeyAction) -> some View {
        Button {
            model.selectedPage = action.page
        } label: {
            HStack(spacing: 10) {
                Text(action.title).font(.system(size: 12.5))
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
                    .muted()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(String(localized: .keysSetOnPage(pageTitle(action.page))))
    }

}
