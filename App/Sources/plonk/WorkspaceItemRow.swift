import SwiftUI

// One row of a workspace: the window, where it goes, and what its app should
// open on the way up.

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
