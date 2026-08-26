import AppKit

// Screen indices shift whenever a display is unplugged or rearranged, so
// anything persisted is keyed by the display's UUID. The index is still
// accepted as a fallback key for configs written before that.

enum ScreenIdentity {

    static func uuid(forIndex index: Int) -> String? {
        let screens = NSScreen.screens
        guard screens.indices.contains(index),
              let number = screens[index].deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(CGDirectDisplayID(number.uint32Value))?.takeRetainedValue()
        else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }

    /// Lookup keys for a screen, most stable first.
    static func keys(forIndex index: Int) -> [String] {
        guard let uuid = uuid(forIndex: index) else { return [String(index)] }
        return [uuid, String(index)]
    }

    /// The screen the pointer is on, falling back to the first one: a shortcut
    /// with no window to read a screen from acts on the one being looked at.
    static var indexUnderCursor: Int {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.firstIndex { $0.frame.contains(point) } ?? 0
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
