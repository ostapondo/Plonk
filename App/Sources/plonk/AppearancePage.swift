import SwiftUI

// Theme and accent. Both reach further than this window: the theme decides the
// appearance every panel is drawn with, and the accent is what the zone overlay
// and the HUD tint themselves with unless the Zones page overrides the colour.

struct AppearancePage: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHead(title: .appearanceTheme, note: .appearanceThemeNote)
                themes
                SectionHead(title: .appearanceAccent)
                accents
                Text(.appearanceAccentNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
    }

    // MARK: - Theme

    private var themes: some View {
        HStack(spacing: 12) {
            ForEach(AppearanceSettings.Theme.allCases) { theme in
                card(theme)
            }
        }
    }

    private func card(_ theme: AppearanceSettings.Theme) -> some View {
        let selected = model.config.appearance.resolvedTheme == theme
        return Button {
            model.actions?.update(\.appearance.theme, to: theme.rawValue)
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                ThemePreview(theme: theme)
                    .frame(height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Ink.stroke(scheme)))
                HStack(spacing: 7) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13))
                        .foregroundStyle(selected ? model.accent : Color.secondary)
                    Text(theme.title).font(.system(size: 12.5, weight: .medium))
                    Spacer(minLength: 4)
                    Text(theme.note).font(.system(size: 10.5)).muted()
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: Ink.radius, style: .continuous).fill(Ink.card(scheme)))
            .overlay(RoundedRectangle(cornerRadius: Ink.radius, style: .continuous)
                .strokeBorder(selected ? model.accent : Ink.stroke(scheme), lineWidth: selected ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(String(localized: .appearanceThemeHelp(String(localized: theme.title),
                                                      String(localized: theme.note))))
    }

    // MARK: - Accent

    /// Set the accent and show it. The zone overlay tints itself with the
    /// accent unless it was given a colour of its own, so a flash is how the
    /// choice is seen on something other than this page.
    private func chooseAccent(_ hex: String?) {
        model.actions?.update(\.appearance.accentHex, to: hex)
        model.actions?.flashZones()
    }

    private var accents: some View {
        HStack(spacing: 9) {
            ForEach(AppearanceSettings.accentChoices, id: \.self) { hex in
                swatch(hex)
            }
            Spacer(minLength: 8)
            Text(.appearanceMatchSystemAccent).font(.system(size: 12)).foregroundStyle(.secondary)
            Toggle("", isOn: Binding(
                get: { model.config.appearance.accentHex == nil },
                set: { chooseAccent($0 ? nil : AppearanceSettings.accentChoices.last) }
            ))
            .labelsHidden().toggleStyle(.switch).controlSize(.small)
            .help(String(localized: .appearanceFollowSystemAccent))
        }
        .padding(13)
        .card()
    }

    private func swatch(_ hex: String) -> some View {
        let selected = model.config.appearance.accentHex?.caseInsensitiveCompare(hex) == .orderedSame
        let colour = Color(nsColor: ZoneAppearance.color(fromHex: hex) ?? .controlAccentColor)
        return Button {
            chooseAccent(hex)
        } label: {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(colour)
                .frame(width: 26, height: 26)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.12)))
                .padding(3)
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(selected ? colour : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .help(hex)
    }
}

/// A drawing of what a theme looks like, not a live view of one: the colours
/// are literal so the light card stays light while the app is in the dark
/// theme, which is the whole point of showing three of them at once.
struct ThemePreview: View {
    let theme: AppearanceSettings.Theme

    private static let darkSide = Color(red: 0.059, green: 0.067, blue: 0.086)
    private static let darkPanel = Color(red: 0.086, green: 0.098, blue: 0.129)
    private static let darkBar = Color(red: 0.137, green: 0.149, blue: 0.192)
    private static let lightSide = Color(red: 0.984, green: 0.984, blue: 0.992)
    private static let lightPanel = Color(red: 0.957, green: 0.961, blue: 0.973)
    private static let lightBar = Color(red: 0.859, green: 0.878, blue: 0.910)

    var body: some View {
        switch theme {
        case .dark: pane(dark: true)
        case .light: pane(dark: false)
        case .system: split
        }
    }

    /// Both halves drawn full width, the dark one clipped to the left half, so
    /// the seam falls in the middle of the picture rather than on a boundary
    /// that happens to be there.
    private var split: some View {
        pane(dark: false)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    pane(dark: true)
                        .frame(width: geo.size.width)
                        .clipShape(Rectangle().offset(x: -geo.size.width / 2))
                }
            }
            .overlay(alignment: .center) {
                Rectangle().fill(Color.accentColor.opacity(0.8)).frame(width: 1)
            }
    }

    private func pane(dark: Bool) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                bar(width: 0.55, gradient: true, dark: dark)
                bar(width: 0.8, gradient: false, dark: dark)
                bar(width: 0.65, gradient: false, dark: dark)
                bar(width: 0.75, gradient: false, dark: dark)
                Spacer(minLength: 0)
            }
            .padding(7)
            .frame(width: 60)
            .frame(maxHeight: .infinity)
            .background(dark ? Self.darkSide : Self.lightSide)

            VStack(alignment: .leading, spacing: 6) {
                bar(width: 0.5, gradient: false, dark: dark)
                RoundedRectangle(cornerRadius: 4)
                    .fill(dark ? Self.darkSide : .white)
                    .frame(height: 22)
                RoundedRectangle(cornerRadius: 4)
                    .fill(dark ? Self.darkSide : .white)
                    .frame(height: 22)
                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(dark ? Self.darkPanel : Self.lightPanel)
        }
    }

    private func bar(width: CGFloat, gradient: Bool, dark: Bool) -> some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 3)
                .fill(gradient
                      ? AnyShapeStyle(Ink.gradient(Color.accentColor))
                      : AnyShapeStyle(dark ? Self.darkBar : Self.lightBar))
                .frame(width: geo.size.width * width, height: 5)
        }
        .frame(height: 5)
    }
}
