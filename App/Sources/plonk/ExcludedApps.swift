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

    var body: some View {
        if model.config.excludedApps.isEmpty {
            Text(.excludedNone)
                .foregroundStyle(.secondary)
        }
        ForEach(model.config.excludedApps, id: \.self) { pattern in
            row(for: pattern)
        }
        AppAdder(prompt: .excludedPrompt) { add($0) }
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

    private func add(_ pattern: String) {
        guard !model.config.excludedApps.contains(pattern) else { return }
        model.actions?.update(\.excludedApps, to: model.config.excludedApps + [pattern])
    }
}
