import SwiftUI

// The pages that are still macOS forms. Home, Zones and Appearance have
// pages of their own; these follow as each is redrawn.

struct AwakePage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle(isOn: model.binding(\.awakeRequested, set: { $0.setAwake($1) })) {
                    Text(LocalizedStringResource.awakeKeepNow)
                    Text(model.awakeRequested && !model.awakeOn
                         ? LocalizedStringResource.awakePausedOnBattery
                         : .awakeMenuBarGlow)
                }
                Picker(String(localized: .awakeTurnOffAfter),
                       selection: model.binding(\.awakeTimeoutMinutes, set: { $0.setAwakeTimeout(minutes: $1) })) {
                    Text(.awakeNever).tag(0)
                    Text(.awakeAfter15Minutes).tag(15)
                    Text(.awakeAfter30Minutes).tag(30)
                    Text(.awakeAfter1Hour).tag(60)
                    Text(.awakeAfter2Hours).tag(120)
                }
            }
            Section(String(localized: .awakePower)) {
                Toggle(isOn: model.binding(\.awakeKeepDisplayOn, set: { $0.setAwakeKeepDisplayOn($1) })) {
                    Text(.awakeKeepDisplayOn)
                    Text(.awakeKeepDisplayOnHelp)
                }
                Toggle(isOn: model.binding(\.awakeAllowOnBattery, set: { $0.setAwakeAllowOnBattery($1) })) {
                    Text(.awakeAllowOnBattery)
                    Text(.awakeAllowOnBatteryHelp)
                }
                Toggle(isOn: model.binding(\.awakeAutoWhileCharging, set: { $0.setAwakeAutoWhileCharging($1) })) {
                    Text(.awakeAutoWhileCharging)
                    Text(.awakeAutoWhileChargingHelp)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct ShotPage: View {
    @ObservedObject var model: AppModel
    @State private var folderDraft = ""

    var body: some View {
        Form {
            Section {
                Button(String(localized: .shotCaptureRegion)) { model.actions?.capture(.region) }
                Button(String(localized: .shotCaptureWindow)) { model.actions?.capture(.window) }
                Button(String(localized: .shotCaptureScreen)) { model.actions?.capture(.screen) }
            } header: {
                Text(.shotCapture)
            } footer: {
                Text(.shotCaptureHelp)
            }
            Section {
                ShortcutRows(model: model,
                             actions: HotkeyAction.owned(by: "shot").filter { $0.group != .crop })
            } header: {
                Text(.commonShortcuts)
            }
            Section {
                ShortcutRows(model: model, actions: HotkeyAction.owned(by: "shot", group: .crop))
            } header: {
                Text(.shotPinPart)
            } footer: {
                Text(.shotPinPartHelp)
            }
            Section {
                Picker(String(localized: .shotLanguage), selection: language) {
                    Text(.shotLanguageAutomatic).tag("")
                    Divider()
                    ForEach(model.supportedTextLanguages, id: \.self) { Text($0).tag($0) }
                }
                .disabled(model.supportedTextLanguages.isEmpty)
            } header: {
                Text(.shotText)
            } footer: {
                Text(.shotTextHelp)
            }
            Section(String(localized: .shotOutput)) {
                Toggle(isOn: model.binding(\.shotCopyToClipboard, set: { $0.setShotCopyToClipboard($1) })) {
                    Text(.shotCopyOnSave)
                }
                HStack {
                    // Committed on Return or when focus leaves, so typing a path
                    // does not rewrite the config on every keystroke.
                    TextField(text: $folderDraft) { Text(.shotSaveFolder) }
                        .onSubmit(commitFolder)
                    Button(String(localized: .commonChoose), action: chooseFolder)
                }
                if !model.shotStatus.isEmpty {
                    Text(model.shotStatus).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
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

private func connectRow(_ client: String, _ command: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(client)
        Text(command)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .foregroundStyle(.secondary)
    }
}

struct VoicePage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section {
                ShortcutRows(model: model, actions: HotkeyAction.owned(by: "voice"))
            } header: {
                Text(.voicePushToTalk)
            } footer: {
                Text(.voicePushToTalkHelp)
            }
            Section {
                Toggle(isOn: model.binding(\.voiceLocalCommands, set: { $0.setVoiceLocalCommands($1) })) {
                    Text(.voiceRunCommonHere)
                    Text(.voiceRunCommonHereHelp)
                }
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(LocalizedStringResource.voiceExamples.enumerated()),
                            id: \.offset) { _, example in
                        Text(example).font(.callout)
                    }
                }
                .foregroundStyle(.secondary)
            } header: {
                Text(.voiceStraightToPlonk)
            } footer: {
                Text(.voiceStraightToPlonkHelp)
            }
            Section {
                Text(.voiceToTheAgentHelp)
                    .foregroundStyle(.secondary)
            } header: {
                Text(.voiceToTheAgent)
            }
        }
        .formStyle(.grouped)
    }
}

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
        Form {
            // With nothing connected there is no picker worth showing, and the
            // useful row is the command that connects something — so that goes
            // first until it has been run.
            if agentChoices.isEmpty {
                mcpSection
                agentsSection
            } else {
                agentsSection
                mcpSection
            }
            examplesSection
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var agentsSection: some View {
        Section {
            if agentChoices.isEmpty {
                Text(.aiNoAgents)
                    .foregroundStyle(.secondary)
            } else {
                Picker(String(localized: .aiActiveAgent), selection: selectedAgent) {
                    Text(.aiAnyAgent).tag("")
                    Divider()
                    ForEach(agentChoices, id: \.self) { name in
                        Text(model.connectedAgents.contains(name)
                             ? name
                             : String(localized: .aiAgentOffline(name))).tag(name)
                    }
                }
                Toggle(isOn: model.binding(\.agentExclusive, set: { $0.setAgentExclusive($1) })) {
                    Text(.aiExclusive)
                    Text(.aiExclusiveHelp)
                }
                .disabled(model.selectedAgent == nil)
            }
        } header: {
            Text(.aiAgents)
        } footer: {
            Text(.aiAgentsHelp)
        }
    }

    @ViewBuilder
    private var mcpSection: some View {
        Section {
            LabeledContent {
                Text("127.0.0.1:\(ControlServer.port)")
            } label: {
                Text(.aiLocalApi)
            }
            connectRow("Claude Code", "claude mcp add plonk -- npx -y plonk-mcp")
            connectRow("Codex CLI", "codex mcp add plonk -- npx -y plonk-mcp")
            connectRow(String(localized: .aiAnyMcpClient),
                       "command: npx, args: [\"-y\", \"plonk-mcp\"]")
        } header: {
            Text(.aiConnect)
        } footer: {
            Text(.aiConnectHelp)
        }
    }

    @ViewBuilder
    private var examplesSection: some View {
        Section {
            ForEach(Array(LocalizedStringResource.aiExamples.enumerated()), id: \.offset) { _, example in
                Button {
                    let sentence = String(localized: example)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(sentence, forType: .string)
                    copied = sentence
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "quote.bubble").foregroundStyle(Color.accentColor)
                        Text(example)
                        Spacer()
                        Image(systemName: "doc.on.doc").font(.caption).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(.aiTrySaying)
        } footer: {
            Text(copied == nil ? String(localized: .aiClickToCopy) : String(localized: .aiCopied))
        }
    }
}

struct MousePage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle(isOn: model.binding(\.highlightClicksEnabled, set: { $0.setHighlightClicks($1) })) {
                    Text(.mouseRingClicks)
                    Text(.mouseRingClicksHelp)
                }
                Toggle(isOn: model.binding(\.crosshairsEnabled, set: { $0.setCrosshairs($1) })) {
                    Text(.mouseCrosshairs)
                    Text(.mouseCrosshairsHelp)
                }
            } header: {
                Text(.mousePointer)
            } footer: {
                Text(.mousePointerHelp)
            }
            Section {
                ShortcutRows(model: model, actions: HotkeyAction.owned(by: "mouse"))
            } header: {
                Text(.commonShortcuts)
            } footer: {
                Text(.mouseShortcutsHelp)
            }
        }
        .formStyle(.grouped)
    }
}

/// A whole number of points, with a knob for the rough shape of it and a field
/// for the exact value. Dragging is quicker when the answer is "a bit more";
/// typing is the only way when the answer is 12.
///
/// Deliberately not a `LabeledContent`: that renders its content as a value
/// rather than a control, so the field looked like static text and never took
/// focus. A bordered box that is plainly a box is the point.
///
/// Nothing invalid reaches config. Only digits can be typed at all, so a stray
/// letter never lands in the field; anything still wrong once it is — out of
/// range, or long enough to overflow — says so and stays put to be corrected
/// rather than silently rounded into something nobody asked for. An empty
/// field is zero.
struct PointsField: View {
    let title: LocalizedStringResource
    let help: LocalizedStringResource
    let placeholder: String
    let range: ClosedRange<Int>
    let value: Double
    let commit: (Double) -> Void

    @State private var draft = ""
    @State private var knob = 0.0
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        // Two lines rather than one: a form row splits itself into a label and
        // a control, and a row holding a label, a slider and a field made that
        // split guess wrong — the field wrapped onto its own line and the
        // placeholder came out as a stray label beside it. The name and the
        // exact value share the top line, the knob gets the width of the row,
        // which is what the system's own sliders do.
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                Text(title)
                Spacer(minLength: 12)
                // `prompt`, not the title argument: on macOS the title is drawn
                // beside the box, so a placeholder passed there becomes a label.
                TextField(text: $draft, prompt: Text(placeholder)) { EmptyView() }
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 56)
                    .focused($focused)
                    .onSubmit(commitDraft)
                    .onChange(of: draft) { typed in
                        let digits = typed.filter(\.isNumber)
                        if digits != typed { draft = digits }
                    }
                Text(.commonPoints).foregroundStyle(.secondary)
            }
            // onEditingChanged spelled out rather than trailing, and no `step:`
            // — that draws tick marks, and the rounding belongs to the value.
            Slider(value: $knob,
                   in: Double(range.lowerBound)...Double(range.upperBound),
                   onEditingChanged: { editing in
                       guard !editing else { return }
                       error = nil
                       commit(knob.rounded())
                   })
                .labelsHidden()
                .controlSize(.small)
            Text(help)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .onAppear { adopt(value) }
        .onChange(of: value) { adopt($0) }
        // The field follows the knob as it moves, so the number being chosen is
        // always readable; nothing is written until the knob is let go.
        .onChange(of: knob) { draft = String(Int($0.rounded())) }
        // Committed when the field is left or Return is pressed, not per
        // keystroke: "1" on the way to "16" is a valid number, and saving it
        // would rewrite config twice and move every snapped window through a
        // size nobody asked for.
        .onChange(of: focused) { if !$0 { commitDraft() } }
    }

    private func adopt(_ number: Double) {
        knob = min(max(number, Double(range.lowerBound)), Double(range.upperBound))
        draft = String(Int(number))
    }

    private func commitDraft() {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            error = nil
            adopt(0)
            commit(0)
            return
        }
        guard let number = Int(trimmed) else {
            error = String(localized: .pointsNotWhole(String(localized: title)))
            return
        }
        guard range.contains(number) else {
            error = String(localized: .pointsOutOfRange(String(localized: title),
                                                        range.lowerBound, range.upperBound))
            return
        }
        error = nil
        knob = Double(number)
        commit(Double(number))
    }
}
