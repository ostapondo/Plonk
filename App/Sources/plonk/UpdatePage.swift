import SwiftUI

struct UpdatePage: View {
    @ObservedObject var model: AppModel

    private var isBusy: Bool {
        ["checking", "downloading", "verifying", "installing"].contains(model.updatePhase)
    }

    private var hasUpdate: Bool { !model.updateAvailableVersion.isEmpty }

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Text(model.appVersion.isEmpty
                         ? String(localized: .updateUnbundled) : model.appVersion)
                } label: {
                    Text(.updateInstalled)
                }
                if hasUpdate {
                    LabeledContent {
                        Text(model.updateAvailableVersion)
                    } label: {
                        Text(.updateAvailable)
                    }
                }
                if !model.updateStatus.isEmpty {
                    Text(model.updateStatus)
                        .foregroundStyle(model.updatePhase == "failed" ? .red : .secondary)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if model.updatePhase == "downloading" {
                    ProgressView(value: model.updateProgress)
                }
                HStack {
                    if hasUpdate {
                        Button(String(localized: .updateInstallAndRelaunch)) { model.actions?.installUpdate() }
                            .buttonStyle(.borderedProminent)
                            .disabled(isBusy)
                    }
                    Button(String(localized: .updateCheckNow)) { model.actions?.checkForUpdates() }
                        .disabled(isBusy)
                    Button(String(localized: .updateReleaseNotes)) { model.actions?.openReleasePage() }
                }
            } footer: {
                Text(.updateInstallHelp)
            }
            if hasUpdate && !model.updateNotes.isEmpty {
                Section(String(localized: .updateWhatsNew(model.updateAvailableVersion))) {
                    ScrollView {
                        Text(model.updateNotes)
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 180)
                }
            }
            Section {
                Toggle(isOn: model.binding(\.updateCheckAutomatically,
                                           set: { $0.setUpdateCheckAutomatically($1) })) {
                    Text(LocalizedStringResource.updateAutomatically)
                    Text(.updateAutomaticallyDetail)
                }
            } footer: {
                Text(.updatePrivacy)
            }
        }
        .formStyle(.grouped)
    }
}
