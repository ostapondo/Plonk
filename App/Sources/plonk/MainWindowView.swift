import AppKit
import SwiftUI

// The app's main window.
//
// Deliberately not a NavigationSplitView: its collapse button hides the sidebar
// outright and floats over the content pane. And no collapse button of our own
// either, because a bare toggle sitting in the corner of a sidebar is not a
// control macOS has. The sidebar drops to an icon rail on its own when the
// window gets narrow, and never goes away.

struct MainWindowView: View {
    @ObservedObject var model: AppModel

    private static let wide: CGFloat = 200
    private static let rail: CGFloat = 58
    private static let railBelow: CGFloat = 780

    private var groups: [(title: String?, pages: [SettingsPage])] {
        var order: [String?] = []
        var bySection: [String?: [SettingsPage]] = [:]
        for page in model.settingsPages {
            if !order.contains(where: { $0 == page.section }) { order.append(page.section) }
            bySection[page.section, default: []].append(page)
        }
        return order.map { ($0, bySection[$0] ?? []) }
    }

    private var current: SettingsPage? {
        model.settingsPages.first { $0.id == model.selectedPage } ?? model.settingsPages.first
    }

    var body: some View {
        GeometryReader { geo in
            let rail = geo.size.width < Self.railBelow
            HStack(spacing: 0) {
                sidebar(rail: rail)
                    .frame(width: rail ? Self.rail : Self.wide)
                    .background(SidebarMaterial())
                Divider()
                Group {
                    if let current { current.make(model) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 620, minHeight: 520)
        .onAppear { if model.selectedPage == nil { model.selectedPage = model.settingsPages.first?.id } }
    }

    // MARK: - Sidebar

    private func sidebar(rail: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                        if let title = group.title {
                            header(title, rail: rail, first: index == 0)
                        }
                        ForEach(group.pages) { page in
                            row(page, rail: rail)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 10)
                .padding(.bottom, 10)
            }
            Divider()
            footer(rail: rail)
        }
    }

    private func header(_ title: String, rail: Bool, first: Bool) -> some View {
        Group {
            if rail {
                Divider().padding(.vertical, 6)
            } else {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.top, first ? 2 : 12)
                    .padding(.bottom, 3)
            }
        }
    }

    private func row(_ page: SettingsPage, rail: Bool) -> some View {
        let selected = current?.id == page.id
        return Button {
            model.selectedPage = page.id
        } label: {
            HStack(spacing: 8) {
                Image(systemName: page.icon)
                    .font(.system(size: 13))
                    .frame(width: 18)
                if !rail {
                    Text(page.title).font(.system(size: 13)).lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
            .foregroundStyle(selected ? Color.white : Color.primary)
            .padding(.vertical, 5)
            .padding(.horizontal, 7)
            .frame(maxWidth: .infinity, alignment: rail ? .center : .leading)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(selected ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(page.title)
    }

    private func footer(rail: Bool) -> some View {
        Button {
            model.actions?.reportBug()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "ladybug").font(.system(size: 13)).frame(width: 18)
                if !rail {
                    Text("Report a Bug").font(.system(size: 13))
                    Spacer(minLength: 0)
                }
            }
            .foregroundStyle(.secondary)
            .padding(.vertical, 10)
            .padding(.horizontal, 15)
            .frame(maxWidth: .infinity, alignment: rail ? .center : .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Report a Bug")
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
