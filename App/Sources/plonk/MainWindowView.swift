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
                    .glassSurface(radius: Ink.panelRadius)
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
        .tint(Ink.controlTint(scheme))
        .accentColor(Ink.controlTint(scheme))
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

    /// A neutral wash over the desktop blur keeps the glass legible in both
    /// appearances without casting the selected accent across every page.
    private var page: some View {
        ZStack {
            VisualEffect(material: .underWindowBackground, state: .followsWindowActiveState)
            Ink.page(scheme).opacity(scheme == .dark ? 0.87 : 0.82)
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
