import CoreGraphics
import Foundation
import Testing
@testable import plonk

// How a measurement is written down, and how it crosses into the API.

struct RulerMeasurementTests {

    private let visible = CGRect(x: 0, y: 25, width: 1440, height: 875)

    @Test func aBoxOnARetinaScreenSaysBothNumbers() {
        let measurement = RulerMeasurement(kind: .bounds, screen: 0,
                                           rect: CGRect(x: 100, y: 200, width: 412, height: 96),
                                           scale: 2)
        #expect(measurement.label == "412 × 96 pt\n824 × 192 px")
        #expect(measurement.clipboardText == "412 × 96")
    }

    /// On a screen where a point is a pixel, saying it twice is noise.
    @Test func aBoxOnAPlainScreenSaysOne() {
        let measurement = RulerMeasurement(kind: .bounds, screen: 0,
                                           rect: CGRect(x: 0, y: 0, width: 200, height: 50),
                                           scale: 1)
        #expect(measurement.label == "200 × 50 pt")
    }

    @Test func aLineReportsItsLengthAndItsSides() {
        let measurement = RulerMeasurement(kind: .line, screen: 0,
                                           rect: CGRect(x: 10, y: 20, width: 30, height: 40),
                                           scale: 1,
                                           from: CGPoint(x: 10, y: 20), to: CGPoint(x: 40, y: 60))
        #expect(measurement.distance == 50)
        #expect(measurement.label == "50 pt\ndx 30 · dy 40")
        #expect(measurement.clipboardText == "50")
    }

    @Test func aBoxHasNoDistance() {
        let measurement = RulerMeasurement(kind: .bounds, screen: 1,
                                           rect: CGRect(x: 0, y: 0, width: 10, height: 10), scale: 1)
        #expect(measurement.distance == nil)
    }

    /// Everything crossing [String: Any] has to be a Double on the way out:
    /// CGFloat is its own type and reads back as nil.
    @Test func theApiPayloadIsDoublesAllTheWayDown() {
        let measurement = RulerMeasurement(kind: .bounds, screen: 2,
                                           rect: CGRect(x: 144, y: 112.5, width: 720, height: 175),
                                           scale: 2)
        let payload = measurement.asDict(visible: visible)

        #expect(payload["kind"] as? String == "bounds")
        #expect(payload["screen"] as? Int == 2)
        #expect((payload["points"] as? [String: Double])?["w"] == 720)
        #expect((payload["pixels"] as? [String: Double])?["h"] == 350)
        #expect(payload["scale"] as? Double == 2)

        let fraction = payload["fraction"] as? [String: Double]
        #expect(fraction?["x"] == 0.1)
        #expect(fraction?["y"] == 0.1)
        #expect(fraction?["w"] == 0.5)
        #expect(fraction?["h"] == 0.2)
    }

    /// A point in the menu bar is measurable and is not inside the visible
    /// area, so its fraction is allowed to be negative rather than clamped
    /// into a lie.
    @Test func somethingAboveTheVisibleAreaKeepsItsSign() {
        let measurement = RulerMeasurement(kind: .bounds, screen: 0,
                                           rect: CGRect(x: 0, y: 0, width: 100, height: 20), scale: 1)
        let fraction = measurement.asDict(visible: visible)["fraction"] as? [String: Double]
        #expect((fraction?["y"] ?? 0) < 0)
    }

    @Test func aScreenWithNoVisibleAreaGetsNoFraction() {
        let measurement = RulerMeasurement(kind: .bounds, screen: 0,
                                           rect: CGRect(x: 0, y: 0, width: 10, height: 10), scale: 1)
        #expect(measurement.asDict(visible: .zero)["fraction"] == nil)
    }
}

struct RulerRouteTests {

    private let visible = CGRect(x: 100, y: 25, width: 1000, height: 800)

    @Test func aFractionLandsInTheVisibleArea() {
        let point = RulerRoutes.point(["x": 0.5, "y": 0.25], in: visible)
        #expect(point == CGPoint(x: 600, y: 225))
    }

    @Test func theCornersAreInside() {
        #expect(RulerRoutes.point(["x": 0, "y": 0], in: visible) == CGPoint(x: 100, y: 25))
        #expect(RulerRoutes.point(["x": 1, "y": 1], in: visible) == CGPoint(x: 1100, y: 825))
    }

    @Test func anythingThatIsNotAPairOfFractionsIsRefused() {
        #expect(RulerRoutes.point(nil, in: visible) == nil)
        #expect(RulerRoutes.point(["x": 0.5], in: visible) == nil)
        #expect(RulerRoutes.point(["x": 1.5, "y": 0.5], in: visible) == nil)
        #expect(RulerRoutes.point(["x": -0.1, "y": 0.5], in: visible) == nil)
        #expect(RulerRoutes.point(["x": Double.nan, "y": 0.5], in: visible) == nil)
        #expect(RulerRoutes.point(["x": "half", "y": 0.5], in: visible) == nil)
    }
}
