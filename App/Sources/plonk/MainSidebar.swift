import AppKit
import SwiftUI

// The sidebar: every page at one level, under the heading of the destination it
// belongs to.
//
// The groups used to expand and collapse, so ten of the twelve pages were behind
// a click that told you nothing — a heading is not a control, and drawing it as
// one only hid the list it was labelling. Headings now label; rows navigate.
//
// Metrics come from the design's macOS mock: a 228pt panel, 30pt rows at 13pt,
// 11pt headings in plain case, and a selected row that is a lift off the panel
// rather than a splash of accent. Colour is carried by the icons instead: each
// destination's rows take one of the zone hues, so the menu reads in the same
// palette as the zones it is about.

struct MainSidebar: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    /// Icons only. The window collapses to this on its own when it gets narrow.
    let rail: Bool

    /// Clears the traffic lights: the window runs its content under the title
    /// bar, so the first thing in the sidebar would sit behind them.
    private static let lights: CGFloat = 40

    private func pages(of group: SettingsGroup) -> [SettingsPage] {
        model.visiblePages.filter { $0.parent == group.id }
    }

    /// Whether a destination is a list rather than one page. Decided on every
    /// page it has, not on the ones showing: a heading over Automation stays
    /// when Voice is switched off, and goes only when nothing is left under it.
    private func isList(_ group: SettingsGroup) -> Bool {
        model.settingsPages.filter { $0.parent == group.id }.count > 1
    }

    /// The hue a destination's icons carry. Home and Layout share plum, the
    /// app's own colour; the rest step through the palette in the order the
    /// groups are listed.
    private func hue(of group: SettingsGroup) -> Color {
        let zone: Int
        switch group.id {
        case "capture": zone = 2
        case "automation": zone = 3
        case "settings": zone = 4
        default: zone = 1
        }
        // The zone hues are tuned to fill a rectangle, and sun and mint are too
        // pale to draw a 13pt glyph on a light panel. Pulled toward ink there,
        // kept as they are on dark.
        return scheme == .dark ? Ink.zone(zone) : Ink.deeper(Ink.zone(zone))
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
                        if isList(group), !rail, !children.isEmpty { heading(group.title) }
                        ForEach(children) {
                            row($0, icon: isList(group) ? $0.icon : group.icon, hue: hue(of: group))
                        }
                    }
                    if !rail, model.isEnabled(.workspaces), !model.workspaceNames.isEmpty { workspaces }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
            }
            if !rail { status }
            footer
        }
    }

    // MARK: - Search

    private var search: some View {
        Button {
            model.actions?.openCommandPalette()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass").font(.system(size: 12, weight: .medium))
                if !rail {
                    Text(.appRunACommand).font(.system(size: 12.5))
                    Spacer(minLength: 0)
                    Text("⌘K").font(.system(size: 11, design: .monospaced)).opacity(0.7)
                }
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .frame(maxWidth: .infinity, alignment: rail ? .center : .leading)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.08)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.bottom, 12)
        .help(String(localized: .appRunACommand))
    }

    // MARK: - Rows

    private func heading(_ title: LocalizedStringResource) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.primary.opacity(0.4))
            .padding(.horizontal, 12)
            .padding(.top, 10)
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

    private func row(_ page: SettingsPage, icon: String, hue: Color) -> some View {
        let selected = model.currentPage?.id == page.id
        return Button {
            model.selectedPage = page.id
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: rail ? 14 : 12.5, weight: .medium))
                    .frame(width: 16)
                    .foregroundStyle(hue)
                if !rail {
                    Text(page.title).font(.system(size: 13, weight: selected ? .semibold : .regular))
                    Spacer(minLength: 6)
                    if let badge = badge(page) {
                        Text(badge)
                            .font(.system(size: 11.5))
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .foregroundStyle(Color.primary)
            .padding(.leading, 12)
            .padding(.trailing, 10)
            .frame(height: 30)
            .frame(maxWidth: .infinity, alignment: rail ? .center : .leading)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? Ink.selection(scheme) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(String(localized: page.title))
    }

    private var workspaces: some View {
        VStack(alignment: .leading, spacing: 2) {
            heading(.appWorkspaces)
            // A row opens the Workspaces page, where each one has its own
            // Launch button. Launching opens apps and moves windows, and a
            // sidebar click is too easy to land by accident for that.
            ForEach(Array(model.workspaceNames.prefix(4).enumerated()), id: \.offset) { index, name in
                Button {
                    model.selectedPage = "workspaces"
                } label: {
                    HStack(spacing: 10) {
                        // A dot in a zone hue with the initial in it: the same
                        // mark the workspace carries everywhere else it is
                        // drawn, and colour in a menu that is otherwise grey.
                        ZStack {
                            Circle().fill(Ink.zone([0, 5, 4, 2][index % 4]))
                            Text(String(name.prefix(1)).uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 16, height: 16)
                        Text(name).font(.system(size: 13)).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Color.primary)
                    .padding(.leading, 12)
                    .padding(.trailing, 10)
                    .frame(height: 30)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(String(localized: .appOpenWorkspace(name)))
            }
        }
    }

    // MARK: - Status

    /// Whether the app can do its job, said only when something is wrong.
    /// Three green chips that are green every day teach people to stop reading
    /// them, and then the one that matters goes unread too. Agents that are
    /// connected are a fact, not a fault, and sit in the footer.
    @ViewBuilder private var status: some View {
        if !model.allPermissionsGranted {
            VStack(alignment: .leading, spacing: 5) {
                if !model.accessibilityGranted {
                    StatusPill(title: .appAccessibility, ok: false, fix: PrivacySettings.openAccessibility)
                }
                if !model.screenRecordingGranted {
                    StatusPill(title: .appScreenRecording, ok: false,
                               fix: PrivacySettings.openScreenRecording)
                }
                if let warning = model.apiWarning {
                    StatusPill(title: .aiLocalApi, ok: false).help(warning)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
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
                // The mark itself, drawn: the bundle icon is the whole macOS
                // tile, rounded square and all, and shrinking that to 16 points
                // beside a line of text puts a picture of an app icon in the
                // sidebar rather than the cube.
                PlonkCube().frame(height: 16)
                Text(model.appVersion.isEmpty
                     ? String(localized: .appName)
                     : String(localized: .appNameVersion(model.appVersion)))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                // Who is driving, in the same quiet type as the version: a
                // green dot and a count, not a chip that outshouts the menu.
                if !model.connectedAgents.isEmpty {
                    HStack(spacing: 5) {
                        Circle().fill(Color.green).frame(width: 5, height: 5)
                        Text(.appAgentCount(model.connectedAgents.count))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .help(model.connectedAgents.joined(separator: ", "))
                    .padding(.trailing, 4)
                }
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
