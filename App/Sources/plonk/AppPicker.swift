import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// What ActiveApps and ExcludedApps share: finding an app to add and drawing
/// the row it becomes.
enum AppPicker {
    static var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    /// Opens Applications and returns what the user picked, empty on cancel.
    static func chooseApps(prompt: LocalizedStringResource) -> [URL] {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = String(localized: prompt)
        guard panel.runModal() == .OK else { return [] }
        return panel.urls
    }

    /// Name and icon for an installed bundle id. Nil for a bare word or an
    /// app that has since been uninstalled, which leaves the id to speak for
    /// itself.
    static func installedApp(for id: String) -> (name: String, icon: NSImage)? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
        let name = FileManager.default.displayName(atPath: url.path)
        return (name.replacingOccurrences(of: ".app", with: ""),
                NSWorkspace.shared.icon(forFile: url.path))
    }
}

/// The two buttons and the field that add an app to a list: pick it from
/// Applications, off what is running, or type a name for a helper process or a
/// word that covers a family of apps. What is handed back is the bundle id
/// where there is one, because it survives the app being renamed or localized,
/// and the typed word otherwise.
struct AppAdder: View {
    /// The button on the open panel, e.g. "Exclude".
    let prompt: LocalizedStringResource
    let onAdd: (String) -> Void
    @State private var typed = ""
    /// What is running, taken when the list appears and when the workspace
    /// says it changed: asking NSWorkspace inside `body` walked every process
    /// on each redraw of the page.
    @State private var running: [NSRunningApplication] = []

    var body: some View {
        // One line where there is room, two where there is not: a button
        // squeezed to "Choo…" is not a button, so the pickers keep their width
        // and the typed-name field is what gives.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                pickers
                Spacer(minLength: 8)
                typedName
            }
            VStack(alignment: .leading, spacing: 8) {
                pickers
                typedName
            }
        }
        .onAppear { running = AppPicker.runningApps }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { _ in
            running = AppPicker.runningApps
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in
            running = AppPicker.runningApps
        }
    }

    private var pickers: some View {
        HStack(spacing: 8) {
            Button(String(localized: .excludedChooseApp), action: chooseApp)
                .buttonStyle(.chip)
            Menu(String(localized: .excludedAddRunning)) {
                ForEach(running, id: \.bundleIdentifier) { app in
                    Button(app.localizedName ?? String(localized: .excludedUnnamed)) {
                        add(app.bundleIdentifier ?? app.localizedName ?? "")
                    }
                }
            }
        }
        .fixedSize()
    }

    /// The escape hatch for anything the two buttons cannot reach.
    private var typedName: some View {
        HStack(spacing: 8) {
            TextField(String(localized: .excludedOrType), text: $typed)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 120, maxWidth: 190)
                .onSubmit { add(typed) }
            Button(String(localized: .excludedAdd)) { add(typed) }
                .buttonStyle(.chip)
                .fixedSize()
                .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func chooseApp() {
        for url in AppPicker.chooseApps(prompt: prompt) {
            add(Bundle(url: url)?.bundleIdentifier ?? url.deletingPathExtension().lastPathComponent)
        }
    }

    private func add(_ raw: String) {
        let pattern = raw.trimmingCharacters(in: .whitespaces)
        typed = ""
        guard !pattern.isEmpty else { return }
        onAdd(pattern)
    }
}

struct AppRow<Subtitle: View, Accessory: View>: View {
    let title: String
    let icon: NSImage?
    let removeHelp: LocalizedStringResource
    let onRemove: () -> Void
    @ViewBuilder let subtitle: () -> Subtitle
    /// Controls between the name and the remove button, for a list where a
    /// row says more than "this app": the rules list puts its pickers here.
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(nsImage: icon).resizable().frame(width: 20, height: 20)
            } else {
                Image(systemName: "questionmark.app.dashed")
                    .frame(width: 20)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                subtitle()
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            accessory()
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help(String(localized: removeHelp))
        }
    }
}

extension AppRow where Accessory == EmptyView {
    init(title: String, icon: NSImage?, removeHelp: LocalizedStringResource,
         onRemove: @escaping () -> Void, @ViewBuilder subtitle: @escaping () -> Subtitle) {
        self.init(title: title, icon: icon, removeHelp: removeHelp, onRemove: onRemove,
                  subtitle: subtitle, accessory: { EmptyView() })
    }
}
