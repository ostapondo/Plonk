import AppKit

// The menu bar item. A plain click opens the Plonk window; the dropdown moves
// to right-click and keeps only what is worth doing without opening anything.

final class StatusMenuController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()

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

    override init() {
        super.init()
        menu.delegate = self
        menu.addItem(entry("Open Plonk", #selector(openWindow)))
        menu.addItem(.separator())

        // Filled in on demand, so it tracks saved workspaces without wiring.
        let workspaces = NSMenuItem(title: "Launch Workspace", action: nil, keyEquivalent: "")
        workspaces.tag = Self.workspacesTag
        workspaces.submenu = NSMenu()
        menu.addItem(workspaces)

        // Also filled in on demand: agents come and go with their MCP sessions.
        let agents = NSMenuItem(title: "Active Agent", action: nil, keyEquivalent: "")
        agents.tag = Self.agentsTag
        agents.submenu = NSMenu()
        menu.addItem(agents)

        menu.addItem(entry("Capture Region", #selector(captureRegion), key: "s"))

        let awake = entry("Keep Screen Awake", #selector(toggleAwake))
        awake.tag = Self.keepAwakeTag
        menu.addItem(awake)

        menu.addItem(.separator())
        // Hidden unless there is something to install, so the menu keeps its
        // "only what is worth doing without opening anything" shape.
        let update = entry("Update Available", #selector(openUpdate))
        update.tag = Self.updateTag
        update.isHidden = true
        menu.addItem(update)
        menu.addItem(entry("Report a Bug", #selector(reportBug)))
        menu.addItem(NSMenuItem(title: "Quit Plonk",
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

    private func entry(_ title: String, _ action: Selector, key: String = "",
                       modifiers: NSEvent.ModifierFlags = [.control, .option]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
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
        menu.item(withTag: Self.keepAwakeTag)?.state = isAwakeRequested() ? .on : .off
        if let update = menu.item(withTag: Self.updateTag) {
            let version = updateVersion()
            update.isHidden = version == nil
            update.title = version.map { "Update to \($0)…" } ?? "Update Available"
        }
        refreshAgentsSubmenu(in: menu)

        guard let item = menu.item(withTag: Self.workspacesTag), let submenu = item.submenu else { return }
        item.isEnabled = !workspaceNames.isEmpty
        submenu.removeAllItems()
        guard !workspaceNames.isEmpty else {
            let empty = NSMenuItem(title: "No workspaces saved yet", action: nil, keyEquivalent: "")
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
            let empty = NSMenuItem(title: "No agents connected", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
            return
        }

        let any = NSMenuItem(title: "Any Agent", action: #selector(selectAgent(_:)), keyEquivalent: "")
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
        let exclusive = NSMenuItem(title: "Only Selected Agent Controls",
                                   action: hasSelection() ? #selector(toggleExclusive) : nil,
                                   keyEquivalent: "")
        exclusive.target = self
        exclusive.state = isExclusive() ? .on : .off
        submenu.addItem(exclusive)
    }
}
