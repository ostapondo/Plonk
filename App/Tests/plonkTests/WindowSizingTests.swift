import CoreGraphics
import Testing
@testable import plonk

// AX space: origin top-left, y grows downward.

/// Larger and smaller: a step about the centre, held to the screen.
struct WindowSizingTests {

    private let visible = CGRect(x: 0, y: 25, width: 1000, height: 575)

    @Test func growsAboutTheCentre() {
        let grown = WindowSizing.resized(CGRect(x: 100, y: 100, width: 200, height: 200), by: 30, within: visible)
        #expect(grown == CGRect(x: 85, y: 85, width: 230, height: 230))
    }

    @Test func shrinksAboutTheCentre() {
        let shrunk = WindowSizing.resized(CGRect(x: 100, y: 100, width: 200, height: 200), by: -30, within: visible)
        #expect(shrunk == CGRect(x: 115, y: 115, width: 170, height: 170))
    }

    /// A window filling the left half grows to the right, not off the screen,
    /// and shrinks away from the edge it is on.
    @Test func aSideAgainstTheScreenEdgeStaysThere() {
        let leftHalf = CGRect(x: 0, y: 25, width: 500, height: 575)
        let grown = WindowSizing.resized(leftHalf, by: 30, within: visible)
        #expect(grown.minX == 0 && grown.width == 530)
        #expect(grown.minY == 25 && grown.height == 575)
        let shrunk = WindowSizing.resized(leftHalf, by: -30, within: visible)
        #expect(shrunk.minX == 0 && shrunk.width == 470)
        #expect(shrunk.minY == 25 && shrunk.maxY == 600)
    }

    /// A window filling the whole screen has nowhere to grow, and shrinks
    /// from every side since there is no edge to shrink away from.
    @Test func aWindowFillingTheScreenOnlyShrinksAndDoesSoFromEverySide() {
        let full = visible
        #expect(WindowSizing.resized(full, by: 30, within: visible) == full)
        let shrunk = WindowSizing.resized(full, by: -30, within: visible)
        #expect(shrunk == full.insetBy(dx: 15, dy: 15))
    }

    @Test func neverLeavesTheScreen() {
        let grown = WindowSizing.resized(CGRect(x: 790, y: 390, width: 200, height: 200), by: 30, within: visible)
        #expect(visible.contains(grown))
    }

    @Test func shrinkingStopsAtATitleBar() {
        let small = CGRect(x: 100, y: 100, width: 130, height: 130)
        #expect(WindowSizing.resized(small, by: -30, within: visible) == small)
    }
}

/// The widths a half steps through when its key is pressed again.
struct PresetCycleTests {

    @Test func aHalfPressedAgainTakesTwoThirdsThenAThirdThenTheHalf() {
        let half = Preset.leftHalf
        let twoThirds = half.next(after: half.frac)
        #expect(abs(twoThirds.w - 2.0 / 3.0) < 0.001 && twoThirds.x == 0)
        let third = half.next(after: twoThirds)
        #expect(abs(third.w - 1.0 / 3.0) < 0.001 && third.x == 0)
        let back = half.next(after: third)
        #expect(back.w == 0.5)
    }

    @Test func theRightAndBottomHalvesKeepToTheirSide() {
        let right = Preset.rightHalf.next(after: Preset.rightHalf.frac)
        #expect(abs(right.x - 1.0 / 3.0) < 0.001 && abs(right.w - 2.0 / 3.0) < 0.001)
        let bottom = Preset.bottomHalf.next(after: Preset.bottomHalf.frac)
        #expect(abs(bottom.y - 1.0 / 3.0) < 0.001 && abs(bottom.h - 2.0 / 3.0) < 0.001)
    }

    /// A window anywhere else, or one nothing is known about, gets the half.
    @Test func aWindowNotOnTheCycleGetsTheHalf() {
        #expect(Preset.leftHalf.next(after: FracRect(0.2, 0.1, 0.6, 0.8)).w == 0.5)
        #expect(Preset.leftHalf.next(after: nil).w == 0.5)
        #expect(Preset.leftHalf.next(after: Preset.rightHalf.frac).x == 0)
    }

    /// A terminal sized to its character grid sits a few points off the half
    /// and still counts as being in it.
    @Test func aWindowAFewPointsOffStillCounts() {
        let nearly = FracRect(0, 0, 0.49, 0.99)
        #expect(abs(Preset.leftHalf.next(after: nearly).w - 2.0 / 3.0) < 0.001)
    }

    @Test func onlyHalvesCycle() {
        #expect(Preset.topLeft.next(after: Preset.topLeft.frac).w == 0.5)
        #expect(Preset.maximize.next(after: Preset.maximize.frac).w == 1)
    }
}

/// Which display is next.
struct DisplayOrderTests {

    @Test func displaysGoLeftToRightThenTopToBottom() {
        let frames = [
            CGRect(x: 0, y: 0, width: 1000, height: 600),
            CGRect(x: -1200, y: 0, width: 1200, height: 800),
            CGRect(x: 0, y: -900, width: 1000, height: 900),
        ]
        #expect(WindowNavigator.displayOrder(frames) == [1, 2, 0])
    }
}
