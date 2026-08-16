import AppKit
import SwiftUI

// The menu bar item. A plain click opens the Plonk window; the dropdown moves
// to right-click and keeps only what is worth doing without opening anything.
//
// The dropdown opens with the live zone set drawn across the top, and every
// rectangle in it sends the front window there. That is the fourth way to place
// a window: no shortcut to have learned, and nothing to be dragging.

final class StatusMenuController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    /// Rebuilt every time the menu opens, so the grid is the set that is live
    /// on the screen right now rather than the one that was there at launch.
    private let zonesHost = NSHostingView(rootView: StatusMenuZones(zones: [], summary: "",
                                                                    snap: { _ in }))

    /// The set on the main screen, and the line describing what is running.
    var zonesOnMainScreen: () -> [ZoneRect] = { [] }
    var setSummary: () -> String = { "" }
    var onSnapZone: ((Int) -> Void)?

    var isAwakeRequested: () -> Bool = { false }
    var workspaceNames: [String] = []
    /// Connected agents plus whether each one is the user's pick, queried when
    /// the menu opens so it always reflects live presence.
    var agentEntries: () -> [(name: String, selected: Bool)] = { [] }
    var isExclusive: () -> Bool = { false }
    var hasSelection: () -> Bool = { false }
    /// The version on offer, or nil when the copy is current. Queried when the
    /// menu opens, so a check that lands while it is shut still shows up.
    var updateVersion: () -> String? = { nil }

    var onOpenWindow: (() -> Void)?
    var onCaptureRegion: (() -> Void)?
    var onToggleAwake: (() -> Void)?
    var onLaunchWorkspace: ((String) -> Void)?
    var onReportBug: (() -> Void)?
    var onSelectAgent: ((String?) -> Void)?
    var onToggleExclusive: (() -> Void)?
    var onOpenUpdate: (() -> Void)?

    private static let keepAwakeTag = 101
    private static let workspacesTag = 102
    private static let agentsTag = 103
    private static let updateTag = 104

    private static let zonesTag = 105

    override init() {
        super.init()
        menu.delegate = self

        zonesHost.frame = NSRect(x: 0, y: 0, width: StatusMenuZones.width,
                                 height: StatusMenuZones.height)
        let zones = NSMenuItem()
        zones.tag = Self.zonesTag
        zones.view = zonesHost
        menu.addItem(zones)
        menu.addItem(.separator())

        menu.addItem(entry(.menuOpenPlonk, #selector(openWindow)))
        menu.addItem(.separator())

        // Filled in on demand, so it tracks saved workspaces without wiring.
        let workspaces = NSMenuItem(title: String(localized: .menuLaunchWorkspace),
                                    action: nil, keyEquivalent: "")
        workspaces.tag = Self.workspacesTag
        workspaces.submenu = NSMenu()
        menu.addItem(workspaces)

        // Also filled in on demand: agents come and go with their MCP sessions.
        let agents = NSMenuItem(title: String(localized: .menuActiveAgent),
                                action: nil, keyEquivalent: "")
        agents.tag = Self.agentsTag
        agents.submenu = NSMenu()
        menu.addItem(agents)

        menu.addItem(entry(.menuCaptureRegion, #selector(captureRegion), key: "s"))

        let awake = entry(.menuKeepAwake, #selector(toggleAwake))
        awake.tag = Self.keepAwakeTag
        menu.addItem(awake)

        menu.addItem(.separator())
        // Hidden unless there is something to install, so the menu keeps its
        // "only what is worth doing without opening anything" shape.
        let update = entry(.menuUpdateAvailable, #selector(openUpdate))
        update.tag = Self.updateTag
        update.isHidden = true
        menu.addItem(update)
        menu.addItem(entry(.menuReportBug, #selector(reportBug)))
        menu.addItem(NSMenuItem(title: String(localized: .menuQuit),
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // Assigning item.menu permanently would swallow the click, so the button
        // keeps its action and the menu is attached only for a right-click.
        item.button?.target = self
        item.button?.action = #selector(buttonClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    func refresh(icon: NSImage, tooltip: String, dimmed: Bool) {
        guard let button = item.button else { return }
        button.image = icon
        button.imagePosition = .imageOnly
        button.title = ""
        button.appearsDisabled = dimmed
        button.toolTip = tooltip
    }

    @objc private func buttonClicked() {
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        guard wantsMenu else {
            onOpenWindow?()
            return
        }
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    private func entry(_ title: LocalizedStringResource, _ action: Selector, key: String = "",
                       modifiers: NSEvent.ModifierFlags = [.control, .option]) -> NSMenuItem {
        let item = NSMenuItem(title: String(localized: title), action: action, keyEquivalent: key)
        if !key.isEmpty { item.keyEquivalentModifierMask = modifiers }
        item.target = self
        return item
    }

    @objc private func openWindow() { onOpenWindow?() }
    @objc private func captureRegion() { onCaptureRegion?() }
    @objc private func toggleAwake() { onToggleAwake?() }
    @objc private func reportBug() { onReportBug?() }
    @objc private func openUpdate() { onOpenUpdate?() }

    @objc private func launchWorkspace(_ sender: NSMenuItem) {
        onLaunchWorkspace?(sender.title)
    }

    @objc private func selectAgent(_ sender: NSMenuItem) {
        onSelectAgent?(sender.representedObject as? String)
    }

    @objc private func toggleExclusive() { onToggleExclusive?() }
}

extension StatusMenuController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        zonesHost.rootView = StatusMenuZones(
            zones: zonesOnMainScreen(),
            summary: setSummary(),
            snap: { [weak self] number in
                // The menu is tracking its own event loop, so it has to be told
                // to stop before the window it is about to move can take focus.
                menu.cancelTracking()
                self?.onSnapZone?(number)
            }
        )
        menu.item(withTag: Self.keepAwakeTag)?.state = isAwakeRequested() ? .on : .off
        if let update = menu.item(withTag: Self.updateTag) {
            let version = updateVersion()
            update.isHidden = version == nil
            update.title = String(localized: version.map { .menuUpdateTo($0) } ?? .menuUpdateAvailable)
        }
        refreshAgentsSubmenu(in: menu)

        guard let item = menu.item(withTag: Self.workspacesTag), let submenu = item.submenu else { return }
        item.isEnabled = !workspaceNames.isEmpty
        submenu.removeAllItems()
        guard !workspaceNames.isEmpty else {
            let empty = NSMenuItem(title: String(localized: .menuNoWorkspaces),
                                   action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
            return
        }
        for name in workspaceNames {
            let entry = NSMenuItem(title: name, action: #selector(launchWorkspace(_:)), keyEquivalent: "")
            entry.target = self
            submenu.addItem(entry)
        }
    }

    private func refreshAgentsSubmenu(in menu: NSMenu) {
        guard let item = menu.item(withTag: Self.agentsTag), let submenu = item.submenu else { return }
        submenu.removeAllItems()
        let entries = agentEntries()
        guard !entries.isEmpty else {
            let empty = NSMenuItem(title: String(localized: .menuNoAgents),
                                   action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
            return
        }

        let any = NSMenuItem(title: String(localized: .menuAnyAgent),
                             action: #selector(selectAgent(_:)), keyEquivalent: "")
        any.target = self
        any.state = hasSelection() ? .off : .on
        submenu.addItem(any)
        for (name, selected) in entries {
            let entry = NSMenuItem(title: name, action: #selector(selectAgent(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = name
            entry.state = selected ? .on : .off
            submenu.addItem(entry)
        }

        submenu.addItem(.separator())
        let exclusive = NSMenuItem(title: String(localized: .menuOnlySelectedAgent),
                                   action: hasSelection() ? #selector(toggleExclusive) : nil,
                                   keyEquivalent: "")
        exclusive.target = self
        exclusive.state = isExclusive() ? .on : .off
        submenu.addItem(exclusive)
    }
}
