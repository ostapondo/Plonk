import AppKit
import ApplicationServices

// The Accessibility calls Plonk makes, and nothing else: no state, no policy,
// no announcing. Reading or writing another app's window is synchronous IPC
// into that app, so every element made here carries a timeout — a hung app
// must not take the cursor with it during a drag.
//
// WindowManager decides where a window goes; this is the whole of how it gets
// there, so it is the one file to read when macOS changes what an app may do
// to another app's windows. Reading a menu bar (ShortcutGuide) and subscribing
// to window-opened notifications (NewWindowWatcher) are different surfaces and
// stay where they are.

enum WindowAccess {
    /// Drag snapping makes one call per mouse event, so the wait is short
    /// enough to drop a frame rather than the drag.
    static let timeout: Float = 0.25

    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func promptForTrust() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }

    static func application(_ pid: pid_t) -> AXUIElement {
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, timeout)
        return element
    }

    static func attribute(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, name as CFString, &value) == .success else { return nil }
        return value
    }

    static func windows(of pid: pid_t) -> [AXUIElement] {
        guard let windows = attribute(application(pid), kAXWindowsAttribute) as? [AXUIElement] else { return [] }
        return windows.filter { (attribute($0, kAXRoleAttribute) as? String) == kAXWindowRole }
    }

    static func frame(of win: AXUIElement) -> CGRect? {
        guard let posVal = attribute(win, kAXPositionAttribute),
              let sizeVal = attribute(win, kAXSizeAttribute) else { return nil }
        var pos = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(posVal as! AXValue, .cgPoint, &pos),
              AXValueGetValue(sizeVal as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: pos, size: size)
    }

    static func isMinimized(_ win: AXUIElement) -> Bool {
        (attribute(win, kAXMinimizedAttribute) as? Bool) ?? false
    }

    static func title(of win: AXUIElement) -> String {
        (attribute(win, kAXTitleAttribute) as? String) ?? ""
    }

    static func focusedWindow(of app: NSRunningApplication) -> AXUIElement? {
        let pid = app.processIdentifier
        if let focused = attribute(application(pid), kAXFocusedWindowAttribute),
           CFGetTypeID(focused) == AXUIElementGetTypeID() {
            return (focused as! AXUIElement)
        }
        return windows(of: pid).first { !isMinimized($0) }
    }

    /// The window under a point in AX space, or nil over the desktop. Walks up
    /// from whatever element is there — a button, a text field — to the window
    /// containing it.
    static func window(at point: CGPoint) -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, timeout)
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &element) == .success,
              var current = element else { return nil }
        // Ten levels is deeper than any real view hierarchy needs; the bound is
        // there because a malformed AX tree can contain a cycle.
        for _ in 0..<10 {
            if (attribute(current, kAXRoleAttribute) as? String) == kAXWindowRole { return current }
            guard let parent = attribute(current, kAXParentAttribute),
                  CFGetTypeID(parent) == AXUIElementGetTypeID() else { return nil }
            current = (parent as! AXUIElement)
        }
        return nil
    }

    static func app(ofWindow win: AXUIElement) -> NSRunningApplication? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(win, &pid) == .success else { return nil }
        return NSRunningApplication(processIdentifier: pid)
    }

    static func setMinimized(_ minimized: Bool, of win: AXUIElement) {
        AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString,
                                     minimized ? kCFBooleanTrue : kCFBooleanFalse)
    }

    /// Brings a window to the front of its own app. Making it main as well is
    /// what tells the app which of its windows the user meant.
    static func raise(_ win: AXUIElement) {
        AXUIElementPerformAction(win, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(win, kAXMainAttribute as CFString, kCFBooleanTrue)
    }

    /// False when the app refused the move, the resize, or both.
    static func setFrame(_ rect: CGRect, of win: AXUIElement) -> Bool {
        var pos = rect.origin
        var size = rect.size
        guard let posVal = AXValueCreate(.cgPoint, &pos),
              let sizeVal = AXValueCreate(.cgSize, &size) else { return false }
        // Position → size → position again: some apps clamp one against the other.
        let movedTo = AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, posVal)
        let resized = AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, sizeVal)
        AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, posVal)
        return movedTo == .success && resized == .success
    }
}
