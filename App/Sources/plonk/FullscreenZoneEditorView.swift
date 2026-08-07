import SwiftUI

// Borderless grid editor shown over the actual screen. Click a zone to split
// it (⇧ for a vertical split), drag a divider to resize, ✕ deletes.
// Edits stay in the draft until Save & Apply, so Cancel and Esc are lossless
// and the saved set never sees a half-finished layout.

struct FullscreenZoneEditorView: View {
    @ObservedObject var model: AppModel
    let setName: String
    /// Non-nil for a set that is not saved yet; see AppActions.editZoneSet.
    let seed: [ZoneRect]?
    let screenIndex: Int
    let done: () -> Void

    @State private var draft: [ZoneRect] = []
    @State private var name = ""
    @State private var error: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.35).ignoresSafeArea()
            ZoneCanvas(zones: draft, editable: true, fullscreen: true) { draft = $0 }
                .ignoresSafeArea()
            panel
        }
        .onExitCommand(perform: done)
        .onAppear {
            name = setName
            let existing = seed ?? model.zoneSets[setName] ?? []
            draft = existing.isEmpty ? [ZoneRect(0, 0, 1, 1)] : existing
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Layout name", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.headline)
            VStack(alignment: .leading, spacing: 3) {
                Text("Split: click a zone, hold ⇧ while clicking for a vertical split.")
                Text("Resize: drag a border or handle — neighboring zones follow.")
                Text("Delete: ✕ removes a zone and neighbors fill the space.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            HStack {
                Spacer()
                Button("Save & Apply", action: save)
                    .keyboardShortcut(.defaultAction)
                Button("Cancel", action: done)
            }
        }
        .padding(16)
        .frame(width: 460)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 60)
    }

    private func save() {
        guard let actions = model.actions else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let target = trimmed.isEmpty ? setName : trimmed
        if seed != nil {
            guard model.zoneSets[target] == nil else {
                error = "A layout named \"\(target)\" already exists."
                return
            }
        } else if target != setName {
            guard actions.renameZoneSet(setName, to: target) else {
                error = "A layout named \"\(target)\" already exists."
                return
            }
        }
        actions.updateZoneSet(target, zones: draft)
        actions.assignZoneSet(target, toScreen: screenIndex)
        done()
    }
}
