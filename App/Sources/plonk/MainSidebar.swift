import AppKit
import SwiftUI

// The sidebar: five destinations, the open one expanded into its pages, the
// saved workspaces, and the theme switch.
//
// Only the open destination shows its children. Eleven entries at one level
// was a list to be read; five that unfold is one to be aimed at, and nothing
// moved further away — a page is still one click, because opening its parent
// is what selecting it does.

struct MainSidebar: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    /// Icons only. The window collapses to this on its own when it gets narrow.
    let rail: Bool

    private var current: SettingsPage? {
        model.settingsPages.first { $0.id == model.selectedPage } ?? model.settingsPages.first
    }

    private func pages(of group: SettingsGroup) -> [SettingsPage] {
        model.settingsPages.filter { $0.parent == group.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !rail { brand }
            search
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(model.settingsGroups) { group in
                        row(group)
                        // The rail shows children too, as icons. Hiding them
                        // there made six pages unreachable in a narrow window,
                        // because a group row only ever opens its first page.
                        let children = pages(of: group)
                        if isOpen(group), children.count > 1 {
                            ForEach(children) { child($0) }
                        }
                    }
                    if !rail, !model.workspaceNames.isEmpty { workspaces }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
            }
            Divider()
            footer
        }
        // Clears the traffic lights: the window runs its content under the
        // title bar, so the first thing in the sidebar would sit behind them.
        .padding(.top, 30)
    }

    // MARK: - Header

    private var brand: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Ink.gradient(model.accent))
                .frame(width: 26, height: 26)
                .overlay(Image(systemName: "cube")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white))
            Text(.appName).font(.system(size: 14, weight: .semibold))
            Spacer(minLength: 0)
            if !model.appVersion.isEmpty {
                Text(model.appVersion)
                    .font(.system(size: 9.5).monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .overlay(Capsule().strokeBorder(Ink.capStroke))
                    .help(String(localized: .appVersion(model.appVersion)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }

    private var search: some View {
        Button {
            model.actions?.openCommandPalette()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").font(.system(size: 12))
                if !rail {
                    Text(.appRunACommand).font(.system(size: 12))
                    Spacer(minLength: 0)
                    KeyCaps(parts: ["⌘", "K"])
                }
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .frame(height: 29)
            .frame(maxWidth: .infinity, alignment: rail ? .center : .leading)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Ink.card(scheme)))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Ink.stroke(scheme)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.bottom, 12)
        .help(String(localized: .appRunACommand))
    }

    // MARK: - Rows

    private func isOpen(_ group: SettingsGroup) -> Bool {
        current?.parent == group.id
    }

    private func row(_ group: SettingsGroup) -> some View {
        let open = isOpen(group)
        let children = pages(of: group)
        // A destination with one page is that page: selecting it has to land
        // somewhere, and there is nothing to expand into.
        let selected = open && children.count <= 1
        return Button {
            guard let first = children.first else { return }
            model.selectedPage = first.id
        } label: {
            HStack(spacing: 9) {
                Image(systemName: group.icon).font(.system(size: 13)).frame(width: 18)
                    .foregroundStyle(open ? model.accent : Color.secondary)
                if !rail {
                    Text(group.title)
                        .font(.system(size: 12.5, weight: open ? .medium : .regular))
                    Spacer(minLength: 0)
                }
            }
            .foregroundStyle(open ? Color.primary : Color.secondary)
            .padding(.horizontal, 9)
            .frame(height: 30)
            .frame(maxWidth: .infinity, alignment: rail ? .center : .leading)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selected ? Ink.raised(scheme) : .clear))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Ink.gradient(model.accent))
                    .frame(width: 2.5)
                    .padding(.vertical, 7)
                    .padding(.leading, -8)
                    .opacity(selected ? 1 : 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(String(localized: group.title))
    }

    private func child(_ page: SettingsPage) -> some View {
        let selected = current?.id == page.id
        return Button {
            model.selectedPage = page.id
        } label: {
            Group {
                if rail {
                    Image(systemName: page.icon).font(.system(size: 12)).frame(width: 18)
                } else {
                    Text(page.title).font(.system(size: 12, weight: selected ? .medium : .regular))
                }
            }
            .foregroundStyle(selected ? Color.primary : Color.secondary)
            .padding(.leading, rail ? 0 : 34)
            .padding(.trailing, rail ? 0 : 9)
            .frame(height: 26)
            .frame(maxWidth: .infinity, alignment: rail ? .center : .leading)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(selected ? Ink.raised(scheme) : .clear))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(selected ? AnyShapeStyle(Ink.gradient(model.accent))
                                   : AnyShapeStyle(Ink.hairline))
                    .frame(width: selected ? 2 : 1)
                    .padding(.vertical, selected ? 5 : 0)
                    .padding(.leading, 17)
                    .opacity(rail ? 0 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(String(localized: page.title))
    }

    private var workspaces: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(String(localized: .appWorkspaces).uppercased())
                .font(.system(size: 9.5, weight: .bold))
                .kerning(0.9)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 9)
                .padding(.top, 14)
                .padding(.bottom, 5)
            ForEach(model.workspaceNames.prefix(4), id: \.self) { name in
                Button {
                    model.actions?.launchWorkspace(named: name, onScreen: nil)
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "rectangle.3.group").font(.system(size: 12)).frame(width: 18)
                        Text(name).font(.system(size: 12)).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .frame(height: 27)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(String(localized: .appLaunchWorkspace(name)))
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            if rail {
                Button { model.actions?.reportBug() } label: {
                    Image(systemName: "ladybug").font(.system(size: 13)).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .help(String(localized: .appReportBug))
            } else {
                Picker("", selection: model.binding(\.appearance.theme, set: { $0.setTheme($1) })) {
                    ForEach(AppearanceSettings.Theme.allCases) { theme in
                        Image(systemName: theme.icon).tag(theme.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 96)
                .help(String(localized: .appThemePicker))
                Spacer(minLength: 0)
                Button { model.actions?.reportBug() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "ladybug").font(.system(size: 12))
                        Text(.appReport).font(.system(size: 11.5))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(String(localized: .appReportBug))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}
