import SwiftUI

// A right-click, which SwiftUI on macOS 13 cannot report without attaching a
// context menu to the view.
//
// The catcher is laid over the thing that wants the click and is invisible to
// everything else: `hitTest` answers only while a right-button event is the one
// being routed, so the left-button gestures underneath still receive every
// event they used to.

struct RightClickCatcher: NSViewRepresentable {
    /// Where the click landed, in the overlaid view's own coordinates: top-left
    /// origin, the way SwiftUI counts.
    let onClick: (CGPoint) -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.onClick = onClick
        return view
    }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.onClick = onClick
    }

    final class CatcherView: NSView {
        var onClick: ((CGPoint) -> Void)?

        /// Matches SwiftUI, so a converted point needs no flipping.
        override var isFlipped: Bool { true }

        override func hitTest(_ point: NSPoint) -> NSView? {
            switch NSApp.currentEvent?.type {
            case .rightMouseDown, .rightMouseUp, .rightMouseDragged:
                return super.hitTest(point)
            default:
                return nil
            }
        }

        override func rightMouseDown(with event: NSEvent) {
            onClick?(convert(event.locationInWindow, from: nil))
        }

        /// Swallowed rather than passed on: the down has already acted, and the
        /// default would look for a context menu that is not there.
        override func rightMouseUp(with event: NSEvent) {}
    }
}
