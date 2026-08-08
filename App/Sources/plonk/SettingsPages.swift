import SwiftUI

// The pages that are still macOS forms. Home, Zones and Appearance have
// pages of their own; these follow as each is redrawn.

struct AwakePage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle(isOn: model.binding(\.awakeRequested, set: { $0.setAwake($1) })) {
                    Text("Keep awake now")
                    Text(model.awakeRequested && !model.awakeOn
                         ? "Paused: on battery, and battery use is not allowed below"
                         : "The menu bar cube glows amber while active")
                }
                Picker("Turn off after",
                       selection: model.binding(\.awakeTimeoutMinutes, set: { $0.setAwakeTimeout(minutes: $1) })) {
                    Text("Never").tag(0)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                    Text("2 hours").tag(120)
                }
            }
            Section("Power") {
                Toggle(isOn: model.binding(\.awakeKeepDisplayOn, set: { $0.setAwakeKeepDisplayOn($1) })) {
                    Text("Keep the display on")
                    Text("Off: only the system stays awake, the screen may still sleep")
                }
                Toggle(isOn: model.binding(\.awakeAllowOnBattery, set: { $0.setAwakeAllowOnBattery($1) })) {
                    Text("Allow on battery")
                    Text("Off: keep-awake pauses when unplugged and resumes on power")
                }
                Toggle(isOn: model.binding(\.awakeAutoWhileCharging, set: { $0.setAwakeAutoWhileCharging($1) })) {
                    Text("Automatically while charging")
                    Text("Keeps the Mac awake whenever it is plugged in")
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
                Button("Capture Region") { model.actions?.capture(.region) }
                Button("Capture Window") { model.actions?.capture(.window) }
                Button("Capture Whole Screen") { model.actions?.capture(.screen) }
            } header: {
                Text("Capture")
            } footer: {
                Text("The editor opens on the capture: draw with pen, arrow, rectangle, ellipse or highlighter, then copy or save. Needs Screen Recording access, which macOS asks for on the first capture.")
            }
            Section {
                ShortcutRows(model: model,
                             actions: HotkeyAction.owned(by: "shot").filter { $0.group != "Crop" })
            } header: {
                Text("Shortcuts")
            }
            Section {
                ShortcutRows(model: model, actions: HotkeyAction.owned(by: "shot", group: "Crop"))
            } header: {
                Text("Pin Part of the Screen")
            } footer: {
                Text("Drag out a region and it floats above everything else. Live mirrors what is underneath — a build log, a chart, a call — so it can be watched while you work on top of it. Still freezes it, which costs nothing and works on windows a stream will not follow. Close the panel to stop it.")
            }
            Section {
                Picker("Language", selection: language) {
                    Text("Automatic").tag("")
                    Divider()
                    ForEach(model.supportedTextLanguages, id: \.self) { Text($0).tag($0) }
                }
                .disabled(model.supportedTextLanguages.isEmpty)
            } header: {
                Text("Text")
            } footer: {
                Text("⌃⌥T selects an area and copies the words in it — including text in screenshots, videos and anything else that is only pixels. Recognition runs on this Mac; nothing is uploaded. Automatic follows the system language.")
            }
            Section("Output") {
                Toggle(isOn: model.binding(\.shotCopyToClipboard, set: { $0.setShotCopyToClipboard($1) })) {
                    Text("Copy to clipboard when saving")
                }
                HStack {
                    // Committed on Return or when focus leaves, so typing a path
                    // does not rewrite the config on every keystroke.
                    TextField("Save folder", text: $folderDraft)
                        .onSubmit(commitFolder)
                    Button("Choose", action: chooseFolder)
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
                Text("Push to Talk")
            } footer: {
                Text("Hold the key, say it, let go — the words go to the active agent from the Agents list on the AI page. Recognition runs on this Mac and nothing is recorded; only the finished sentence reaches the agent. macOS asks for Microphone and Speech Recognition on first use.")
            }
            Section {
                Toggle(isOn: model.binding(\.voiceLocalCommands, set: { $0.setVoiceLocalCommands($1) })) {
                    Text("Run the common ones here")
                    Text("No agent, no round trip, works offline")
                }
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(["snap this left", "zone three", "put it back", "next window",
                             "keep awake for an hour", "launch my review workspace"], id: \.self) { example in
                        Text("“\(example)”").font(.callout)
                    }
                }
                .foregroundStyle(.secondary)
            } header: {
                Text("Straight to Plonk")
            } footer: {
                Text("Halves and quarters, numbered zones, put back, focus, next window in a zone, show zones, keep-awake, screenshots, and launching a workspace by name. Anything less clear-cut — two things at once, a percentage, an app by name, awake until a build finishes — goes to the agent instead, so nothing is guessed at.")
            }
            Section {
                Text("\"Browser on the left, terminal right\" — the agent arranges it. \"Save this as a workspace called review\", \"screenshot the screen and circle what looks broken\" — same. Anything you could type to the agent, you can say.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("What to Say to the Agent")
            }
        }
        .formStyle(.grouped)
    }
}

struct AIPage: View {
    @ObservedObject var model: AppModel
    @State private var copied: String?

    private static let examples = [
        "Browser on the left 60%, terminal top right, notes bottom right",
        "Put VS Code in the middle zone",
        "Save this as a workspace called \"review\"",
        "Launch my \"work\" workspace",
        "Make me a three-column zone set for the main screen",
        "Keep the screen awake for the next hour",
        "Screenshot the screen and circle whatever looks broken",
    ]

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
                Text("No agents connected yet — anything speaking MCP shows up here once it calls a Plonk tool.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Active agent", selection: selectedAgent) {
                    Text("Any agent").tag("")
                    Divider()
                    ForEach(agentChoices, id: \.self) { name in
                        Text(model.connectedAgents.contains(name) ? name : "\(name) (offline)").tag(name)
                    }
                }
                Toggle(isOn: model.binding(\.agentExclusive, set: { $0.setAgentExclusive($1) })) {
                    Text("Only the active agent controls")
                    Text("Other agents can still read state and take screenshots")
                }
                .disabled(model.selectedAgent == nil)
            }
        } header: {
            Text("Agents")
        } footer: {
            Text("Every connected MCP client appears here. The active agent is who voice and other outgoing requests will go to.")
        }
    }

    @ViewBuilder
    private var mcpSection: some View {
        Section {
            LabeledContent("Local API", value: "127.0.0.1:\(ControlServer.port)")
            connectRow("Claude Code", "claude mcp add plonk -- npx -y plonk-mcp")
            connectRow("Codex CLI", "codex mcp add plonk -- npx -y plonk-mcp")
            connectRow("Cursor, Zed, anything MCP", "command: npx, args: [\"-y\", \"plonk-mcp\"]")
        } header: {
            Text("Connect an Agent")
        } footer: {
            Text("Run one of these once, in the client. Plonk is not tied to one assistant — any MCP client can drive it, several at once. Set PLONK_AGENT_NAME in the client's MCP config to name a session by hand.")
        }
    }

    @ViewBuilder
    private var examplesSection: some View {
        Section {
            ForEach(Array(Self.examples.enumerated()), id: \.offset) { _, example in
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(example, forType: .string)
                    copied = example
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
            Text("Try Saying")
        } footer: {
            Text(copied == nil ? "Click one to copy it." : "Copied to clipboard.")
        }
    }
}

struct MousePage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle(isOn: model.binding(\.highlightClicksEnabled, set: { $0.setHighlightClicks($1) })) {
                    Text("Ring every click")
                    Text("For screen recordings, where a click is otherwise invisible")
                }
                Toggle(isOn: model.binding(\.crosshairsEnabled, set: { $0.setCrosshairs($1) })) {
                    Text("Crosshairs through the pointer")
                    Text("Full-width and full-height lines, for lining things up")
                }
            } header: {
                Text("Pointer")
            } footer: {
                Text("These only ever read the mouse; nothing is intercepted, so no click or keystroke changes on their account, and no keystroke is watched at all. They take the zone colour from the Zones page.")
            }
            Section {
                ShortcutRows(model: model, actions: HotkeyAction.owned(by: "mouse"))
            } header: {
                Text("Shortcuts")
            } footer: {
                Text("Finding the pointer dims everything but a circle round it, briefly. Jumping warps it to the middle of the next display and flashes it there, which beats pushing a mouse across three monitors.")
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
    let title: String
    let help: String
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
                Text("pt").foregroundStyle(.secondary)
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
            error = "\(title) has to be a whole number of points."
            return
        }
        guard range.contains(number) else {
            error = "\(title) has to be between \(range.lowerBound) and \(range.upperBound)."
            return
        }
        error = nil
        knob = Double(number)
        commit(Double(number))
    }
}
