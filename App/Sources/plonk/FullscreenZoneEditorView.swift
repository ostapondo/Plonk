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
    /// The set's own gap, edited as digits and kept only while `ownGap` is on;
    /// off means the default gap in Zones › Overlay.
    @State private var ownGap = false
    @State private var gapText = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.35).ignoresSafeArea()
            ZoneCanvas(zones: draft, editable: true, fullscreen: true, selected: selected,
                       gap: gap ?? model.config.zoneGap) { draft = $0 }
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
            if seed == nil, let own = model.config.zoneSetGaps[setName] {
                ownGap = true
                gapText = String(Int(own))
            }
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(String(localized: .zoneEditorName), text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.headline)
            gapRow
            VStack(alignment: .leading, spacing: 3) {
                Text(.zoneEditorSplit)
                Text(.zoneEditorResize)
                Text(.zoneEditorDelete)
                Text(.zoneEditorKeyboard)
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
                Button(String(localized: .zoneEditorSaveAndApply), action: save)
                    .keyboardShortcut(.defaultAction)
                Button(String(localized: .commonCancel), action: done)
            }
        }
        .padding(16)
        .frame(width: 460)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 60)
    }

    /// The gap this layout keeps around its windows: the default from
    /// Zones › Overlay, or a number of its own. A layout of wide zones can
    /// afford air that a six-zone one cannot.
    private var gapRow: some View {
        HStack(spacing: 10) {
            Text(.zoneEditorGap)
            Picker("", selection: $ownGap) {
                Text(.zoneEditorGapDefault(Int(model.config.zoneGap))).tag(false)
                Text(.zoneEditorGapOwn).tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            if ownGap {
                TextField(text: $gapText, prompt: Text("0")) { EmptyView() }
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 56)
                    .onChange(of: gapText) { typed in
                        let digits = typed.filter(\.isNumber)
                        if digits != typed { gapText = digits }
                    }
                Text(.commonPoints).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    /// What `gapRow` says, as a value: nil for the default. Anything above
    /// the limit is held to it, the way `Config.clamp` would on load.
    private var gap: Double? {
        guard ownGap else { return nil }
        return Double(Int(gapText) ?? 0).clamped(to: 0...Config.gapLimit)
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
                error = String(localized: .zoneEditorNameTaken(target))
                return
            }
        } else if target != setName {
            guard actions.renameZoneSet(setName, to: target) else {
                error = String(localized: .zoneEditorNameTaken(target))
                return
            }
        }
        actions.updateZoneSet(target, zones: draft, gap: gap)
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
            case 1: onKey?(.split(vertical: shift))
            case 51, 117: onKey?(.delete)
            default: super.keyDown(with: event)
            }
        }
    }
}
