import AppKit
import ApplicationServices

// Every shortcut the front app actually has, on one screen.
//
// PowerToys ships a picture of the Windows key shortcuts — a fixed list that
// goes stale and covers one app. On macOS the same idea can be done properly:
// every app publishes its menus through Accessibility, key equivalents
// included, so the guide is read off the app itself. It is never out of date,
// it works for software nobody has ever heard of, and it needs no database.

enum ShortcutGuide {

    struct Item: Identifiable {
        let id = UUID()
        let menu: String
        let title: String
        /// Rendered the way the menu draws it, e.g. "⇧⌘K".
        let keys: String
    }

    /// Walks the front app's menu bar. AX calls block on the other process, so
    /// this belongs on a background queue; the callback lands on the main one.
    static func read(for app: NSRunningApplication, completion: @escaping ([Item]) -> Void) {
        let pid = app.processIdentifier
        DispatchQueue.global(qos: .userInitiated).async {
            let items = collect(pid: pid)
            DispatchQueue.main.async { completion(items) }
        }
    }

    private static func collect(pid: pid_t) -> [Item] {
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 1.0)
        guard let bar = element(application, kAXMenuBarAttribute) else { return [] }

        var items: [Item] = []
        for topLevel in children(of: bar) {
            let name = string(topLevel, kAXTitleAttribute) ?? ""
            // The leftmost menu is the Apple menu, which belongs to the system
            // rather than to the app in front.
            guard !name.isEmpty, name != "Apple" else { continue }
            for child in children(of: topLevel) {
                items.append(contentsOf: walk(child, menu: name, depth: 0))
            }
        }
        return items
    }

    /// Menus nest — a submenu is a child of an item — so this recurses, with a
    /// bound because a broken AX tree can hand back a cycle.
    private static func walk(_ element: AXUIElement, menu: String, depth: Int) -> [Item] {
        guard depth < 4 else { return [] }
        var items: [Item] = []
        for child in children(of: element) {
            let role = string(child, kAXRoleAttribute)
            if role == kAXMenuRole {
                items.append(contentsOf: walk(child, menu: menu, depth: depth + 1))
                continue
            }
            guard let title = string(child, kAXTitleAttribute), !title.isEmpty else { continue }
            if let keys = shortcut(of: child) {
                items.append(Item(menu: menu, title: title, keys: keys))
            }
            items.append(contentsOf: walk(child, menu: menu, depth: depth + 1))
        }
        return items
    }

    /// The key equivalent as the menu would draw it, or nil when the item has
    /// none — which is most of them.
    private static func shortcut(of item: AXUIElement) -> String? {
        guard let character = string(item, kAXMenuItemCmdCharAttribute), !character.isEmpty else { return nil }
        let raw = (copy(item, kAXMenuItemCmdModifiersAttribute) as? NSNumber)?.intValue ?? 0
        return modifiers(raw) + character.uppercased()
    }

    /// AXMenuItemCmdModifiers is a bit field where Command is the *absence* of
    /// bit 3, because Command is the default for a menu key equivalent.
    static func modifiers(_ raw: Int) -> String {
        var text = ""
        if raw & 0x04 != 0 { text += "⌃" }
        if raw & 0x02 != 0 { text += "⌥" }
        if raw & 0x01 != 0 { text += "⇧" }
        if raw & 0x08 == 0 { text += "⌘" }
        return text
    }

    // MARK: - AX plumbing

    private static func copy(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        copy(element, attribute) as? String
    }

    private static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = copy(element, attribute), CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        (copy(element, kAXChildrenAttribute) as? [AXUIElement]) ?? []
    }
}
