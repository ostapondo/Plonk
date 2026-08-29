import AppKit

typealias EventTapHandler = (CGEventType, CGEvent) -> Unmanaged<CGEvent>?

protocol EventTapToken: AnyObject {}

/// A CGEvent tap on the main run loop, with the one piece of upkeep every tap
/// needs: the system disables a tap that ever takes too long, and turning it
/// back on is the documented recovery. Losing it silently would strand every
/// event after, so that lives here rather than in each owner. The tap is torn
/// down when this is released.
final class EventTap: EventTapToken {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let handler: EventTapHandler

    /// nil when the tap cannot be created, which is what happens without
    /// Accessibility. `handler` returns nil to swallow an event; a listen-only
    /// tap's return value is ignored.
    init?(
        mask: CGEventMask, options: CGEventTapOptions, name: String,
        handler: @escaping EventTapHandler
    ) {
        self.handler = handler
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: options,
            eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                return Unmanaged<EventTap>.fromOpaque(context).takeUnretainedValue().handle(type, event)
            },
            userInfo: context
        ) else {
            NSLog("Plonk: could not create the \(name) event tap")
            return nil
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        runLoopSource = source
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    deinit {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        return handler(type, event)
    }
}
