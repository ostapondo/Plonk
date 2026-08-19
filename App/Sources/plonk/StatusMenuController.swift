import AppKit
import SwiftUI

// The menu bar item. Either button opens the same dropdown: what is worth
// doing without opening anything, and under Features a switch for every
// module, so the menu stays only as long as what is switched on.

final class StatusMenuController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    /// The switches, as a second menu dropped from the same icon.
    private let toolsMenu = NSMenu()
    /// Rebuilt every time the menu opens, and after every flip, so the switches
    /// show what config holds now.
    private let featuresHost = NSHostingView(rootView: StatusMenuFeatures(isOn: { _ in true },
                                                                          toggle: { _, _ in }))

    var isAwakeRequested: () -> Bool = { false }
    var isFeatureEnabled: (Feature) -> Bool = { _ in true }
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
    var onToggleFeature: ((Feature, Bool) -> Void)?

    private static let keepAwakeTag = 101
    private static let workspacesTag = 102
    private static let agentsTag = 103
    private static let updateTag = 104
    private static let captureTag = 105

    /// Which entry belongs to which feature, so an entry is hidden with it.
    private static let featureTags: [(tag: Int, feature: Feature)] = [
        (workspacesTag, .workspaces), (captureTag, .shot), (keepAwakeTag, .awake),
    ]

    override init() {
        super.init()
        menu.delegate = self

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

        let capture = entry(.menuCaptureRegion, #selector(captureRegion), key: "s")
        capture.tag = Self.captureTag
        menu.addItem(capture)

        let awake = entry(.menuKeepAwake, #selector(toggleAwake))
        awake.tag = Self.keepAwakeTag
        menu.addItem(awake)

        menu.addItem(.separator())
        // Not a submenu: the switches open as a menu of their own, dropped
        // from the icon once this one has closed, so they have the room and
        // the menu stays a list of things to do.
        menu.addItem(entry(.menuTools, #selector(openTools)))
        featuresHost.frame = NSRect(x: 0, y: 0, width: StatusMenuFeatures.width,
                                    height: StatusMenuFeatures.height)
        let switches = NSMenuItem()
        switches.view = featuresHost
        toolsMenu.addItem(switches)

        menu.addItem(.separator())
        // Hidden unless there is something to install, so the menu keeps its
        // "only what is worth doing without opening anything" shape.
        let update = entry(.menuUpdateAvailable, #selector(openUpdate))
        update.tag = Self.updateTag
        update.isHidden = true
        menu.addItem(update)
        menu.addItem(entry(.menuReportBug, #selector(reportBug)))
        // Through a selector of its own rather than NSApplication.terminate:
        // macOS draws an icon beside the standard one, and the whole section
        // indents to make room for it.
        menu.addItem(entry(.menuQuit, #selector(quit), key: "q", modifiers: .command))

        item.menu = menu
    }

    func refresh(icon: NSImage, tooltip: String, dimmed: Bool) {
        guard let button = item.button else { return }
        button.image = icon
        button.imagePosition = .imageOnly
        button.title = ""
        button.appearsDisabled = dimmed
        button.toolTip = tooltip
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
    @objc private func quit() { NSApp.terminate(nil) }

    /// Runs after the dropdown has closed. The item's menu is swapped for the
    /// length of one click so the switches drop from the icon like the
    /// dropdown does, then put back so the next click opens the dropdown.
    @objc private func openTools() {
        refreshFeatures()
        item.menu = toolsMenu
        item.button?.performClick(nil)
        item.menu = menu
    }

    @objc private func launchWorkspace(_ sender: NSMenuItem) {
        onLaunchWorkspace?(sender.title)
    }

    @objc private func selectAgent(_ sender: NSMenuItem) {
        onSelectAgent?(sender.representedObject as? String)
    }

    @objc private func toggleExclusive() { onToggleExclusive?() }

    /// Entries for a feature that is off leave the menu, and the switches show
    /// the state as it now stands. Run when the menu opens and after every flip,
    /// so a feature switched off while the menu is up disappears on the spot.
    private func refreshFeatures() {
        for (tag, feature) in Self.featureTags {
            menu.item(withTag: tag)?.isHidden = !isFeatureEnabled(feature)
        }
        featuresHost.rootView = StatusMenuFeatures(
            isOn: { [weak self] feature in self?.isFeatureEnabled(feature) ?? true },
            toggle: { [weak self] feature, on in
                self?.onToggleFeature?(feature, on)
                self?.refreshFeatures()
            }
        )
    }
}

extension StatusMenuController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === self.menu else { return }
        refreshFeatures()
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
