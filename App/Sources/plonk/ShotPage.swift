import AppKit
import SwiftUI

// Screenshots: take one, mark it up, and lift the words out of anything that is
// only pixels.

struct ShotPage: View {
    @ObservedObject var model: AppModel
    @State private var folderDraft = ""

    var body: some View {
        PageShell(title: .pageShot, subtitle: .shotCaptureHelp) {
            SettingsCard(title: .shotCapture) {
                SettingBlock {
                    HStack(spacing: 8) {
                        Button(String(localized: .shotCaptureRegion)) { model.actions?.capture(.region) }
                            .buttonStyle(.borderedProminent)
                        Button(String(localized: .shotCaptureWindow)) { model.actions?.capture(.window) }
                        Button(String(localized: .shotCaptureScreen)) { model.actions?.capture(.screen) }
                    }
                }
            }
            SettingsCard(title: .commonShortcuts) {
                SettingBlock {
                    ShortcutRows(model: model,
                                 actions: HotkeyAction.owned(by: "shot").filter { $0.group != .crop })
                }
            }
            SettingsCard(title: .shotPinPart, note: .shotPinPartHelp) {
                SettingBlock {
                    ShortcutRows(model: model, actions: HotkeyAction.owned(by: "shot", group: .crop))
                }
            }
            SettingsCard(title: .shotText, note: .shotTextHelp) {
                SettingRow(title: .shotLanguage) {
                    Picker("", selection: language) {
                        Text(.shotLanguageAutomatic).tag("")
                        Divider()
                        ForEach(model.supportedTextLanguages, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .disabled(model.supportedTextLanguages.isEmpty)
                }
            }
            SettingsCard(title: .shotOutput) {
                ToggleRow(title: .shotCopyOnSave,
                          isOn: model.binding(\.shotCopyToClipboard,
                                              set: { $0.setShotCopyToClipboard($1) }))
                SettingRow(title: .shotSaveFolder) {
                    HStack(spacing: 7) {
                        // Committed on Return or when focus leaves, so typing a
                        // path does not rewrite the config on every keystroke.
                        TextField(text: $folderDraft) { Text(.shotSaveFolder) }
                            .textFieldStyle(.roundedBorder)
                            .labelsHidden()
                            .frame(width: 190)
                            .onSubmit(commitFolder)
                        Button(String(localized: .commonChoose), action: chooseFolder)
                    }
                    .controlSize(.small)
                }
                if !model.shotStatus.isEmpty {
                    SettingBlock {
                        Text(model.shotStatus).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear { folderDraft = model.shotFolder }
        .onChange(of: model.shotFolder) { folderDraft = $0 }
        .onDisappear(perform: commitFolder)
    }

    /// One language at a time here; the API takes the full list for callers
    /// that know they are looking at two.
    private var language: Binding<String> {
        Binding(
            get: { model.textLanguages.first ?? "" },
            set: { model.actions?.setTextLanguages($0.isEmpty ? [] : [$0]) }
        )
    }

    private func commitFolder() {
        let folder = folderDraft.trimmingCharacters(in: .whitespaces)
        guard !folder.isEmpty, folder != model.shotFolder else { return }
        model.actions?.setShotFolder(folder)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            folderDraft = url.path
            model.actions?.setShotFolder(url.path)
        }
    }
}
