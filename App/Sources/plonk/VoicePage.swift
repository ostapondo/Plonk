import SwiftUI

// Voice: hold a key, say where the window goes. Recognition runs on this Mac.

struct VoicePage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        PageShell(title: .pageVoice, subtitle: .voicePushToTalkHelp) {
            SettingsCard(title: .voicePushToTalk) {
                SettingBlock {
                    ShortcutRows(model: model, actions: HotkeyAction.owned(by: "voice"))
                }
            }
            SettingsCard(title: .voiceStraightToPlonk, note: .voiceStraightToPlonkHelp) {
                ToggleRow(title: .voiceRunCommonHere,
                          detail: .voiceRunCommonHereHelp,
                          isOn: model.binding(\.voiceLocalCommands,
                                              set: { $0.setVoiceLocalCommands($1) }))
                SettingBlock {
                    ForEach(Array(LocalizedStringResource.voiceExamples.enumerated()),
                            id: \.offset) { _, example in
                        Text(example)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            SettingsCard(title: .voiceToTheAgent) {
                SettingBlock {
                    Text(.voiceToTheAgentHelp)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
