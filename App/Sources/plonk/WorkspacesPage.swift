import SwiftUI

// Where workspaces are captured, inspected and launched.

struct WorkspacesPage: View {
    @ObservedObject var model: AppModel
    @State private var newName = ""
    @State private var expanded: Set<String> = []
    /// Workspace whose name is being edited in place, if any.
    @State private var renaming: String?
    @State private var renameDraft = ""

    var body: some View {
        Form {
            if !model.accessibilityGranted {
                Section {
                    Label("Grant Accessibility access: System Settings, Privacy & Security, Accessibility. Then relaunch Plonk.",
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            Section {
                if model.workspaceNames.isEmpty {
                    Text("No workspaces yet. Open the apps you want, arrange them, and save. Launching a workspace opens whatever is missing and puts every window back.")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.workspaceNames, id: \.self) { name in
                    workspace(name)
                }
            } header: {
                Text("Workspaces")
            } footer: {
                Text("Apps cannot be opened straight into position, so windows appear first and are moved a moment later.")
            }
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "plus.rectangle.on.rectangle")
                        .foregroundStyle(.secondary)
                    TextField("Workspace name", text: $newName, prompt: Text("Workspace name"))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(save)
                        .labelsHidden()
                    Button("Save", action: save)
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Save What Is On Screen")
            } footer: {
                Text("Type a name and press Save. Every open window is captured with the app it belongs to and the monitor it sits on.")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - One workspace

    @ViewBuilder
    private func workspace(_ name: String) -> some View {
        let items = model.workspaces[name]?.items ?? []
        VStack(alignment: .leading, spacing: 8) {
            if renaming == name {
                HStack(spacing: 8) {
                    TextField("Workspace name", text: $renameDraft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { commitRename(of: name) }
                        .onExitCommand { renaming = nil }
                    Button("Save") { commitRename(of: name) }
                        .disabled(renameDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("Cancel") { renaming = nil }
                }
                .padding(.vertical, 4)
            } else {
            HStack(spacing: 10) {
                // The chevron alone is too small to aim at, so the whole left
                // half of the row toggles.
                Button {
                    toggle(name)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(expanded.contains(name) ? 90 : 0))
                            .frame(width: 12)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(name)
                            HStack(spacing: 4) {
                                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                                    AppIcon(path: item.bundlePath, size: 16)
                                }
                                Text(summary(items))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 2)
                            }
                        }
                        Spacer(minLength: 12)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(expanded.contains(name) ? "Hide the windows" : "Show the windows")

                Button("Launch") { model.actions?.launchWorkspace(named: name, onScreen: nil) }
                Menu {
                    // The way out when the captured display is gone.
                    if model.screenCount > 1 {
                        Menu("Launch on Monitor") {
                            ForEach(0..<model.screenCount, id: \.self) { index in
                                Button(monitorTitle(index)) {
                                    model.actions?.launchWorkspace(named: name, onScreen: index)
                                }
                            }
                        }
                    }
                    Button("Rename") {
                        renameDraft = name
                        renaming = name
                    }
                    Button("Recapture from Screen") { model.actions?.saveCurrentWorkspace(named: name) }
                    Toggle("Move Windows That Are Already Open",
                           isOn: Binding(
                            get: { model.workspaces[name]?.moveExisting ?? true },
                            set: { model.actions?.setWorkspaceMoveExisting($0, for: name) }
                           ))
                    Divider()
                    Button("Delete", role: .destructive) { model.actions?.deleteWorkspace(named: name) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 28)
            }
            }
            if expanded.contains(name) {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        if index > 0 { Divider() }
                        WorkspaceItemRow(model: model, workspace: name, index: index, item: item)
                            // Removing an item shifts the rows below it; the id
                            // drops their editor state instead of handing it on.
                            .id("\(name)#\(index)#\(item.launchKey)")
                    }
                }
                .padding(.leading, 22)
            }
        }
        .padding(.vertical, 2)
    }

    private func summary(_ items: [WorkspaceItem]) -> String {
        let apps = Workspace(items: items).apps.count
        let windows = items.count
        let appPart = apps == 1 ? "1 app" : "\(apps) apps"
        let windowPart = windows == 1 ? "1 window" : "\(windows) windows"
        let screens = Set(items.compactMap(\.screen)).count
        let screenPart = screens > 1 ? " · \(screens) monitors" : ""
        return "\(appPart) · \(windowPart)\(screenPart)"
    }

    private func monitorTitle(_ index: Int) -> String {
        let size = model.screenDescriptions.indices.contains(index) ? model.screenDescriptions[index] : ""
        return index == 0 ? "Main Display (\(size))" : "Display \(index + 1) (\(size))"
    }

    private func commitRename(of old: String) {
        let new = renameDraft.trimmingCharacters(in: .whitespaces)
        guard !new.isEmpty else { return }
        guard model.actions?.renameWorkspace(old, to: new) == true else { return }
        renaming = nil
        if expanded.remove(old) != nil { expanded.insert(new) }
    }

    private func toggle(_ name: String) {
        if expanded.contains(name) {
            expanded.remove(name)
        } else {
            expanded.insert(name)
        }
    }

    private func save() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        model.actions?.saveCurrentWorkspace(named: name)
        newName = ""
    }
}

/// One window inside a workspace: where it goes, and what its app should open.
struct WorkspaceItemRow: View {
    @ObservedObject var model: AppModel
    let workspace: String
    let index: Int
    let item: WorkspaceItem

    @State private var editing = false
    @State private var urls = ""
    @State private var args = ""

    var body: some View {
        HStack(spacing: 9) {
            AppIcon(path: item.bundlePath, size: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.app).font(.callout).lineLimit(1)
                Text(placement).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Button {
                urls = (item.urls ?? []).joined(separator: "\n")
                args = (item.args ?? []).joined(separator: "\n")
                editing = true
            } label: {
                Image(systemName: (item.urls?.isEmpty == false || item.args?.isEmpty == false)
                      ? "doc.text.fill" : "doc.text")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("What this app should open")
            .popover(isPresented: $editing, arrowEdge: .bottom) { editor }

            Button {
                model.actions?.removeWorkspaceItem(index, from: workspace)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Remove from this workspace")
        }
        .padding(.vertical, 6)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.app).font(.headline)
            field("Open with this app", text: $urls,
                  hint: "One file, folder or URL per line. Used only when the app has to be launched.")
            field("Arguments", text: $args, hint: "One per line. Ignored by apps that do not read them.")
            HStack {
                Spacer()
                Button("Cancel") { editing = false }
                Button("Save") {
                    model.actions?.updateWorkspaceItem(index, in: workspace,
                                                       urls: lines(urls), args: lines(args))
                    editing = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    private func field(_ title: String, text: Binding<String>, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption.weight(.medium))
            TextEditor(text: text)
                .font(.system(size: 12, design: .monospaced))
                .frame(height: 54)
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.gray.opacity(0.3)))
            Text(hint).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func lines(_ text: String) -> [String] {
        text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var placement: String {
        let percent = { (value: Double) in Int((value * 100).rounded()) }
        let screen = item.screen.map { "screen \($0) · " } ?? ""
        return "\(screen)\(percent(item.w))% × \(percent(item.h))% at \(percent(item.x)),\(percent(item.y))"
    }
}
