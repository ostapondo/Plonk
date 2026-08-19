import AppKit
import SwiftUI

// The app's main window: a sidebar set into the ground as its own panel, and
// the page beside it.
//
// Deliberately not a NavigationSplitView: its collapse button hides the sidebar
// outright and floats over the content pane. And no collapse button of our own
// either, because a bare toggle sitting in the corner of a sidebar is not a
// control macOS has. The sidebar drops to an icon rail on its own when the
// window gets narrow, and never goes away.
//
// No bar over the page: the sidebar already says where you are, and the page
// opens with its own title. Whether anything is wrong is said in the sidebar,
// above the footer, and only when something is.

struct MainWindowView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme

    static let wide: CGFloat = 228
    /// Wide enough for the traffic lights, which sit inside the panel now.
    static let rail: CGFloat = 76
    /// Under this window width the sidebar is the icon rail. The presenter
    /// reads it too, to centre the traffic lights in whichever panel is drawn.
    static let railBelow: CGFloat = 780
    /// Between the sidebar panel and the page.
    private static let gutter: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let rail = geo.size.width < Self.railBelow
            HStack(spacing: Self.gutter) {
                MainSidebar(model: model, rail: rail)
                    .frame(width: rail ? Self.rail : Self.wide)
                    .background(RoundedRectangle(cornerRadius: Ink.panelRadius, style: .continuous)
                        .fill(Ink.sidebar(scheme)))
                    .overlay(RoundedRectangle(cornerRadius: Ink.panelRadius, style: .continuous)
                        .strokeBorder(Ink.stroke(scheme)))
                Group {
                    if let current = model.currentPage { current.make(model) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(Ink.inset)
            .background(page)
        }
        // The window hides its title bar so the sidebar reaches the top edge,
        // but the hosting view still insets the content by its height. Without
        // this everything hangs below an empty strip the width of the window.
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

    /// The ground: the desktop showing through, the page colour over it, and
    /// the accent bleeding in from two corners the way it does behind the hero.
    /// Flat charcoal is correct and lifeless; this is the one place the window
    /// is allowed a bit of colour.
    private var page: some View {
        ZStack {
            VisualEffect(material: .underWindowBackground, state: .followsWindowActiveState)
            Ink.page(scheme).opacity(scheme == .dark ? 0.88 : 0.92)
            RadialGradient(colors: [model.accent.opacity(scheme == .dark ? 0.16 : 0.20), .clear],
                           center: .init(x: 0.85, y: -0.05), startRadius: 0, endRadius: 620)
            RadialGradient(colors: [Ink.warmer(model.accent).opacity(scheme == .dark ? 0.10 : 0.14),
                                    .clear],
                           center: .init(x: 0.02, y: 1.05), startRadius: 0, endRadius: 520)
        }
        .ignoresSafeArea()
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
