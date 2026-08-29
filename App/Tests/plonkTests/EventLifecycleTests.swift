import AppKit
import Testing
@testable import plonk

private final class FakeEventTap: EventTapToken {}

struct EventLifecycleTests {
    @Test @MainActor func mouseTapListensOnlyToEventsItsEnabledToolsNeed() {
        var masks: [CGEventMask] = []
        let mouse = MouseTools(tapFactory: { mask, _, _, _ in
            masks.append(mask)
            return FakeEventTap()
        }, isTrusted: { true })
        var config = Config()
        config.highlightClicksEnabled = true
        mouse.apply(config)
        #expect(masks.count == 1)
        #expect(masks[0] & (1 << CGEventType.leftMouseDown.rawValue) != 0)
        #expect(masks[0] & (1 << CGEventType.mouseMoved.rawValue) == 0)

        config.crosshairsEnabled = true
        mouse.apply(config)
        #expect(masks.count == 2)
        #expect(masks[1] & (1 << CGEventType.mouseMoved.rawValue) != 0)

        config.highlightClicksEnabled = false
        config.crosshairsEnabled = false
        mouse.apply(config)
        mouse.stop()
    }

    @Test func dragMonitorsStartOnceAndAreRemovedWhenDisabled() {
        var added = 0
        var removed = 0
        let manager = DragSnapManager(
            windows: WindowManager(),
            addMonitor: { _, _ in
                added += 1
                return NSObject()
            },
            removeMonitor: { _ in removed += 1 }
        )
        var config = Config()
        manager.apply(config)
        manager.start()
        #expect(added == 2)
        config.dragSnapEnabled = false
        manager.apply(config)
        #expect(removed == 2)
    }
}
