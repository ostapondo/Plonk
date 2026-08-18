import AppKit
import SwiftUI

// ⌘K. Type a few letters of any command and press Return.
//
// Arrow keys come from a local event monitor rather than SwiftUI's move
// commands: the text field wants the arrows for its own cursor, and taking
// them away from it is the only way the list can be driven while typing.

struct CommandPaletteView: View {
    let commands: [PlonkCommand]
    /// The agent a sentence would go to, for the label on the ask row.
    var agent: String?
    let onAsk: (String) -> Void
    let onClose: () -> Void
    @Environment(\.colorScheme) private var scheme

    @State private var query = ""
    @State private var selection = 0
    @State private var monitor: Any?
    @FocusState private var focused: Bool

    /// The commands in the order they are drawn. Selection indexes this, not the
    /// scored list: the rows are grouped after scoring, so the two orders differ
    /// and the arrow keys were stepping through a list nobody could see.
    private var results: [PlonkCommand] { sections.flatMap(\.commands) }

    var body: some View {
        VStack(spacing: 0) {
            field
            Divider()
            list
            footer
        }
        .frame(width: 560)
        .background(VisualEffect(material: .popover))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Ink.capStroke))
        .onAppear { focused = true; startMonitor() }
        .onDisappear(perform: stopMonitor)
    }

    private var field: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").muted()
            TextField(String(localized: .palettePrompt), text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($focused)
                .onSubmit(runSelected)
                .onChange(of: query) { _ in selection = 0 }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(sections, id: \.name) { section in
                        Section {
                            ForEach(section.commands) { command in
                                row(command)
                            }
                        } header: {
                            Eyebrow(verbatim: section.name, size: 9.5, kerning: 0.9)
                                .padding(.horizontal, 16)
                                .padding(.top, 11)
                                .padding(.bottom, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.ultraThinMaterial)
                        }
                    }
                    if results.isEmpty {
                        Text(.paletteNoMatch(query))
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                            .padding(16)
                    }
                }
                .padding(.bottom, 6)
            }
            .frame(height: 320)
            .onChange(of: selection) { index in
                guard results.indices.contains(index) else { return }
                proxy.scrollTo(results[index].id, anchor: .center)
            }
        }
    }

    /// Whatever was typed, offered to the agent. Deliberately last: a query
    /// that matches a real command should run it, not send a sentence about it
    /// on a round trip, and ⌘return is there for when that is what was meant.
    private var askRow: PlonkCommand? {
        // The value, not the binding. This runs a runloop turn after onClose()
        // has torn the hosting view down, and reading @State by then can hand
        // back the empty string it started as — which askAgent silently drops.
        let prompt = query
        return PlonkCommand.ask(prompt, agent: agent) { onAsk(prompt) }
    }

    /// Groups in the order the commands arrived, so the list does not reshuffle
    /// itself alphabetically while it is being typed into.
    private var sections: [(name: String, commands: [PlonkCommand])] {
        var result = commands.matching(query).groupedPreservingOrder(by: \.group)
            .map { (name: $0.key, commands: $0.elements) }
        if let askRow {
            result.append((name: askRow.group, commands: [askRow]))
        }
        return result
    }

    private func row(_ command: PlonkCommand) -> some View {
        let index = results.firstIndex { $0.id == command.id } ?? -1
        let selected = index == selection
        return HStack(spacing: 11) {
            Text(command.title).font(.system(size: 12.5))
            Spacer(minLength: 12)
            KeyCaps(parts: command.keys)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(selected ? Ink.raised(scheme) : .clear)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(selected ? Color.accentColor : .clear)
                .frame(width: 2.5)
        }
        .contentShape(Rectangle())
        .onTapGesture { selection = index; runSelected() }
        .id(command.id)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            hint(["↑", "↓"], .paletteHintNavigate)
            hint(["return"], .paletteHintRun)
            hint(["⌘", "return"], .paletteAskTheAgent)
            hint(["esc"], .paletteHintClose)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .overlay(alignment: .top) { Rectangle().fill(Ink.hairline).frame(height: 1) }
    }

    private func hint(_ keys: [String], _ label: LocalizedStringResource) -> some View {
        HStack(spacing: 5) {
            KeyCaps(parts: keys)
            Text(label).font(.system(size: 10.5)).muted()
        }
    }

    /// Skips the selection entirely: ⌘return means "send what I typed", whatever
    /// the list happens to be highlighting.
    private func askSelected() {
        guard let askRow else { return }
        onClose()
        DispatchQueue.main.async { askRow.run() }
    }

    private func runSelected() {
        guard results.indices.contains(selection) else { return }
        let command = results[selection]
        onClose()
        // After the window is gone, not during: a command that opens a window
        // of its own should not race the teardown of this one.
        DispatchQueue.main.async { command.run() }
    }

    private func move(_ delta: Int) {
        guard !results.isEmpty else { return }
        selection = (selection + delta).clamped(to: 0...(results.count - 1))
    }

    private func startMonitor() {
        stopMonitor()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch Int(event.keyCode) {
            case 125: move(1); return nil      // down
            case 126: move(-1); return nil     // up
            case 53: onClose(); return nil     // escape
            case 36 where event.modifierFlags.contains(.command):
                askSelected(); return nil      // return
            default: return event
            }
        }
    }

    private func stopMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
