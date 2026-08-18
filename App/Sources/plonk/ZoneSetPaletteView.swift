import AppKit
import Carbon.HIToolbox
import SwiftUI

// Every zone set that could go on one screen, drawn small. Arrows or a digit
// to pick one, return to put it on the screen, E to open it in the editor.
//
// The digits match the ⌃⌥⇧1-9 bindings deliberately: those do the same swap
// blind, and this is where the order they use becomes something you can see.
// Edge snapping sits at the top with no digit, because it is a mode rather
// than a set and has no editor to open.
//
// Arrow keys come from a local event monitor for the same reason the command
// palette's do: nothing here is a text field, so SwiftUI's move commands never
// fire on their own.

struct ZoneSetPaletteView: View {
    @ObservedObject var model: AppModel
    let screenIndex: Int
    let onClose: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var selection = 0
    @State private var monitor: Any?

    /// One line of the list. An empty name is edge snapping.
    private struct Row: Identifiable {
        let name: String
        let zones: [ZoneRect]
        let custom: Bool
        var id: String { name }
        var title: String { name.isEmpty ? String(localized: .zoneSetEdgeSnapping) : name }
    }

    private var rows: [Row] {
        [Row(name: "", zones: [], custom: false)] + model.zoneSetNames.map {
            Row(name: $0, zones: model.zoneSets[$0] ?? [],
                custom: model.customZoneSetNames.contains($0))
        }
    }

    /// What the screen is on now. No assignment means the default set.
    private var assigned: String { model.assignedZoneSet(onScreen: screenIndex) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            list
            footer
        }
        .frame(width: 460)
        .background(VisualEffect(material: .popover))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Ink.capStroke))
        .onAppear {
            selection = rows.firstIndex { $0.name == assigned } ?? 0
            startMonitor()
        }
        .onDisappear(perform: stopMonitor)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.3.group").muted()
            Text(.zoneSetTitle).font(.system(size: 13, weight: .semibold))
            Spacer()
            Text(screenLabel).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private var screenLabel: String {
        let size = model.screenDescription(screenIndex)
        guard model.screenCount > 1 else { return size }
        return String(localized: size.isEmpty ? .zoneSetScreen(screenIndex + 1)
                                              : .zoneSetScreenWithSize(screenIndex + 1, size))
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        line(row, index: index)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 340)
            .onChange(of: selection) { index in
                guard rows.indices.contains(index) else { return }
                proxy.scrollTo(rows[index].id, anchor: .center)
            }
        }
    }

    private func line(_ row: Row, index: Int) -> some View {
        let selected = index == selection
        return HStack(spacing: 11) {
            thumbnail(row)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title).font(.system(size: 12.5, weight: selected ? .semibold : .regular))
                if row.name == assigned {
                    Text(.zoneSetOnThisScreenNow).font(.system(size: 10.5)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if index < 10 { KeyCaps(parts: ["\(index)"]) }
            if !row.name.isEmpty {
                Button { edit(row) } label: { Image(systemName: "pencil") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help(String(localized: row.custom ? .zoneSetEditThis : .zoneSetEditCopy))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(selected ? Ink.raised(scheme) : .clear)
        .overlay(alignment: .leading) {
            Rectangle().fill(selected ? Color.accentColor : .clear).frame(width: 2.5)
        }
        .contentShape(Rectangle())
        .onTapGesture { selection = index; apply(row) }
        .id(row.id)
    }

    private func thumbnail(_ row: Row) -> some View {
        Group {
            if row.zones.isEmpty {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.gray.opacity(0.35)))
                    .overlay(Image(systemName: "arrow.down.left.and.arrow.up.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary))
            } else {
                ZoneCanvas(zones: row.zones)
            }
        }
        .frame(width: 62, height: 39)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            hint(["↑", "↓"], "pick")
            hint(["return"], "use it")
            hint(["E"], "edit")
            hint(["N"], "new")
            hint(["esc"], "close")
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .overlay(alignment: .top) { Rectangle().fill(Ink.hairline).frame(height: 1) }
    }

    private func hint(_ keys: [String], _ label: String) -> some View {
        HStack(spacing: 5) {
            KeyCaps(parts: keys)
            Text(label).font(.system(size: 10.5)).muted()
        }
    }

    // MARK: - Doing something about it

    /// Closes first, and does the work a runloop turn later: a relayout moves
    /// real windows, and the editor opens a window of its own. Neither should
    /// race the teardown of this one.
    private func apply(_ row: Row) {
        onClose()
        let name = row.name
        let screen = screenIndex
        DispatchQueue.main.async { [model] in
            model.actions?.assignZoneSet(name, toScreen: screen)
            HUD.shared.show(name.isEmpty ? String(localized: .zoneSetEdgeSnapping) : name)
        }
    }

    private func edit(_ row: Row) {
        guard !row.name.isEmpty else { return }
        onClose()
        let name = row.name
        let screen = screenIndex
        DispatchQueue.main.async { [model] in
            model.editZoneSet(named: name, onScreen: screen)
        }
    }

    private func createNew() {
        onClose()
        let screen = screenIndex
        DispatchQueue.main.async { [model] in
            model.actions?.editZoneSet(model.freeZoneSetName(base: String(localized: .zoneSetCustom)),
                                       seed: [ZoneRect(0, 0, 1, 1)], onScreen: screen)
        }
    }

    private func move(_ delta: Int) {
        let count = rows.count
        guard count > 0 else { return }
        selection = min(max(selection + delta, 0), count - 1)
    }

    private func startMonitor() {
        stopMonitor()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let entries = rows
            switch Int(event.keyCode) {
            case kVK_DownArrow: move(1); return nil
            case kVK_UpArrow: move(-1); return nil
            case kVK_Escape: onClose(); return nil
            case kVK_Return, kVK_ANSI_KeypadEnter:
                if entries.indices.contains(selection) { apply(entries[selection]) }
                return nil
            case kVK_ANSI_E:
                if entries.indices.contains(selection) { edit(entries[selection]) }
                return nil
            case kVK_ANSI_N:
                createNew()
                return nil
            default:
                guard let digit = Int(event.charactersIgnoringModifiers ?? ""),
                      entries.indices.contains(digit) else { return event }
                apply(entries[digit])
                return nil
            }
        }
    }

    private func stopMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
