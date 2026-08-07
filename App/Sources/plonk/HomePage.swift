import SwiftUI

// Where a first-time user lands. Leads with what to say to an agent, because
// that is the part nobody guesses on their own; permissions and gadgets follow.

struct HomePage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if let warning = model.configWarning {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .textSelection(.enabled)
                        .padding(11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.10)))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.orange.opacity(0.35)))
                }
                readiness
                quickActions
                section("Startup") { startup }
                section("Gadgets") { gadgets }
                footer
            }
            .padding(20)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "cube")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Color.accentColor)
                .frame(width: 54, height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.accentColor.opacity(0.13))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.22))
                )
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text("Plonk").font(.title2.bold())
                    if !model.appVersion.isEmpty {
                        Text(model.appVersion)
                            .font(.caption2.weight(.medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.primary.opacity(0.07)))
                            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.12)))
                            .help("Version \(model.appVersion)")
                    }
                }
                Text("Menu bar gadgets, and an agent that can use them")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Readiness

    private var readiness: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 8, alignment: .leading)],
                  alignment: .leading, spacing: 8) {
            chip("Accessibility", ok: model.accessibilityGranted,
                 detail: "Needed to move and resize windows", fix: openAccessibilitySettings)
            chip("Screen Recording", ok: model.screenRecordingGranted,
                 detail: "Needed for screenshots", fix: openScreenRecordingSettings)
            chip("Local API", ok: model.apiWarning == nil,
                 detail: model.apiWarning ?? "127.0.0.1:\(ControlServer.port), reachable by the MCP tools", fix: nil)
        }
    }

    private func chip(_ title: String, ok: Bool, detail: String, fix: (() -> Void)?) -> some View {
        HStack(spacing: 7) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(ok ? Color.green : Color.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption.weight(.medium))
                if !ok {
                    Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            if !ok, let fix {
                Spacer(minLength: 4)
                Button("Grant", action: fix)
                    .buttonStyle(.link)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(ok ? Color.gray.opacity(0.09) : Color.orange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(ok ? Color.gray.opacity(0.20) : Color.orange.opacity(0.35))
        )
        .help(detail)
    }

    // MARK: - Quick actions

    // The status item opens this window rather than a menu, so the things that
    // used to be one click away in the menu bar have to live here.
    private var quickActions: some View {
        HStack(spacing: 10) {
            tile("Capture Region", "camera.viewfinder") { model.actions?.capture(.region) }
            tile("Show Zones", "square.grid.2x2") { model.actions?.flashZones() }
            tile("Edit Zones", "pencil.and.outline") { model.actions?.openZonePicker() }
            tile(model.awakeRequested ? "Awake: On" : "Keep Awake", "cup.and.saucer") {
                model.actions?.setAwake(!model.awakeRequested)
            }
        }
    }

    private func tile(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon).font(.title2).foregroundStyle(Color.accentColor)
                Text(title).font(.caption).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .cardBackground()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Gadgets

    private var gadgets: some View {
        VStack(spacing: 0) {
            gadgetRow("Hotkeys", "keyboard", page: "zones",
                      detail: model.unavailableHotkeys.isEmpty
                          ? "⌃⌥ with an arrow, a letter or Return"
                          : "Taken by another app: \(model.unavailableHotkeys.joined(separator: ", "))",
                      toggle: model.binding(\.hotkeysEnabled, set: { $0.setHotkeys($1) }))
            Divider()
            gadgetRow("Drag to snap", "rectangle.3.group", page: "zones",
                      detail: "Drop windows into zones or screen edges",
                      toggle: model.binding(\.dragSnapEnabled, set: { $0.setDragSnap($1) }))
            Divider()
            gadgetRow("Keep awake", "cup.and.saucer", page: "awake",
                      detail: model.awakeRequested && !model.awakeOn
                          ? "Paused: on battery" : "Holds a power assertion",
                      toggle: model.binding(\.awakeRequested, set: { $0.setAwake($1) }))
            Divider()
            gadgetRow("Screenshots", "camera.viewfinder", page: "shot",
                      detail: "Saved to \(model.shotFolder)", toggle: nil)
            Divider()
            gadgetRow("AI control", "sparkles", page: "ai",
                      detail: "\(model.workspaceNames.count) workspaces · \(model.zoneSetNames.count) zone sets",
                      toggle: nil)
        }
        .cardBackground()
    }

    private func gadgetRow(_ title: String, _ icon: String, page: String,
                           detail: String, toggle: Binding<Bool>?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if let toggle {
                Toggle("", isOn: toggle).labelsHidden().toggleStyle(.switch).controlSize(.small)
            }
            Button {
                model.selectedPage = page
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open \(title) settings")
        }
        .padding(11)
    }

    // MARK: - Startup

    private var startup: some View {
        HStack(spacing: 10) {
            Image(systemName: "power")
                .frame(width: 20)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("Launch at login").font(.callout.weight(.medium))
                Text("Plonk starts automatically when you log in")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: model.binding(\.launchAtLogin, set: { $0.setLaunchAtLogin($1) }))
                .labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
        .padding(11)
        .cardBackground()
    }

    // MARK: - Footer

    // Report a Bug lives in the sidebar, where it is reachable from every page.
    private var footer: some View {
        Text("Everything runs on this Mac. No account, no cloud, no telemetry.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func section<Content: View>(_ title: String, note: String? = nil,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title).font(.subheadline.bold()).foregroundStyle(.secondary)
                Spacer()
                if let note {
                    Text(note).font(.caption2).foregroundStyle(.secondary)
                }
            }
            content()
        }
    }

    private func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    private func openScreenRecordingSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    private func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }
}

private extension View {
    func cardBackground() -> some View {
        background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.09)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.gray.opacity(0.22)))
    }
}
