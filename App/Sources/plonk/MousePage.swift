import SwiftUI

// Pointer and clicks: the tools that only ever read the mouse.

struct MousePage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        PageShell(title: .pageMouse, subtitle: .mousePointerHelp) {
            SettingsCard(title: .mousePointer) {
                ToggleRow(title: .mouseRingClicks,
                          detail: .mouseRingClicksHelp,
                          isOn: model.binding(\.highlightClicksEnabled,
                                              set: { $0.setHighlightClicks($1) }))
                ToggleRow(title: .mouseCrosshairs,
                          detail: .mouseCrosshairsHelp,
                          isOn: model.binding(\.crosshairsEnabled, set: { $0.setCrosshairs($1) }))
            }
            SettingsCard(title: .commonShortcuts, note: .mouseShortcutsHelp) {
                SettingBlock {
                    ShortcutRows(model: model, actions: HotkeyAction.owned(by: "mouse"))
                }
            }
        }
    }
}
