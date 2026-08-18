import AppKit

// The menu bar tidy: hide the icons that only need to be there sometimes.
//
// macOS gives no way to hide another app's status item, so this does what
// every menu bar manager does. Plonk puts two items of its own in the bar: a
// divider and a chevron. Everything the user drags to the left of the divider
// is the hidden set. Collapsing stretches the divider to a width no screen has,
// which shoves that set off the left edge; expanding puts the width back and
// they slide in again. One item changing length once, nothing polled, nothing
// captured, so it costs nothing while idle.
//
// The list of what is in the bar comes from the window server: every status
// item is a small window on the status bar layer, and its owner is the app.
// It is read when asked for, never on a timer.

struct MenuBarItemInfo: Identifiable, Equatable {
    /// Owner pid plus its index in that app's extras bar.
    let id: String
    let appName: String
    let pid: pid_t
    let index: Int
    /// Screen x, top-left origin (left edge is 0).
    let x: CGFloat
    let width: CGFloat
    /// Left of the divider while expanded, which is what collapsing hides.
    let hidden: Bool
}

final class MenuBarManager: NSObject {
    private var divider: NSStatusItem?
    private var chevron: NSStatusItem?
    private static let dividerName = "dev.plonk.menubar.divider"
    private static let chevronName = "dev.plonk.menubar.chevron"
    /// Wider than any display, which is what puts the hidden set off screen.
    private static let collapsedLength: CGFloat = 10_000
    private static let expandedLength: CGFloat = 8

    private(set) var enabled = false
    private(set) var collapsed = true

    /// Fires after the user clicks the chevron; the owner persists the state.
    var onToggle: ((Bool) -> Void)?

    func apply(_ config: Config) {
        if config.menuBarEnabled != enabled {
            enabled = config.menuBarEnabled
            enabled ? install() : remove()
        }
        if config.menuBarCollapsed != collapsed {
            setCollapsed(config.menuBarCollapsed)
        }
    }

    // MARK: Items in the bar

    private func install() {
        // A first launch puts the pair just left of Plonk's own icon rather
        // than at the far left, where every new status item is born; after
        // that macOS remembers wherever the user dragged them.
        let defaults = UserDefaults.standard
        let dividerKey = "NSStatusItem Preferred Position \(Self.dividerName)"
        let chevronKey = "NSStatusItem Preferred Position \(Self.chevronName)"
        if defaults.object(forKey: dividerKey) == nil {
            defaults.set(140, forKey: chevronKey)
            defaults.set(160, forKey: dividerKey)
        }

        let bar = NSStatusBar.system
        let chevron = bar.statusItem(withLength: NSStatusItem.squareLength)
        chevron.autosaveName = Self.chevronName
        chevron.button?.target = self
        chevron.button?.action = #selector(chevronClicked)
        self.chevron = chevron

        let divider = bar.statusItem(withLength: Self.expandedLength)
        divider.autosaveName = Self.dividerName
        divider.button?.imagePosition = .imageOnly
        divider.button?.appearsDisabled = true
        // A click on the divider expands too, so a bar that somehow lost its
        // chevron can always be brought back.
        divider.button?.target = self
        divider.button?.action = #selector(dividerClicked)
        self.divider = divider
        layout()
    }

    private func remove() {
        let bar = NSStatusBar.system
        if let divider { bar.removeStatusItem(divider) }
        if let chevron { bar.removeStatusItem(chevron) }
        divider = nil
        chevron = nil
    }

    private func layout() {
        guard let divider, let chevron else { return }
        divider.length = collapsed ? Self.collapsedLength : Self.expandedLength
        // The divider's own glyph would sit 5,000 points off screen while
        // collapsed, so it only draws when there is something to divide.
        divider.button?.image = collapsed ? nil
            : NSImage(systemSymbolName: "line.diagonal", accessibilityDescription: nil)
        let name = collapsed ? "chevron.left" : "chevron.right"
        chevron.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        chevron.button?.imagePosition = .imageOnly
    }

    @objc private func chevronClicked() {
        setCollapsed(!collapsed)
        onToggle?(collapsed)
    }

    @objc private func dividerClicked() {
        guard collapsed else { return }
        setCollapsed(false)
        onToggle?(false)
    }

    /// Collapsing only when the chevron sits right of the divider: the other
    /// way round the collapse would push the chevron itself off screen and
    /// take the way back with it.
    func setCollapsed(_ value: Bool) {
        guard value != collapsed else { return }
        if value, !chevronIsRightOfDivider { return }
        collapsed = value
        layout()
    }

    private var chevronIsRightOfDivider: Bool {
        guard let d = divider?.button?.window?.frame, let c = chevron?.button?.window?.frame
        else { return false }
        return c.minX >= d.maxX - 1
    }

    // MARK: Reading the bar

    /// Every other app's status item, left to right, and whether it is in the
    /// hidden set. Read on demand; nothing is cached.
    ///
    /// Asked of each app over Accessibility rather than of the window server:
    /// since macOS 26 every status item window belongs to Control Center and
    /// is called "Item-0", so that list cannot say whose icon is whose. An
    /// app's `AXExtrasMenuBar` can, and carries the frame the same way.
    func items() -> [MenuBarItemInfo] {
        guard let dividerX = dividerX() else { return [] }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        var out: [MenuBarItemInfo] = []
        for app in NSWorkspace.shared.runningApplications where app.processIdentifier != ownPID {
            let element = AXUIElementCreateApplication(app.processIdentifier)
            var extras: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, "AXExtrasMenuBar" as CFString, &extras) == .success,
                  let bar = extras, CFGetTypeID(bar) == AXUIElementGetTypeID()
            else { continue }
            var kids: CFTypeRef?
            guard AXUIElementCopyAttributeValue(bar as! AXUIElement, kAXChildrenAttribute as CFString, &kids) == .success,
                  let children = kids as? [AXUIElement]
            else { continue }
            let name = app.localizedName ?? "?"
            for (index, child) in children.enumerated() {
                guard let frame = Self.frame(of: child), frame.width > 0 else { continue }
                out.append(MenuBarItemInfo(id: "\(app.processIdentifier):\(index)", appName: name,
                                           pid: app.processIdentifier, index: index,
                                           x: frame.minX, width: frame.width,
                                           hidden: frame.maxX <= dividerX))
            }
        }
        return out.sorted { $0.x < $1.x }
    }

    /// Position and size as AX reports them: screen points, top-left origin,
    /// the same frame the window server uses for the bar.
    private static func frame(of element: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posValue = posRef, let sizeValue = sizeRef
        else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(posValue as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }

    /// The divider's left edge in screen x. Screen x is shared between AppKit
    /// and the top-left spaces on the main display, so no flip is needed.
    private func dividerX() -> CGFloat? {
        guard let window = divider?.button?.window else { return nil }
        return window.frame.minX
    }
}
