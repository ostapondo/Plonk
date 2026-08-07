import AppKit

// The menu bar item. A plain click opens the Plonk window; the dropdown moves
// to right-click and keeps only what is worth doing without opening anything.

final class StatusMenuController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()

    var isAwakeRequested: () -> Bool = { false }
    var workspaceNames: [String] = []

    var onOpenWindow: (() -> Void)?
    var onCaptureRegion: (() -> Void)?
    var onToggleAwake: (() -> Void)?
    var onLaunchWorkspace: ((String) -> Void)?
    var onReportBug: (() -> Void)?

    private static let keepAwakeTag = 101
    private static let workspacesTag = 102

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

        menu.addItem(entry("Capture Region", #selector(captureRegion), key: "s"))

        let awake = entry("Keep Screen Awake", #selector(toggleAwake))
        awake.tag = Self.keepAwakeTag
        menu.addItem(awake)

        menu.addItem(.separator())
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

    @objc private func launchWorkspace(_ sender: NSMenuItem) {
        onLaunchWorkspace?(sender.title)
    }
}

extension StatusMenuController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.item(withTag: Self.keepAwakeTag)?.state = isAwakeRequested() ? .on : .off

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
}
