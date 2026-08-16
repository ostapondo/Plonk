import AppKit
import SwiftUI

// Agents and MCP: who is connected, how to connect one, and what to say to it.

struct AIPage: View {
    @ObservedObject var model: AppModel
    @State private var copied: String?

    /// Everything the picker can offer: whoever is online, plus the current
    /// pick even when its session is gone, so it can still be cleared.
    private var agentChoices: [String] {
        var names = model.connectedAgents
        if let selected = model.selectedAgent, !names.contains(selected) { names.append(selected) }
        return names
    }

    private var selectedAgent: Binding<String> {
        Binding(
            get: { model.selectedAgent ?? "" },
            set: { model.actions?.selectAgent($0.isEmpty ? nil : $0) }
        )
    }

    var body: some View {
        PageShell(title: .pageAI, subtitle: .aiAgentsHelp) {
            // With nothing connected there is no picker worth showing, and the
            // useful card is the command that connects something — so that goes
            // first until it has been run.
            if agentChoices.isEmpty {
                connect
                agents
            } else {
                agents
                connect
            }
            examples
        }
    }

    @ViewBuilder
    private var agents: some View {
        SettingsCard(title: .aiAgents) {
            if agentChoices.isEmpty {
                SettingBlock {
                    Text(.aiNoAgents)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                SettingRow(title: .aiActiveAgent) {
                    Picker("", selection: selectedAgent) {
                        Text(.aiAnyAgent).tag("")
                        Divider()
                        ForEach(agentChoices, id: \.self) { name in
                            Text(model.connectedAgents.contains(name)
                                 ? name
                                 : String(localized: .aiAgentOffline(name))).tag(name)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                ToggleRow(title: .aiExclusive,
                          detail: .aiExclusiveHelp,
                          isOn: model.binding(\.agentExclusive, set: { $0.setAgentExclusive($1) }))
                    .disabled(model.selectedAgent == nil)
            }
        }
    }

    private var connect: some View {
        SettingsCard(title: .aiConnect, note: .aiConnectHelp) {
            SettingRow(title: .aiLocalApi) {
                Text("127.0.0.1:\(ControlServer.port)")
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            command("Claude Code", "claude mcp add plonk -- npx -y plonk-mcp")
            command("Codex CLI", "codex mcp add plonk -- npx -y plonk-mcp")
            command(String(localized: .aiAnyMcpClient),
                    "command: npx, args: [\"-y\", \"plonk-mcp\"]")
        }
    }

    private func command(_ client: String, _ line: String) -> some View {
        SettingBlock {
            VStack(alignment: .leading, spacing: 4) {
                Text(client).font(.system(size: 12.5))
                Text(line)
                    .font(.system(size: 11.5, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var examples: some View {
        SettingsCard(title: .aiTrySaying,
                     note: copied == nil ? .aiClickToCopy : .aiCopied) {
            ForEach(Array(LocalizedStringResource.aiExamples.enumerated()), id: \.offset) { _, example in
                SettingBlock {
                    Button {
                        let sentence = String(localized: example)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(sentence, forType: .string)
                        copied = sentence
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: "quote.bubble")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.accentColor)
                            Text(example).font(.system(size: 12.5))
                            Spacer(minLength: 8)
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                                .muted()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
