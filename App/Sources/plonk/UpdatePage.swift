import SwiftUI

// What is installed, what is on offer, and the one outbound connection the app
// is allowed to make.

struct UpdatePage: View {
    @ObservedObject var model: AppModel

    private var isBusy: Bool {
        ["checking", "downloading", "verifying", "installing"].contains(model.updatePhase)
    }

    private var hasUpdate: Bool { !model.updateAvailableVersion.isEmpty }

    var body: some View {
        PageShell(title: .pageUpdate, subtitle: .updateInstallHelp) {
            SettingsCard {
                SettingRow(title: .updateInstalled) {
                    Text(model.appVersion.isEmpty
                         ? String(localized: .updateUnbundled) : model.appVersion)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                if hasUpdate {
                    SettingRow(title: .updateAvailable) {
                        Text(model.updateAvailableVersion)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                SettingBlock {
                    if !model.updateStatus.isEmpty {
                        Text(model.updateStatus)
                            .font(.system(size: 12))
                            .foregroundStyle(model.updatePhase == "failed" ? .red : .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if model.updatePhase == "downloading" {
                        ProgressView(value: model.updateProgress)
                    }
                    HStack(spacing: 8) {
                        if hasUpdate {
                            Button(String(localized: .updateInstallAndRelaunch)) {
                                model.actions?.installUpdate()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isBusy)
                        }
                        Button(String(localized: .updateCheckNow)) { model.actions?.checkForUpdates() }
                            .disabled(isBusy)
                        Button(String(localized: .updateReleaseNotes)) { model.actions?.openReleasePage() }
                    }
                    .controlSize(.small)
                }
            }
            if hasUpdate && !model.updateNotes.isEmpty {
                SettingsCard(title: .updateWhatsNew(model.updateAvailableVersion)) {
                    SettingBlock {
                        ScrollView {
                            Text(model.updateNotes)
                                .font(.system(size: 12))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 180)
                    }
                }
            }
            SettingsCard(note: .updatePrivacy) {
                ToggleRow(title: .updateAutomatically,
                          detail: .updateAutomaticallyDetail,
                          isOn: model.binding(\.updateCheckAutomatically,
                                              set: { $0.setUpdateCheckAutomatically($1) }))
            }
        }
    }
}
