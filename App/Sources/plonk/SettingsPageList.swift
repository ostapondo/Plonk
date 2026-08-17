import SwiftUI

// Which pages exist and where they sit.
//
// Five destinations, each holding the pages that belong to it. The flat list of
// eleven this replaced was ordered by nothing in particular, and its "Gadgets"
// group was a bucket for everything that fitted nowhere else — Voice, Keep
// Awake, Screenshot and Pointer have nothing to do with one another. Grouping
// by what the user is trying to do puts each of them somewhere findable.
//
// A group with a single page is drawn as that page: Home has no children to
// expand into, so it behaves as one entry.

enum SettingsPages {
    static let groups: [SettingsGroup] = [
        SettingsGroup(id: "home", title: .groupHome, icon: "house"),
        SettingsGroup(id: "layout", title: .groupLayout, icon: "square.grid.2x2"),
        SettingsGroup(id: "capture", title: .groupCapture, icon: "camera.viewfinder"),
        SettingsGroup(id: "automation", title: .groupAutomation, icon: "sparkles"),
        SettingsGroup(id: "settings", title: .groupSettings, icon: "slider.horizontal.3"),
    ]

    static let all: [SettingsPage] = [
        SettingsPage(id: "home", title: .pageHome, icon: "house", parent: "home") {
            AnyView(HomePage(model: $0))
        },
        SettingsPage(id: "zones", title: .pageZones, icon: "square.grid.2x2", parent: "layout") {
            AnyView(ZonesPage(model: $0))
        },
        SettingsPage(id: "workspaces", title: .pageWorkspaces, icon: "rectangle.3.group", parent: "layout") {
            AnyView(WorkspacesPage(model: $0))
        },
        SettingsPage(id: "shot", title: .pageShot, icon: "camera.viewfinder", parent: "capture") {
            AnyView(ShotPage(model: $0))
        },
        SettingsPage(id: "mouse", title: .pageMouse, icon: "cursorarrow.rays", parent: "capture") {
            AnyView(MousePage(model: $0))
        },
        SettingsPage(id: "ruler", title: .pageRuler, icon: "ruler", parent: "capture") {
            AnyView(RulerPage(model: $0))
        },
        SettingsPage(id: "ai", title: .pageAI, icon: "sparkles", parent: "automation") {
            AnyView(AIPage(model: $0))
        },
        SettingsPage(id: "voice", title: .pageVoice, icon: "mic", parent: "automation") {
            AnyView(VoicePage(model: $0))
        },
        SettingsPage(id: "appearance", title: .pageAppearance, icon: "paintpalette", parent: "settings") {
            AnyView(AppearancePage(model: $0))
        },
        SettingsPage(id: "shortcuts", title: .pageShortcuts, icon: "keyboard", parent: "settings") {
            AnyView(ShortcutsPage(model: $0))
        },
        SettingsPage(id: "awake", title: .pageAwake, icon: "cup.and.saucer", parent: "settings") {
            AnyView(AwakePage(model: $0))
        },
        SettingsPage(id: "active", title: .pageActive, icon: "person.wave.2", parent: "settings") {
            AnyView(ActivePage(model: $0))
        },
        SettingsPage(id: "update", title: .pageUpdate, icon: "arrow.down.circle", parent: "settings") {
            AnyView(UpdatePage(model: $0))
        },
    ]
}
