import AppKit
import Testing
@testable import plonk

@MainActor
struct ShotEditorDragInputTests {
    @Test func theCanvasReceivesShiftChangesAsFirstResponderDuringADrag() throws {
        _ = NSApplication.shared
        var startPoint: CGPoint?
        var dragPoint: CGPoint?
        var endPoint: CGPoint?
        var shiftChanges: [Bool] = []
        let input = ShotEditorDragInput.InputView(.init(
            onDrag: { start, point, _ in
                startPoint = start
                dragPoint = point
            },
            onEnd: { point, _ in endPoint = point },
            onShiftChange: { shiftChanges.append($0) }
        ))
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 300, height: 200),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = input

        func mouse(_ type: NSEvent.EventType, x: CGFloat, y: CGFloat) throws -> NSEvent {
            try #require(NSEvent.mouseEvent(with: type, location: CGPoint(x: x, y: y), modifierFlags: [],
                                             timestamp: 0, windowNumber: window.windowNumber, context: nil,
                                             eventNumber: 0, clickCount: 1, pressure: 1))
        }
        func shift(_ flags: NSEvent.ModifierFlags) throws -> NSEvent {
            try #require(NSEvent.keyEvent(with: .flagsChanged, location: .zero, modifierFlags: flags,
                                            timestamp: 0, windowNumber: window.windowNumber, context: nil,
                                            characters: "", charactersIgnoringModifiers: "", isARepeat: false,
                                            keyCode: 56))
        }

        input.mouseDown(with: try mouse(.leftMouseDown, x: 30, y: 160))
        #expect(window.firstResponder === input)
        input.mouseDragged(with: try mouse(.leftMouseDragged, x: 90, y: 140))
        window.sendEvent(try shift(.shift))
        window.sendEvent(try shift([]))
        #expect(shiftChanges == [true, false])
        #expect(startPoint == CGPoint(x: 30, y: 40))
        #expect(dragPoint == CGPoint(x: 90, y: 60))

        input.mouseUp(with: try mouse(.leftMouseUp, x: 90, y: 140))
        window.sendEvent(try shift(.shift))
        #expect(endPoint == dragPoint)
        #expect(shiftChanges == [true, false])
    }
}
