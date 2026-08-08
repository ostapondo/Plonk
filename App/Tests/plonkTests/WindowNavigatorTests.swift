import CoreGraphics
import Testing
@testable import plonk

// AX space: origin top-left, y grows downward.

struct WindowNavigatorTests {

    private let left = CGRect(x: 0, y: 0, width: 400, height: 800)
    private let right = CGRect(x: 400, y: 0, width: 400, height: 800)
    private let below = CGRect(x: 0, y: 800, width: 400, height: 200)

    // MARK: - directional focus

    @Test func stepsToTheWindowInThatDirection() {
        #expect(WindowNavigator.target(from: left, candidates: [right, below], direction: .right) == 0)
        #expect(WindowNavigator.target(from: left, candidates: [right, below], direction: .down) == 1)
    }

    @Test func nothingLiesThatWay() {
        #expect(WindowNavigator.target(from: left, candidates: [right], direction: .left) == nil)
        #expect(WindowNavigator.target(from: left, candidates: [right], direction: .up) == nil)
    }

    /// Straight ahead beats nearer but off to the side, which is what makes
    /// stepping right twice come back to where it started.
    @Test func prefersTheWindowStraightAhead() {
        let origin = CGRect(x: 0, y: 400, width: 200, height: 200)
        let ahead = CGRect(x: 400, y: 400, width: 200, height: 200)
        let offAxis = CGRect(x: 300, y: 0, width: 200, height: 200)
        #expect(WindowNavigator.target(from: origin, candidates: [offAxis, ahead], direction: .right) == 1)
    }

    @Test func aWindowStackedOnTheOriginIsNotAStep() {
        #expect(WindowNavigator.target(from: left, candidates: [left], direction: .right) == nil)
    }

    @Test func noCandidatesIsNotACrash() {
        #expect(WindowNavigator.target(from: left, candidates: [], direction: .down) == nil)
    }

    // MARK: - cycling within a zone

    private let zone = CGRect(x: 0, y: 0, width: 400, height: 800)

    @Test func cyclesThroughTheWindowsInTheZone() {
        let stacked = [left, CGRect(x: 10, y: 10, width: 380, height: 780), right]
        #expect(WindowNavigator.nextInZone(after: 0, candidates: stacked, zone: zone) == 1)
        #expect(WindowNavigator.nextInZone(after: 1, candidates: stacked, zone: zone) == 0)
    }

    @Test func cyclesBackwards() {
        let stacked = [left, CGRect(x: 10, y: 10, width: 380, height: 780), right]
        #expect(WindowNavigator.nextInZone(after: 0, candidates: stacked, zone: zone, backwards: true) == 1)
    }

    @Test func aZoneHoldingOneWindowHasNothingToCycle() {
        #expect(WindowNavigator.nextInZone(after: 0, candidates: [left, right], zone: zone) == nil)
    }

    /// Focus can sit on a window outside the zone — a palette, say. Cycling
    /// then means "start at the top of that zone" rather than doing nothing.
    @Test func startsSomewhereWhenTheCurrentWindowIsOutsideTheZone() {
        let stacked = [right, left, CGRect(x: 10, y: 10, width: 380, height: 780)]
        #expect(WindowNavigator.nextInZone(after: 0, candidates: stacked, zone: zone) == 1)
    }

    // MARK: - clamping a restored frame

    @Test func aFrameAlreadyOnScreenIsUntouched() {
        let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let frame = CGRect(x: 100, y: 100, width: 300, height: 300)
        #expect(WindowNavigator.clamped(frame, into: visible) == frame)
    }

    @Test func aFrameOffTheEdgeIsPulledBackIn() {
        let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let clamped = WindowNavigator.clamped(CGRect(x: 1800, y: 900, width: 300, height: 300), into: visible)
        #expect(clamped == CGRect(x: 700, y: 500, width: 300, height: 300))
    }

    @Test func aFrameLargerThanTheScreenIsCutDownToIt() {
        let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let clamped = WindowNavigator.clamped(CGRect(x: -200, y: -200, width: 2000, height: 2000), into: visible)
        #expect(clamped == visible)
    }

    @Test func anEmptyScreenLeavesTheFrameAlone() {
        let frame = CGRect(x: 10, y: 10, width: 100, height: 100)
        #expect(WindowNavigator.clamped(frame, into: .zero) == frame)
    }
}
