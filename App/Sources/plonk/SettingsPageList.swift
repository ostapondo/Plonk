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
        SettingsGroup(id: "home", title: "Home", icon: "house"),
        SettingsGroup(id: "layout", title: "Layout", icon: "square.grid.2x2"),
        SettingsGroup(id: "capture", title: "Capture", icon: "camera.viewfinder"),
        SettingsGroup(id: "automation", title: "Automation", icon: "sparkles"),
        SettingsGroup(id: "settings", title: "Settings", icon: "slider.horizontal.3"),
    ]

    static let all: [SettingsPage] = [
        SettingsPage(id: "home", title: "Home", icon: "house", parent: "home") {
            AnyView(HomePage(model: $0))
        },
        SettingsPage(id: "zones", title: "Zones", icon: "square.grid.2x2", parent: "layout") {
            AnyView(ZonesPage(model: $0))
        },
        SettingsPage(id: "workspaces", title: "Workspaces", icon: "rectangle.3.group", parent: "layout") {
            AnyView(WorkspacesPage(model: $0))
        },
        SettingsPage(id: "shot", title: "Screenshot", icon: "camera.viewfinder", parent: "capture") {
            AnyView(ShotPage(model: $0))
        },
        SettingsPage(id: "mouse", title: "Pointer & clicks", icon: "cursorarrow.rays", parent: "capture") {
            AnyView(MousePage(model: $0))
        },
        SettingsPage(id: "ruler", title: "Ruler", icon: "ruler", parent: "capture") {
            AnyView(RulerPage(model: $0))
        },
        SettingsPage(id: "ai", title: "Agents & MCP", icon: "sparkles", parent: "automation") {
            AnyView(AIPage(model: $0))
        },
        SettingsPage(id: "voice", title: "Voice", icon: "mic", parent: "automation") {
            AnyView(VoicePage(model: $0))
        },
        SettingsPage(id: "appearance", title: "Appearance", icon: "paintpalette", parent: "settings") {
            AnyView(AppearancePage(model: $0))
        },
        SettingsPage(id: "shortcuts", title: "Keyboard", icon: "keyboard", parent: "settings") {
            AnyView(ShortcutsPage(model: $0))
        },
        SettingsPage(id: "awake", title: "Keep awake", icon: "cup.and.saucer", parent: "settings") {
            AnyView(AwakePage(model: $0))
        },
        SettingsPage(id: "update", title: "Updates", icon: "arrow.down.circle", parent: "settings") {
            AnyView(UpdatePage(model: $0))
        },
    ]
}
