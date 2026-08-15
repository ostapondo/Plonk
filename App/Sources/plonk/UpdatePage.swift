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
                LabeledContent("Installed") { Text(model.appVersion.isEmpty ? "unbundled" : model.appVersion) }
                if hasUpdate {
                    LabeledContent("Available") { Text(model.updateAvailableVersion) }
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
                        Button("Install and Relaunch") { model.actions?.installUpdate() }
                            .buttonStyle(.borderedProminent)
                            .disabled(isBusy)
                    }
                    Button("Check Now") { model.actions?.checkForUpdates() }
                        .disabled(isBusy)
                    Button("Release Notes") { model.actions?.openReleasePage() }
                }
            } footer: {
                Text("""
                Installing downloads the release from GitHub, checks it is signed with the same \
                certificate as this copy, and swaps it in — so the permissions you have already \
                granted carry over. A build that fails that check is discarded and nothing is replaced.
                """)
            }
            if hasUpdate && !model.updateNotes.isEmpty {
                Section("What's New in \(model.updateAvailableVersion)") {
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
                    Text("Check for updates automatically")
                    Text("On launch, once a day, and when the network comes back")
                }
            } footer: {
                Text("""
                This is the only thing Plonk connects out for. The check asks api.github.com for the \
                latest release and sends nothing but a User-Agent naming the app and its version — \
                no identifier, no account, no telemetry. Turn it off and nothing here reaches the \
                network on its own, and an agent asking for a check is refused: the buttons above \
                are the only way one happens.
                """)
            }
        }
        .formStyle(.grouped)
    }
}
