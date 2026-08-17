import AppKit

// How the app looks: the theme it follows and the colour it accents with.
// One object rather than two fields on Config, so the next appearance setting
// costs the config decoder nothing.

struct AppearanceSettings: Codable, Equatable {
    /// "system" hands the choice to macOS; the other two override it.
    var theme = Theme.system.rawValue
    /// "#RRGGBB", or nil to follow the system accent colour.
    var accentHex: String?

    enum Theme: String, CaseIterable, Identifiable {
        case system, light, dark

        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .system: return .appearanceThemeSystem
            case .light: return .appearanceThemeLight
            case .dark: return .appearanceThemeDark
            }
        }

        var note: LocalizedStringResource {
            switch self {
            case .system: return .appearanceThemeSystemNote
            case .light: return .appearanceThemeLightNote
            case .dark: return .appearanceThemeDarkNote
            }
        }

        var icon: String {
            switch self {
            case .system: return "laptopcomputer"
            case .light: return "sun.max"
            case .dark: return "moon"
            }
        }

        /// Nil hands the window back to macOS.
        var nsAppearance: NSAppearance? {
            switch self {
            case .system: return nil
            case .light: return NSAppearance(named: .aqua)
            case .dark: return NSAppearance(named: .darkAqua)
            }
        }
    }

    /// Anything unrecognised in a hand-edited file reads as "system".
    var resolvedTheme: Theme { Theme(rawValue: theme) ?? .system }

    /// The colour the app draws itself with. Falls back to the system accent,
    /// which is also what the zone overlay does when it has no colour of its own.
    var accent: NSColor { ZoneAppearance.color(fromHex: accentHex) ?? .controlAccentColor }

    /// What the picker offers. Nil — the system accent — is offered separately,
    /// because it is a different kind of choice from picking a colour.
    static let accentChoices = ["#F2795F", "#E5484D", "#F0AA3C", "#34D17F",
                                "#3B9DFF", "#8B7CF6", "#E05FA8", "#8B93A6"]

    init() {}

    // Tolerate missing keys, the same way Config does.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        theme = try c.decodeIfPresent(String.self, forKey: .theme) ?? Theme.system.rawValue
        accentHex = try c.decodeIfPresent(String.self, forKey: .accentHex)
    }

    /// Applies to every window at once, including the ones already on screen.
    ///
    /// Which is why it checks first: this runs after every config change, and
    /// assigning the appearance makes every open window re-resolve and redraw.
    /// Dragging the zone colour writes config per tick, and the whole UI must
    /// not repaint at drag frequency for a setting that did not move.
    func apply(to app: NSApplication) {
        let wanted = resolvedTheme.nsAppearance
        guard app.appearance != wanted else { return }
        app.appearance = wanted
    }
}
