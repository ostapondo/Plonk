import AppKit

// Screen indices shift whenever a display is unplugged or rearranged, so
// anything persisted is keyed by the display's UUID. The index is still
// accepted as a fallback key for configs written before that.

enum ScreenIdentity {

    static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    static func uuid(forIndex index: Int) -> String? {
        let screens = NSScreen.screens
        guard screens.indices.contains(index),
              let id = displayID(for: screens[index]),
              let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue()
        else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }

    /// Lookup keys for a screen, most stable first.
    static func keys(forIndex index: Int) -> [String] {
        guard let uuid = uuid(forIndex: index) else { return [String(index)] }
        return [uuid, String(index)]
    }

    /// Storage keys only when the screen is attached now. Routes use this
    /// before persisting an index supplied by a client; `keys(forIndex:)`
    /// deliberately keeps accepting a bare legacy index while reading config.
    static func attachedKeys(forIndex index: Int) -> [String]? {
        guard let uuid = uuid(forIndex: index) else { return nil }
        return [uuid, String(index)]
    }

    /// The screen the pointer is on, falling back to the first one: a shortcut
    /// with no window to read a screen from acts on the one being looked at.
    static var indexUnderCursor: Int {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.firstIndex { contains($0, point) } ?? 0
    }

    static func screen(at point: CGPoint) -> NSScreen? {
        let screens = NSScreen.screens
        return screens.first { contains($0, point) } ?? screens.first
    }

    /// The pointer on a screen's top row reports y == frame.maxY, which `CGRect.contains`
    /// excludes; NSMouseInRect counts that row and leaves out the bottom one instead.
    private static func contains(_ screen: NSScreen, _ point: CGPoint) -> Bool {
        NSMouseInRect(point, screen.frame, false)
    }

    /// Every display attached now, by UUID: what a desk is keyed by.
    static func attachedDisplays() -> Set<String> {
        Set(NSScreen.screens.indices.compactMap(uuid(forIndex:)))
    }

    /// Where that display sits now, or nil when it is not attached.
    static func index(forUUID uuid: String) -> Int? {
        NSScreen.screens.indices.first { self.uuid(forIndex: $0) == uuid }
    }
}
