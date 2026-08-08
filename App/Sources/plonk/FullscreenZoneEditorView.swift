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
    @State private var selected: Int?

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.35).ignoresSafeArea()
            ZoneCanvas(zones: draft, editable: true, fullscreen: true, selected: selected) { draft = $0 }
                .ignoresSafeArea()
            // Sits behind the panel and takes nothing but keys, so the mouse
            // still reaches the canvas.
            ZoneKeyCatcher { handle($0) }
                .allowsHitTesting(false)
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
                Text("Keyboard: ⇥ selects, arrows move, ⇧arrows resize, S splits, ⇧S splits vertically, ⌫ deletes.")
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

    /// Editing without a mouse. Every edit goes through the same geometry the
    /// drag does, so a keyboard cannot produce a layout a mouse could not.
    private func handle(_ key: ZoneKeyCatcher.Key) {
        guard !draft.isEmpty else { return }
        switch key {
        case .tab(let backwards):
            let count = draft.count
            let current = selected ?? (backwards ? 0 : count - 1)
            selected = ((current + (backwards ? count - 1 : 1)) % count)
        case .arrow(let dx, let dy, let resizing):
            guard let index = selected else {
                selected = 0
                return
            }
            let step = ZoneGeometry.grid
            if let next = ZoneGeometry.adjust(draft, at: index, dx: dx * step, dy: dy * step,
                                              resizing: resizing) {
                draft = next
            }
        case .split(let vertical):
            guard let index = selected, draft.indices.contains(index) else { return }
            let z = draft[index]
            let cut = vertical ? z.x + z.w / 2 : z.y + z.h / 2
            if let next = ZoneGeometry.split(draft, at: index, fraction: cut, vertical: vertical) {
                draft = next
            }
        case .delete:
            guard let index = selected, draft.count > 1, draft.indices.contains(index) else { return }
            draft = ZoneGeometry.removeAndHeal(draft, at: index)
            selected = min(index, draft.count - 1)
        }
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

/// Catches key presses for the fullscreen editor without stealing the mouse.
/// A plain SwiftUI `onKeyPress` would do this in one line, but that is macOS
/// 14 and Plonk runs from 13.
struct ZoneKeyCatcher: NSViewRepresentable {
    enum Key {
        case tab(backwards: Bool)
        /// A step in fractions of the screen: -1, 0 or 1 on each axis.
        case arrow(dx: Double, dy: Double, resizing: Bool)
        case split(vertical: Bool)
        case delete
    }

    let onKey: (Key) -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.onKey = onKey
        return view
    }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.onKey = onKey
    }

    final class CatcherView: NSView {
        var onKey: ((Key) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }

        override func keyDown(with event: NSEvent) {
            let shift = event.modifierFlags.contains(.shift)
            switch Int(event.keyCode) {
            case 48: onKey?(.tab(backwards: shift))
            case 123: onKey?(.arrow(dx: -1, dy: 0, resizing: shift))
            case 124: onKey?(.arrow(dx: 1, dy: 0, resizing: shift))
            case 126: onKey?(.arrow(dx: 0, dy: -1, resizing: shift))
            case 125: onKey?(.arrow(dx: 0, dy: 1, resizing: shift))
            case 1: onKey?(.split(vertical: !shift))
            case 51, 117: onKey?(.delete)
            default: super.keyDown(with: event)
            }
        }
    }
}
