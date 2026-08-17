import AppKit
import SwiftUI
import UniformTypeIdentifiers

// The apps that arm stay active, as a list of apps rather than of strings.
//
// Unlike ExcludedApps these are matched exactly, not as patterns: the question
// is "is Teams running", which a bundle id answers and a substring only
// guesses at. So there is no free-text field here — an app that is not
// installed cannot be running, and nothing would be gained by naming it.

struct ActiveApps: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if model.config.activeApps.isEmpty {
                Text(.activeNoApps).foregroundStyle(.secondary)
            }
            ForEach(model.config.activeApps, id: \.self) { id in
                row(for: id)
            }
            HStack(spacing: 8) {
                Button(String(localized: .activeChooseApp), action: chooseApp)
                Menu(String(localized: .activeAddRunning)) {
                    ForEach(runningApps, id: \.bundleIdentifier) { app in
                        Button(app.localizedName ?? String(localized: .activeUnnamed)) {
                            add(app.bundleIdentifier ?? "")
                        }
                    }
                }
                .fixedSize()
            }
        }
    }

    private func row(for id: String) -> some View {
        let known = Self.installedApp(for: id)
        return HStack(spacing: 10) {
            if let icon = known?.icon {
                Image(nsImage: icon).resizable().frame(width: 20, height: 20)
            } else {
                Image(systemName: "questionmark.app.dashed")
                    .frame(width: 20)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(known?.name ?? id)
                Text(id)
                    .font(.caption)
                    .monospaced()
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                model.actions?.update(\.activeApps, to: model.config.activeApps.filter { $0 != id })
            } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help(String(localized: .activeRemove))
        }
    }

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = String(localized: .activePrompt)
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let id = Bundle(url: url)?.bundleIdentifier else { continue }
            add(id)
        }
    }

    private func add(_ id: String) {
        let trimmed = id.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !model.config.activeApps.contains(trimmed) else { return }
        model.actions?.update(\.activeApps, to: model.config.activeApps + [trimmed])
    }

    /// Name and icon for an installed bundle id. Nil once the app it named has
    /// been uninstalled, which leaves the id on the row to speak for itself.
    private static func installedApp(for id: String) -> (name: String, icon: NSImage)? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else {
            return nil
        }
        let name = FileManager.default.displayName(atPath: url.path)
        return (name, NSWorkspace.shared.icon(forFile: url.path))
    }
}
