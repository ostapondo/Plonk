import AppKit
import SwiftUI

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
    /// What is running, taken when the list appears and when the workspace
    /// says it changed: asking NSWorkspace inside `body` walked every process
    /// on each redraw of the page.
    @State private var running: [NSRunningApplication] = []

    var body: some View {
        if model.config.excludedApps.isEmpty {
            Text(.excludedNone)
                .foregroundStyle(.secondary)
        }
        ForEach(model.config.excludedApps, id: \.self) { pattern in
            row(for: pattern)
        }
        HStack(spacing: 8) {
            Button(String(localized: .excludedChooseApp), action: chooseApp)
            Menu(String(localized: .excludedAddRunning)) {
                ForEach(running, id: \.bundleIdentifier) { app in
                    Button(app.localizedName ?? String(localized: .excludedUnnamed)) {
                        add(app.bundleIdentifier ?? app.localizedName ?? "")
                    }
                }
            }
            .fixedSize()
            Spacer(minLength: 8)
            // The escape hatch for anything the two buttons above cannot
            // reach: a helper process, a game that is not installed yet, or a
            // word that should match a family of apps.
            TextField(String(localized: .excludedOrType), text: $typed)
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
                .onSubmit { add(typed) }
            Button(String(localized: .excludedAdd)) { add(typed) }
                .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .onAppear { running = AppPicker.runningApps }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { _ in
            running = AppPicker.runningApps
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in
            running = AppPicker.runningApps
        }
    }

    private func row(for pattern: String) -> some View {
        let known = AppPicker.installedApp(for: pattern)
        return AppRow(title: known?.name ?? pattern, icon: known?.icon, removeHelp: .excludedStopExcluding) {
            model.actions?.update(\.excludedApps, to: model.config.excludedApps.filter { $0 != pattern })
        } subtitle: {
            // The pattern is only worth showing when it is not simply the
            // name already on the line above it.
            if known != nil {
                Text(pattern).monospaced()
            } else {
                Text(.excludedMatchedAnywhere)
            }
        }
    }

    private func chooseApp() {
        for url in AppPicker.chooseApps(prompt: .excludedPrompt) {
            // The bundle id, not the name: it survives the app being renamed
            // or localized, and it is what the app reports about itself.
            add(Bundle(url: url)?.bundleIdentifier ?? url.deletingPathExtension().lastPathComponent)
        }
    }

    private func add(_ raw: String) {
        let pattern = raw.trimmingCharacters(in: .whitespaces)
        guard !pattern.isEmpty, !model.config.excludedApps.contains(pattern) else {
            typed = ""
            return
        }
        model.actions?.update(\.excludedApps, to: model.config.excludedApps + [pattern])
        typed = ""
    }
}
