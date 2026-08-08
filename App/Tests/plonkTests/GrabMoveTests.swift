import CoreGraphics
import Testing
@testable import plonk

// AX space: origin top-left, y grows downward, so "top" is the smaller y.

private let frame = CGRect(x: 100, y: 100, width: 400, height: 300)

struct GrabMoveHandleTests {

    @Test func aDragNearTheLeftEdgeTakesTheLeftEdge() {
        let handle = GrabMove.handle(for: CGPoint(x: 110, y: 250), in: frame)
        #expect(handle.left && !handle.right && !handle.top && !handle.bottom)
    }

    @Test func aDragInACornerTakesBothItsEdges() {
        let handle = GrabMove.handle(for: CGPoint(x: 110, y: 110), in: frame)
        #expect(handle.left && handle.top)
        #expect(!handle.right && !handle.bottom)
    }

    @Test func aDragNearTheBottomRightTakesThatCorner() {
        let handle = GrabMove.handle(for: CGPoint(x: 490, y: 390), in: frame)
        #expect(handle.right && handle.bottom)
    }

    /// Dead centre still resizes, from whichever side is nearer, so a drag in
    /// the middle of a window is never a silent no-op.
    @Test func theMiddleFallsBackToTheNearestSide() {
        let handle = GrabMove.handle(for: CGPoint(x: 300, y: 250), in: frame)
        #expect(!handle.isEmpty)
        // 300 is dead centre horizontally, 250 dead centre vertically; the
        // window is wider than it is tall, so the vertical edges are nearer.
        #expect(handle.top || handle.bottom)
    }

    @Test func aZeroSizedWindowHasNoHandles() {
        #expect(GrabMove.handle(for: .zero, in: .zero).isEmpty)
    }

    // MARK: - resizing

    @Test func pullingTheRightEdgeOnlyChangesTheWidth() {
        let result = GrabMove.resized(frame, by: CGVector(dx: 50, dy: 0),
                                      pulling: GrabMove.Handle(right: true))
        #expect(result == CGRect(x: 100, y: 100, width: 450, height: 300))
    }

    @Test func pullingTheLeftEdgeMovesTheOriginToo() {
        let result = GrabMove.resized(frame, by: CGVector(dx: -50, dy: 0),
                                      pulling: GrabMove.Handle(left: true))
        #expect(result == CGRect(x: 50, y: 100, width: 450, height: 300))
    }

    @Test func pullingACornerChangesBothAxes() {
        let result = GrabMove.resized(frame, by: CGVector(dx: -20, dy: -30),
                                      pulling: GrabMove.Handle(left: true, top: true))
        #expect(result == CGRect(x: 80, y: 70, width: 420, height: 330))
    }

    /// Dragging the right edge past the left one must not turn the window
    /// inside out, and dragging the left edge past the right must not either.
    @Test func aWindowNeverCollapsesBelowTheMinimum() {
        let shrunkRight = GrabMove.resized(frame, by: CGVector(dx: -1000, dy: -1000),
                                           pulling: GrabMove.Handle(right: true, bottom: true))
        #expect(shrunkRight.width >= 80 && shrunkRight.height >= 80)

        let shrunkLeft = GrabMove.resized(frame, by: CGVector(dx: 1000, dy: 1000),
                                          pulling: GrabMove.Handle(left: true, top: true))
        #expect(shrunkLeft.width >= 80 && shrunkLeft.height >= 80)
        // Pulled from the left, the right edge stays put.
        #expect(abs(shrunkLeft.maxX - frame.maxX) < 0.001)
        #expect(abs(shrunkLeft.maxY - frame.maxY) < 0.001)
    }

    @Test func noHandleLeavesTheFrameAlone() {
        #expect(GrabMove.resized(frame, by: CGVector(dx: 40, dy: 40), pulling: GrabMove.Handle()) == frame)
    }
}

struct ZoneGapTests {

    @Test func aGapShrinksTheRectOnEverySide() {
        let inset = WindowManager.inset(CGRect(x: 0, y: 0, width: 800, height: 600), by: 10)
        #expect(inset == CGRect(x: 10, y: 10, width: 780, height: 580))
    }

    @Test func noGapChangesNothing() {
        let rect = CGRect(x: 0, y: 0, width: 800, height: 600)
        #expect(WindowManager.inset(rect, by: 0) == rect)
    }

    /// A wide gap on a narrow zone would otherwise produce a null rect, and a
    /// window set to a null rect goes to an infinite origin.
    @Test func aGapWiderThanTheZoneIsClampedRatherThanInverting() {
        let narrow = CGRect(x: 0, y: 0, width: 130, height: 130)
        let inset = WindowManager.inset(narrow, by: 40)
        #expect(inset.width > 0 && inset.height > 0)
        #expect(!inset.isNull && !inset.isInfinite)
        #expect(inset.width <= narrow.width && inset.height <= narrow.height)
    }

    @Test func aZoneAtTheMinimumIsLeftAlone() {
        let tiny = CGRect(x: 0, y: 0, width: 100, height: 90)
        #expect(WindowManager.inset(tiny, by: 40) == tiny)
    }
}
