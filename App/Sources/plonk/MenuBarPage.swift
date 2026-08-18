import SwiftUI

// Menu bar tidy: turn it on, and say which icons stay and which go.

struct MenuBarPage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        PageShell(title: .menuBarTitle, subtitle: .menuBarSubtitle) {
            SettingsCard {
                ToggleRow(title: .menuBarEnable, detail: .menuBarEnableHelp,
                          isOn: model.binding(\.menuBarEnabled))
                if model.config.menuBarEnabled {
                    ToggleRow(title: .menuBarCollapsed, detail: .menuBarCollapsedHelp,
                              isOn: model.binding(\.menuBarCollapsed))
                }
            }
            SettingsCard(title: .menuBarItems, note: .menuBarItemsHelp) {
                if !model.config.menuBarEnabled {
                    SettingBlock {
                        Text(.menuBarEmpty).font(.caption).muted()
                    }
                } else {
                    ForEach(model.menuBarItems) { item in
                        SettingRow(title: LocalizedStringResource(stringLiteral: item.appName)) {
                            Text(item.hidden ? LocalizedStringResource.menuBarHidden : .menuBarVisible)
                                .font(.caption)
                                .foregroundStyle(item.hidden ? .secondary : .primary)
                        }
                    }
                    SettingBlock {
                        Button(String(localized: .menuBarRefresh)) {
                            model.actions?.refreshMenuBarItems()
                        }
                    }
                }
            }
        }
        .onAppear { model.actions?.refreshMenuBarItems() }
        .onChange(of: model.config.menuBarEnabled) { _ in
            // The pair needs a layout pass before the bar can be read.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                model.actions?.refreshMenuBarItems()
            }
        }
    }
}
