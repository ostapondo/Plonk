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

struct AppRow<Subtitle: View>: View {
    let title: String
    let icon: NSImage?
    let removeHelp: LocalizedStringResource
    let onRemove: () -> Void
    @ViewBuilder let subtitle: () -> Subtitle

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
            Spacer()
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help(String(localized: removeHelp))
        }
    }
}
