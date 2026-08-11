import AppKit
import SwiftUI

// The app's main window: sidebar, a bar that says where you are and whether
// anything is wrong, and the page itself.
//
// Deliberately not a NavigationSplitView: its collapse button hides the sidebar
// outright and floats over the content pane. And no collapse button of our own
// either, because a bare toggle sitting in the corner of a sidebar is not a
// control macOS has. The sidebar drops to an icon rail on its own when the
// window gets narrow, and never goes away.

struct MainWindowView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme

    private static let wide: CGFloat = 216
    private static let rail: CGFloat = 58
    private static let railBelow: CGFloat = 780

    private var current: SettingsPage? {
        model.settingsPages.first { $0.id == model.selectedPage } ?? model.settingsPages.first
    }

    private var group: SettingsGroup? {
        model.settingsGroups.first { $0.id == current?.parent }
    }

    /// "Layout · Zones", or just "Home" where the destination is the page.
    private var title: String {
        guard let current else { return "Plonk" }
        guard let group, group.title != current.title else { return current.title }
        return "\(group.title) · \(current.title)"
    }

    var body: some View {
        GeometryReader { geo in
            let rail = geo.size.width < Self.railBelow
            HStack(spacing: 0) {
                MainSidebar(model: model, rail: rail)
                    .frame(width: rail ? Self.rail : Self.wide)
                    .background(SidebarMaterial())
                Divider()
                VStack(spacing: 0) {
                    topBar
                    Divider()
                    Group {
                        if let current { current.make(model) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(page)
                }
            }
        }
        // The window hides its title bar so our own header is the only one, but
        // the hosting view still insets the content by its height. Without this
        // the top bar hangs below an empty strip the width of the window.
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 620, minHeight: 520)
        // Both, and deliberately: `tint` is what system controls read, and the
        // deprecated `accentColor` is the only one that moves `Color.accentColor`
        // itself — which is what every view drawing its own accent asks for.
        .tint(model.accent)
        .accentColor(model.accent)
        // Window-scoped rather than a global hotkey: ⌘K belongs to whichever
        // app is in front, and taking it from all of them would be rude.
        .background(
            Button("") { model.actions?.openCommandPalette() }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        )
        .onAppear { if model.selectedPage == nil { model.selectedPage = model.settingsPages.first?.id } }
    }

    // MARK: - Top bar

    // Permissions only earn room when one is missing. Three chips that are
    // green every day teach people to stop reading them, and then the one that
    // matters goes unread too.
    private var topBar: some View {
        HStack(spacing: 8) {
            Text(title).font(.system(size: 14.5, weight: .semibold))
            Spacer(minLength: 12)
            if healthy {
                StatusPill(title: "All permissions granted", ok: true)
            } else {
                if !model.accessibilityGranted {
                    StatusPill(title: "Accessibility", ok: false, fix: PrivacySettings.openAccessibility)
                }
                if !model.screenRecordingGranted {
                    StatusPill(title: "Screen Recording", ok: false,
                               fix: PrivacySettings.openScreenRecording)
                }
                if let warning = model.apiWarning {
                    StatusPill(title: "Local API", ok: false).help(warning)
                }
            }
            if !model.connectedAgents.isEmpty {
                StatusPill(title: agentCount, ok: true)
                    .help(model.connectedAgents.joined(separator: ", "))
            }
            Button { model.actions?.openCommandPalette() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").font(.system(size: 11))
                    Text("⌘K").font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Ink.card(scheme)))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Ink.capStroke))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Run a command")
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
        .background(Ink.chrome(scheme))
    }

    /// The page background, with the accent bleeding in from the corners the
    /// way it does behind the hero. Flat charcoal is correct and lifeless; this
    /// is the one place the window is allowed a bit of colour.
    private var page: some View {
        ZStack {
            Ink.page(scheme)
            RadialGradient(colors: [model.accent.opacity(scheme == .dark ? 0.16 : 0.10), .clear],
                           center: .init(x: 0.85, y: -0.05), startRadius: 0, endRadius: 620)
            RadialGradient(colors: [Ink.warmer(model.accent).opacity(scheme == .dark ? 0.10 : 0.07),
                                    .clear],
                           center: .init(x: 0.02, y: 1.05), startRadius: 0, endRadius: 520)
        }
        .ignoresSafeArea()
    }

    private var healthy: Bool {
        model.accessibilityGranted && model.screenRecordingGranted && model.apiWarning == nil
    }

    private var agentCount: String {
        model.connectedAgents.count == 1 ? "1 agent" : "\(model.connectedAgents.count) agents"
    }
}

/// The two panes of System Settings the app can send someone to. Both pages
/// are the ones a missing permission is granted on, and nothing else opens them.
enum PrivacySettings {
    static func openAccessibility() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    static func openScreenRecording() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    private static func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }
}

/// The real sidebar blur. SwiftUI materials get close, but only
/// NSVisualEffectView picks up the vibrancy the system sidebar has.
private struct SidebarMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
