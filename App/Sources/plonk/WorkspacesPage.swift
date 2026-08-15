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
                    Label(String(localized: .workspacesGrantAccessibility),
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            // Above the list: it is how a workspace comes to exist, and it is
            // the same one row whether there are none saved or twenty. Below,
            // it walked further down the page with every workspace added.
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "plus.rectangle.on.rectangle")
                        .foregroundStyle(.secondary)
                    TextField(text: $newName, prompt: Text(.workspacesName)) { Text(.workspacesName) }
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(save)
                        .labelsHidden()
                    Button(String(localized: .commonSave), action: save)
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text(.workspacesSaveWhatIsOnScreen)
            } footer: {
                Text(.workspacesSaveHelp)
            }
            Section {
                if model.workspaceNames.isEmpty {
                    Text(.workspacesNone)
                        .foregroundStyle(.secondary)
                }
                ForEach(model.workspaceNames, id: \.self) { name in
                    workspace(name)
                }
            } header: {
                Text(.workspacesTitle)
            } footer: {
                Text(.workspacesListHelp)
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
                    TextField(text: $renameDraft) { Text(.workspacesName) }
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { commitRename(of: name) }
                        .onExitCommand { renaming = nil }
                    Button(String(localized: .commonSave)) { commitRename(of: name) }
                        .disabled(renameDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button(String(localized: .commonCancel)) { renaming = nil }
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
                .help(String(localized: expanded.contains(name)
                             ? .workspacesHideWindows : .workspacesShowWindows))

                Button(String(localized: .workspacesLaunch)) { model.actions?.launchWorkspace(named: name, onScreen: nil) }
                Menu {
                    // The way out when the captured display is gone.
                    if model.screenCount > 1 {
                        Menu(String(localized: .workspacesLaunchOnMonitor)) {
                            ForEach(0..<model.screenCount, id: \.self) { index in
                                Button(monitorTitle(index)) {
                                    model.actions?.launchWorkspace(named: name, onScreen: index)
                                }
                            }
                        }
                    }
                    Button(String(localized: .workspacesRename)) {
                        renameDraft = name
                        renaming = name
                    }
                    Button(String(localized: .workspacesRecapture)) { model.actions?.saveCurrentWorkspace(named: name) }
                    Toggle(String(localized: .workspacesMoveExisting),
                           isOn: Binding(
                            get: { model.workspaces[name]?.moveExisting ?? true },
                            set: { model.actions?.setWorkspaceMoveExisting($0, for: name) }
                           ))
                    Divider()
                    Button(String(localized: .commonDelete), role: .destructive) { model.actions?.deleteWorkspace(named: name) }
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

    /// Counted parts come from the plural dictionary, and the separator with
    /// them: joining with a hardcoded middot is a decision about the language.
    private func summary(_ items: [WorkspaceItem]) -> String {
        let screens = Set(items.compactMap(\.screen)).count
        var parts = [String(localized: .workspacesAppCount(Workspace(items: items).apps.count)),
                     String(localized: .workspacesWindowCount(items.count))]
        if screens > 1 { parts.append(String(localized: .workspacesMonitorCount(screens))) }
        return parts.joined(separator: String(localized: .commonSeparator))
    }

    private func monitorTitle(_ index: Int) -> String {
        let size = model.screenDescriptions.indices.contains(index) ? model.screenDescriptions[index] : ""
        return String(localized: index == 0 ? .workspacesMainDisplay(size)
                                            : .workspacesDisplay(index + 1, size))
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
            .help(String(localized: .workspacesOpenWith))
            .popover(isPresented: $editing, arrowEdge: .bottom) { editor }

            Button {
                model.actions?.removeWorkspaceItem(index, from: workspace)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help(String(localized: .workspacesRemove))
        }
        .padding(.vertical, 6)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.app).font(.headline)
            field(.workspacesOpenWithField, text: $urls, hint: .workspacesOpenWithHint)
            field(.workspacesArguments, text: $args, hint: .workspacesArgumentsHint)
            HStack {
                Spacer()
                Button(String(localized: .commonCancel)) { editing = false }
                Button(String(localized: .commonSave)) {
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

    private func field(_ title: LocalizedStringResource, text: Binding<String>,
                       hint: LocalizedStringResource) -> some View {
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
        let frame = String(localized: .workspacesPlacement(percent(item.w), percent(item.h),
                                                           percent(item.x), percent(item.y)))
        guard let screen = item.screen else { return frame }
        return String(localized: .workspacesOnScreen(screen, frame))
    }
}
