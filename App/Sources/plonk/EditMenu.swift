import AppKit

// The menu nobody sees, and every text field needs.
//
// ⌘C, ⌘V, ⌘X, ⌘A and ⌘Z are not built into NSTextField. AppKit delivers them
// by asking the main menu for a matching key equivalent and sending the
// selector down the responder chain — so an app with no main menu has text
// fields that cannot be pasted into, and there is nothing in the field itself
// to fix. Plonk had none, which is why the command palette would take a typed
// sentence but not a pasted one.
//
// An accessory app never draws a menu bar, so this adds no visible surface: it
// exists purely so `performKeyEquivalent` has somewhere to look. Nothing here
// has a target, on purpose — nil means the responder chain, which is the field
// that happens to be focused.

enum EditMenu {
    static func install(on app: NSApplication) {
        let edit = NSMenu(title: String(localized: .editMenu))
        for item in items() { edit.addItem(item) }

        let editItem = NSMenuItem()
        editItem.submenu = edit

        let main = NSMenu()
        main.addItem(editItem)
        app.mainMenu = main
    }

    private static func items() -> [NSMenuItem] {
        [
            item(String(localized: .editUndo), "undo:", "z"),
            item(String(localized: .editRedo), "redo:", "Z"),
            .separator(),
            item(String(localized: .editCut), "cut:", "x"),
            item(String(localized: .editCopy), "copy:", "c"),
            item(String(localized: .editPaste), "paste:", "v"),
            item(String(localized: .editSelectAll), "selectAll:", "a"),
        ]
    }

    /// An uppercase key means shift is part of the equivalent, which is how
    /// AppKit spells ⌘⇧Z without a separate modifier mask.
    private static func item(_ title: String, _ selector: String, _ key: String) -> NSMenuItem {
        let shifted = key != key.lowercased()
        let entry = NSMenuItem(title: title, action: Selector(selector),
                               keyEquivalent: key.lowercased())
        entry.keyEquivalentModifierMask = shifted ? [.command, .shift] : [.command]
        return entry
    }
}
