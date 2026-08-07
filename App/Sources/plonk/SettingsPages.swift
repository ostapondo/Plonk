import SwiftUI

struct ZonesPage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle(isOn: model.binding(\.dragSnapEnabled, set: { $0.setDragSnap($1) })) {
                    Text("Drag to snap")
                    Text("Drop windows into zones or screen edges while dragging")
                }
            }
            Section {
                Picker("Show zones", selection: model.binding(\.zonesRequireModifier,
                                                              set: { $0.setZonesRequireModifier($1) })) {
                    Text("While dragging").tag(false)
                    Text("While dragging with the modifier held").tag(true)
                }
                Picker("Modifier", selection: model.binding(\.zonesModifier, set: { $0.setZonesModifier($1) })) {
                    Text("⇧ Shift").tag("shift")
                    Text("⌥ Option").tag("option")
                    Text("⌃ Control").tag("control")
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Holding the modifier while dragging inverts the mode, so the other behavior is always available.")
            }
            Section {
                ShortcutRows(model: model, actions: HotkeyAction.owned(by: "zones"))
            } header: {
                Text("Shortcuts")
            } footer: {
                Text("Click a key field and press the combination. Esc cancels, Delete unbinds.")
            }
            Section("Per Monitor") {
                ForEach(0..<model.screenCount, id: \.self) { screen in
                    Picker(screen == 0 ? "Screen 1 (primary)" : "Screen \(screen + 1)",
                           selection: assignment(for: screen)) {
                        Text("Edge snapping").tag("edge")
                        Divider()
                        ForEach(model.zoneSetNames, id: \.self) { Text($0).tag($0) }
                    }
                }
            }
            Section {
                Button("Edit Zones") { model.actions?.openZonePicker() }
            } footer: {
                Text("Create and draw zone sets in the editor, or ask Claude for freeform ones. Overlaps are allowed; the smallest zone under the cursor wins.")
            }
        }
        .formStyle(.grouped)
    }

    private func assignment(for screen: Int) -> Binding<String> {
        Binding(
            get: { model.screenAssignments[screen].map { $0.isEmpty ? "edge" : $0 } ?? BuiltinZoneSets.defaultName },
            set: { model.actions?.assignZoneSet($0 == "edge" ? "" : $0, toScreen: screen) }
        )
    }
}

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
            Section("Shortcut") {
                ShortcutRows(model: model, actions: HotkeyAction.owned(by: "shot"))
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

struct AIPage: View {
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

    var body: some View {
        Form {
            Section("MCP") {
                LabeledContent("Local API", value: "127.0.0.1:\(ControlServer.port)")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connect Claude Code:")
                    Text("claude mcp add plonk -- node <repo>/mcp/dist/server.js")
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }
            }
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
        .formStyle(.grouped)
    }
}
