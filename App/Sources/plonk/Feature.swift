import Foundation

// The modules a user can switch off as a whole, from the menu bar or the
// Features page. One id per module, matching its settings page, so the same
// word names the page that disappears, the shortcuts that go quiet and the
// routes an agent is refused.
//
// Off means off everywhere: the page leaves the sidebar, its entry leaves the
// menu, its hotkeys are not registered, its manager stands down and its routes
// answer 409. A disabled feature keeps its settings, so switching it back on
// restores exactly what was there.

enum Feature: String, CaseIterable, Identifiable {
    case zones, workspaces, shot, mouse, ruler, voice, awake

    var id: String { rawValue }

    /// The settings page of the same module; hidden while the feature is off.
    var pageID: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .zones: return .pageZones
        case .workspaces: return .pageWorkspaces
        case .shot: return .pageShot
        case .mouse: return .pageMouse
        case .ruler: return .pageRuler
        case .voice: return .pageVoice
        case .awake: return .pageAwake
        }
    }

    /// One line under the name, saying what goes quiet when it is off.
    var detail: LocalizedStringResource {
        switch self {
        case .zones: return .featureZonesDetail
        case .workspaces: return .featureWorkspacesDetail
        case .shot: return .featureShotDetail
        case .mouse: return .featureMouseDetail
        case .ruler: return .featureRulerDetail
        case .voice: return .featureVoiceDetail
        case .awake: return .featureAwakeDetail
        }
    }

    var icon: String {
        switch self {
        case .zones: return "square.grid.2x2"
        case .workspaces: return "rectangle.3.group"
        case .shot: return "camera.viewfinder"
        case .mouse: return "cursorarrow.rays"
        case .ruler: return "ruler"
        case .voice: return "mic"
        case .awake: return "waveform.path.ecg"
        }
    }

    /// The routes the module answers, by first path segment. A request to one
    /// while the feature is off is refused before any handler sees it.
    var routePrefixes: [String] {
        switch self {
        case .zones: return ["/layout", "/zones"]
        case .workspaces: return ["/workspaces", "/layouts"]
        case .shot: return ["/shot"]
        case .ruler: return ["/ruler"]
        case .awake: return ["/awake"]
        case .mouse, .voice: return []
        }
    }

    /// The feature a route belongs to, nil for the ones that are the app itself.
    static func owning(path: String) -> Feature? {
        allCases.first { feature in
            feature.routePrefixes.contains { path == $0 || path.hasPrefix($0 + "/") }
        }
    }

    /// The feature a shortcut belongs to, by the page that owns it. Nil for the
    /// shortcuts that are the app itself: the palette and the guide.
    static func owning(_ action: HotkeyAction) -> Feature? {
        Feature(rawValue: action.page)
    }

    /// The feature behind a settings page, nil for a page that is always there.
    static func owning(page id: String) -> Feature? {
        Feature(rawValue: id)
    }

    /// What an agent reads back when a route it called is switched off.
    var offReason: String {
        "\(rawValue) is switched off in Plonk, so this request was not carried out. "
            + "The user can switch it back on under Tools in Plonk's menu bar menu or in the app."
    }
}
