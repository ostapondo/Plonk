import AppKit
import ApplicationServices

// The Accessibility layer: reading and writing the windows of another app.
//
// Every call here is synchronous IPC into that app, which is why the timeout
// in WindowManager matters and why nothing on this side caches. The rest of
// WindowManager decides where a window goes; this is how it gets there.
//
// None of it is private only because the type is split across two files, and
// Swift lets an extension see a private member only in the file that declared
// it. Nothing outside WindowManager should be calling any of this.

extension WindowManager {
    var isTrusted: Bool { AXIsProcessTrusted() }

    func promptForTrust() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }

    func appElement(_ pid: pid_t) -> AXUIElement {
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, Self.axTimeout)
        return element
    }

    func axWindows(of pid: pid_t) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement(pid), kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return [] }
        return windows.filter { (attr($0, kAXRoleAttribute) as? String) == kAXWindowRole }
    }

    func attr(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, name as CFString, &value) == .success else { return nil }
        return value
    }

    func frame(ofWindow win: AXUIElement) -> CGRect? {
        guard let posVal = attr(win, kAXPositionAttribute), let sizeVal = attr(win, kAXSizeAttribute) else { return nil }
        var pos = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(posVal as! AXValue, .cgPoint, &pos),
              AXValueGetValue(sizeVal as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: pos, size: size)
    }

    func focusedWindow(of app: NSRunningApplication) -> AXUIElement? {
        let pid = app.processIdentifier
        if let focused = attr(appElement(pid), kAXFocusedWindowAttribute),
           CFGetTypeID(focused) == AXUIElementGetTypeID() {
            return (focused as! AXUIElement)
        }
        return axWindows(of: pid).first { !isMinimized($0) }
    }

    func isMinimized(_ win: AXUIElement) -> Bool {
        (attr(win, kAXMinimizedAttribute) as? Bool) ?? false
    }

    func title(of win: AXUIElement) -> String {
        (attr(win, kAXTitleAttribute) as? String) ?? ""
    }

    /// The window under a point in AX space, or nil over the desktop. Walks up
    /// from whatever element is there — a button, a text field — to the window
    /// containing it.
    func window(at point: CGPoint) -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, Self.axTimeout)
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &element) == .success,
              var current = element else { return nil }
        // Ten levels is deeper than any real view hierarchy needs; the bound is
        // there because a malformed AX tree can contain a cycle.
        for _ in 0..<10 {
            if (attr(current, kAXRoleAttribute) as? String) == kAXWindowRole { return current }
            guard let parent = attr(current, kAXParentAttribute),
                  CFGetTypeID(parent) == AXUIElementGetTypeID() else { return nil }
            current = (parent as! AXUIElement)
        }
        return nil
    }

    func app(ofWindow win: AXUIElement) -> NSRunningApplication? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(win, &pid) == .success else { return nil }
        return NSRunningApplication(processIdentifier: pid)
    }

    /// Placement during a live drag. Announces nothing: the change bus would
    /// otherwise fire on every mouse event, and the drop announces once.
    func setFrame(_ rect: CGRect, ofWindow win: AXUIElement) {
        setFrame(win, rect, announce: false)
    }

    @discardableResult
    func setFrame(_ win: AXUIElement, _ rect: CGRect, announce: Bool = true) -> Bool {
        var pos = rect.origin
        var size = rect.size
        guard let posVal = AXValueCreate(.cgPoint, &pos),
              let sizeVal = AXValueCreate(.cgSize, &size) else { return false }
        // Position → size → position again: some apps clamp one against the other.
        let movedTo = AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, posVal)
        let resized = AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, sizeVal)
        AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, posVal)
        guard movedTo == .success && resized == .success else { return false }
        // Placement reaches here from hotkeys, drag snapping, workspace
        // launches and the HTTP routes alike, so this is the one place that
        // sees every window move. Launches run off the main queue.
        if announce, let onDidPlace {
            DispatchQueue.main.async(execute: onDidPlace)
        }
        return true
    }
}
