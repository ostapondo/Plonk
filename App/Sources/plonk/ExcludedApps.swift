import AppKit
import SwiftUI
import UniformTypeIdentifiers

// The list of apps Plonk keeps its hands off, as a list of apps rather than a
// list of strings.
//
// What is stored is still a pattern — AppExclusions matches it anywhere in an
// app's name or bundle id — because the thing being excluded may not be
// installed, may be a helper process with no icon, or may be several apps at
// once ("steam" covers Steam and Steam Helper). But nobody should have to know
// that to exclude Photoshop: pick it from Applications, or off the list of what
// is running right now, and the bundle id is what gets written.

struct ExcludedApps: View {
    @ObservedObject var model: AppModel
    @State private var typed = ""

    var body: some View {
        if model.excludedApps.isEmpty {
            Text("Nothing is excluded — Plonk will move any window.")
                .foregroundStyle(.secondary)
        }
        ForEach(model.excludedApps, id: \.self) { pattern in
            row(for: pattern)
        }
        HStack(spacing: 8) {
            Button("Choose App…", action: chooseApp)
            Menu("Add Running App") {
                ForEach(runningApps, id: \.bundleIdentifier) { app in
                    Button(app.localizedName ?? "?") { add(app.bundleIdentifier ?? app.localizedName ?? "") }
                }
            }
            .fixedSize()
            Spacer(minLength: 8)
            // The escape hatch for anything the two buttons above cannot
            // reach: a helper process, a game that is not installed yet, or a
            // word that should match a family of apps.
            TextField("or type a name", text: $typed)
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
                .onSubmit { add(typed) }
            Button("Add") { add(typed) }
                .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func row(for pattern: String) -> some View {
        let known = Self.installedApp(for: pattern)
        return HStack(spacing: 10) {
            if let icon = known?.icon {
                Image(nsImage: icon).resizable().frame(width: 20, height: 20)
            } else {
                Image(systemName: "questionmark.app.dashed")
                    .frame(width: 20)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(known?.name ?? pattern)
                // The pattern is only worth showing when it is not simply the
                // name already on the line above it.
                if known != nil {
                    Text(pattern)
                        .font(.caption)
                        .monospaced()
                        .foregroundStyle(.secondary)
                } else {
                    Text("matched anywhere in an app's name or bundle id")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                model.actions?.setExcludedApps(model.excludedApps.filter { $0 != pattern })
            } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Stop excluding this")
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
        panel.prompt = "Exclude"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            // The bundle id, not the name: it survives the app being renamed
            // or localized, and it is what the app reports about itself.
            add(Bundle(url: url)?.bundleIdentifier ?? url.deletingPathExtension().lastPathComponent)
        }
    }

    private func add(_ raw: String) {
        let pattern = raw.trimmingCharacters(in: .whitespaces)
        guard !pattern.isEmpty, !model.excludedApps.contains(pattern) else {
            typed = ""
            return
        }
        model.actions?.setExcludedApps(model.excludedApps + [pattern])
        typed = ""
    }

    /// Name and icon for a pattern that happens to be an installed app's
    /// bundle id. Nil for a bare word, which is left to speak for itself.
    private static func installedApp(for pattern: String) -> (name: String, icon: NSImage)? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: pattern) else { return nil }
        let name = FileManager.default.displayName(atPath: url.path)
        return (name.replacingOccurrences(of: ".app", with: ""),
                NSWorkspace.shared.icon(forFile: url.path))
    }
}
