import AppKit
import SwiftUI

// The apps that arm the session, as a list of apps rather than of strings.
//
// Unlike ExcludedApps these are matched exactly, not as patterns: the question
// is "is Teams running", which a bundle id answers and a substring only
// guesses at. So there is no free-text field here — an app that is not
// installed cannot be running, and nothing would be gained by naming it.

struct AwakeApps: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if model.config.awakeApps.isEmpty {
                Text(.awakeNoApps).foregroundStyle(.secondary)
            }
            ForEach(model.config.awakeApps, id: \.self) { id in
                row(for: id)
            }
            HStack(spacing: 8) {
                Button(String(localized: .awakeChooseApp), action: chooseApp)
                Menu(String(localized: .awakeAddRunning)) {
                    ForEach(AppPicker.runningApps, id: \.bundleIdentifier) { app in
                        Button(app.localizedName ?? String(localized: .awakeUnnamed)) {
                            add(app.bundleIdentifier ?? "")
                        }
                    }
                }
                .fixedSize()
            }
        }
    }

    private func row(for id: String) -> some View {
        let known = AppPicker.installedApp(for: id)
        return AppRow(title: known?.name ?? id, icon: known?.icon, removeHelp: .awakeRemove) {
            model.actions?.update(\.awakeApps, to: model.config.awakeApps.filter { $0 != id })
        } subtitle: {
            Text(id).monospaced()
        }
    }

    private func chooseApp() {
        for url in AppPicker.chooseApps(prompt: .awakePrompt) {
            guard let id = Bundle(url: url)?.bundleIdentifier else { continue }
            add(id)
        }
    }

    private func add(_ id: String) {
        let trimmed = id.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !model.config.awakeApps.contains(trimmed) else { return }
        model.actions?.update(\.awakeApps, to: model.config.awakeApps + [trimmed])
    }
}
