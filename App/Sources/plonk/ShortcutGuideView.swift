import AppKit
import SwiftUI

// The panel the shortcut guide is shown in: columns of menus, a search field,
// and Escape to dismiss. It floats without taking focus from the app it is
// describing, which is the whole point — the shortcuts stay usable while it
// is up.

struct ShortcutGuideView: View {
    let appName: String
    let items: [ShortcutGuide.Item]
    @State private var query = ""

    private var grouped: [(menu: String, items: [ShortcutGuide.Item])] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        let matching = needle.isEmpty ? items : items.filter {
            $0.title.lowercased().contains(needle) || $0.keys.lowercased().contains(needle)
                || $0.menu.lowercased().contains(needle)
        }
        // Menu order is the order they appear in the bar, which is the order
        // the user already knows.
        var order: [String] = []
        var byMenu: [String: [ShortcutGuide.Item]] = [:]
        for item in matching {
            if byMenu[item.menu] == nil { order.append(item.menu) }
            byMenu[item.menu, default: []].append(item)
        }
        return order.map { ($0, byMenu[$0] ?? []) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(appName).font(.headline)
                Spacer()
                TextField("Filter", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
            }
            .padding(14)

            Divider()

            if items.isEmpty {
                Text("This app publishes no menu shortcuts.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(40)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 22)],
                              alignment: .leading, spacing: 22) {
                        ForEach(grouped, id: \.menu) { group in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(group.menu)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                                ForEach(group.items) { item in
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text(item.title).lineLimit(1).truncationMode(.middle)
                                        Spacer(minLength: 10)
                                        Text(item.keys)
                                            .font(.system(.callout, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }

            Divider()
            Text("Read from this app's own menus, so it cannot go stale. Escape closes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
        }
        .frame(minWidth: 560, minHeight: 380)
    }
}

/// Floating, non-activating panel: the app being described has to keep focus,
/// or its shortcuts would go to the guide instead.
final class ShortcutGuidePanel: NSPanel {
    var onClose: (() -> Void)?

    init(appName: String, items: [ShortcutGuide.Item]) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 720, height: 460),
                   styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        title = "Shortcuts — \(appName)"
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = NSHostingView(rootView: ShortcutGuideView(appName: appName, items: items))
        center()
    }

    override func cancelOperation(_ sender: Any?) {
        close()
    }

    override func close() {
        onClose?()
        super.close()
    }
}
