import SwiftUI

// Where workspaces are captured, inspected and launched.
//
// A workspace is a desk: the apps, every window's frame, and the display each
// one belongs on. So each is drawn as the desk it rebuilds — one bar per
// monitor, with the windows sitting in it in the colours of the zones they
// return to — and two of them can be told apart before either name is read.
//
// The colour is read back off the geometry, because a workspace stores frames
// and not zone numbers: ZoneGeometry.nearest says which zone a frame came out
// of, and a window that is nobody's zone stays grey rather than being coloured
// a lie.

struct WorkspacesPage: View {
    @ObservedObject var model: AppModel
    @State private var newName = ""
    @State private var expanded: Set<String> = []
    /// Workspace whose name is being edited in place, if any.
    @State private var renaming: String?
    @State private var renameDraft = ""

    private let columns = [GridItem(.adaptive(minimum: 330), spacing: 11, alignment: .top)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if !model.accessibilityGranted {
                    Label(String(localized: .workspacesGrantAccessibility),
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if model.workspaceNames.isEmpty {
                    Text(.workspacesNone)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 11) {
                        ForEach(model.workspaceNames, id: \.self) { desk($0) }
                    }
                }
                Text(.workspacesListHelp)
                    .font(.caption)
                    .muted()
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
    }

    // MARK: - Header

    // The title says what the page is; saving a desk is the one thing it does,
    // so that sits under it on a line of its own rather than being squeezed in
    // beside a sentence that wraps.
    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(.workspacesTitle)
                    .font(.system(size: 26, weight: .heavy))
                    .kerning(-0.7)
                Text(.workspacesSaveHelp)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 7) {
                TextField(text: $newName, prompt: Text(.workspacesName)) { Text(.workspacesName) }
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: 190)
                    .onSubmit(save)
                Button(String(localized: .commonSave), action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .controlSize(.small)
        }
    }

    // MARK: - One desk

    @ViewBuilder
    private func desk(_ name: String) -> some View {
        let items = model.workspaces[name]?.items ?? []
        VStack(alignment: .leading, spacing: 9) {
            if renaming == name {
                rename(name)
            } else {
                title(name, items: items)
            }
            DeskMonitors(model: model, items: items).frame(height: 62)
            apps(items)
            if expanded.contains(name) {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        Divider()
                        WorkspaceItemRow(model: model, workspace: name, index: index, item: item)
                            // Removing an item shifts the rows below it; the id
                            // drops their editor state instead of handing it on.
                            .id("\(name)#\(index)#\(item.launchKey)")
                    }
                }
            }
        }
        .padding(12)
        .card()
    }

    private func title(_ name: String, items: [WorkspaceItem]) -> some View {
        HStack(spacing: 7) {
            Button {
                toggle(name)
            } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text(name).font(.system(size: 13.5, weight: .bold)).lineLimit(1)
                    Text(summary(items))
                        .font(.system(size: 11, design: .monospaced))
                        .muted()
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(String(localized: expanded.contains(name)
                         ? .workspacesHideWindows : .workspacesShowWindows))
            Button(String(localized: .workspacesLaunch)) {
                model.actions?.launchWorkspace(named: name, onScreen: nil)
            }
            .controlSize(.small)
            menu(name)
        }
    }

    private func menu(_ name: String) -> some View {
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
            Button(String(localized: .workspacesRecapture)) {
                model.actions?.saveCurrentWorkspace(named: name)
            }
            Toggle(String(localized: .workspacesMoveExisting),
                   isOn: Binding(
                    get: { model.workspaces[name]?.moveExisting ?? true },
                    set: { model.actions?.setWorkspaceMoveExisting($0, for: name) }
                   ))
            Divider()
            Button(String(localized: .commonDelete), role: .destructive) {
                model.actions?.deleteWorkspace(named: name)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        // A borderless menu still draws its own chevron beside the label, which
        // next to a three-dot glyph reads as a rendering fault rather than as a
        // control. The dots are the indicator.
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private func rename(_ name: String) -> some View {
        HStack(spacing: 7) {
            TextField(text: $renameDraft) { Text(.workspacesName) }
                .textFieldStyle(.roundedBorder)
                .onSubmit { commitRename(of: name) }
                .onExitCommand { renaming = nil }
            Button(String(localized: .commonSave)) { commitRename(of: name) }
                .disabled(renameDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            Button(String(localized: .commonCancel)) { renaming = nil }
        }
        .controlSize(.small)
    }

    /// The apps this desk opens. Icons alone stopped being readable once a desk
    /// had six of them, so each carries its name.
    private func apps(_ items: [WorkspaceItem]) -> some View {
        HStack(spacing: 4) {
            ForEach(Workspace(items: items).apps.prefix(4), id: \.self) { app in
                HStack(spacing: 4) {
                    AppIcon(path: items.first { $0.app == app }?.bundlePath, size: 12)
                    Text(app).font(.system(size: 11)).lineLimit(1)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(Ink.capFill))
            }
            Spacer(minLength: 0)
        }
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
