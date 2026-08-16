import AppKit
import SwiftUI

// The sidebar: every page at one level, under the heading of the destination it
// belongs to.
//
// The groups used to expand and collapse, so ten of the twelve pages were behind
// a click that told you nothing — a heading is not a control, and drawing it as
// one only hid the list it was labelling. Headings now label; rows navigate.
//
// Metrics come from the design's macOS mock: a 220pt sidebar, 13pt rows, 11pt
// headings, and a selected row that is the accent rather than a grey fill.

struct MainSidebar: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    /// Icons only. The window collapses to this on its own when it gets narrow.
    let rail: Bool

    /// Clears the traffic lights: the window runs its content under the title
    /// bar, so the first thing in the sidebar would sit behind them.
    private static let lights: CGFloat = 34

    private var current: SettingsPage? {
        model.settingsPages.first { $0.id == model.selectedPage } ?? model.settingsPages.first
    }

    private func pages(of group: SettingsGroup) -> [SettingsPage] {
        model.settingsPages.filter { $0.parent == group.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: Self.lights)
            search
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(model.settingsGroups) { group in
                        let children = pages(of: group)
                        // A destination holding one page is that page, and a
                        // heading over a list of one is noise.
                        if children.count > 1, !rail { heading(group.title) }
                        ForEach(children) { row($0, icon: children.count > 1 ? $0.icon : group.icon) }
                    }
                    if !rail, !model.workspaceNames.isEmpty { workspaces }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
            }
            footer
        }
    }

    // MARK: - Search

    private var search: some View {
        Button {
            model.actions?.openCommandPalette()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").font(.system(size: 12))
                if !rail {
                    Text(.appRunACommand).font(.system(size: 12.5))
                    Spacer(minLength: 0)
                    Text("⌘K").font(.system(size: 11, design: .monospaced))
                }
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .frame(height: 27)
            .frame(maxWidth: .infinity, alignment: rail ? .center : .leading)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Ink.capFill))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.bottom, 12)
        .help(String(localized: .appRunACommand))
    }

    // MARK: - Rows

    private func heading(_ title: LocalizedStringResource) -> some View {
        Text(String(localized: title).uppercased())
            .font(.system(size: 11, weight: .bold))
            .kerning(0.45)
            .muted()
            .padding(.horizontal, 8)
            .padding(.top, 9)
            .padding(.bottom, 4)
    }

    /// What a row says about itself on the right: the set a screen is on, how
    /// many desks are saved, that the agents page is the MCP one. Only where
    /// there is a fact worth carrying — an empty badge is not drawn.
    private func badge(_ page: SettingsPage) -> String? {
        switch page.id {
        case "zones": return model.screenAssignments[0]
        case "workspaces": return model.workspaceNames.isEmpty ? nil
                                                               : String(model.workspaceNames.count)
        case "ai": return "MCP"
        default: return nil
        }
    }

    private func row(_ page: SettingsPage, icon: String) -> some View {
        let selected = current?.id == page.id
        return Button {
            model.selectedPage = page.id
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12.5))
                    .frame(width: 16)
                    .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                if !rail {
                    Text(page.title).font(.system(size: 13, weight: selected ? .semibold : .regular))
                    Spacer(minLength: 6)
                    if let badge = badge(page) {
                        Text(badge)
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(1)
                            .foregroundStyle(selected ? AnyShapeStyle(.white.opacity(0.75))
                                                      : AnyShapeStyle(.tertiary))
                    }
                }
            }
            .foregroundStyle(selected ? Color.white : Color.primary)
            .padding(.horizontal, 8)
            .frame(height: 27)
            .frame(maxWidth: .infinity, alignment: rail ? .center : .leading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selected ? AnyShapeStyle(Ink.gradient(model.accent))
                                   : AnyShapeStyle(Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(String(localized: page.title))
    }

    private var workspaces: some View {
        VStack(alignment: .leading, spacing: 1) {
            heading(.appWorkspaces)
            ForEach(model.workspaceNames.prefix(4), id: \.self) { name in
                Button {
                    model.actions?.launchWorkspace(named: name, onScreen: nil)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.3.group").font(.system(size: 12.5)).frame(width: 16)
                        Text(name).font(.system(size: 13)).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .frame(height: 27)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(String(localized: .appLaunchWorkspace(name)))
            }
        }
    }

    // MARK: - Footer

    // The cube, what is installed, and the way to say something is wrong with
    // it. Everything else that used to live here is a setting, and settings
    // have a page.
    private var footer: some View {
        HStack(spacing: 7) {
            if rail {
                Button { model.actions?.reportBug() } label: {
                    Image(systemName: "ladybug").font(.system(size: 13)).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .help(String(localized: .appReportBug))
            } else {
                // The bundle's own icon, not an SF Symbol that looks like it:
                // the cube is a drawing with three coloured faces, and a
                // monochrome glyph of a box is a different mark entirely.
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 16, height: 16)
                Text(model.appVersion.isEmpty
                     ? String(localized: .appName)
                     : String(localized: .appNameVersion(model.appVersion)))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button { model.actions?.reportBug() } label: {
                    Image(systemName: "ladybug").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(String(localized: .appReportBug))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .overlay(alignment: .top) { Rectangle().fill(Ink.hairline).frame(height: 1) }
    }
}
