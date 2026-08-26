import CoreGraphics
import Foundation
import Testing
@testable import plonk

/// A shake is a wiggle: quick, wide, and back and forth. Anything less is a
/// hand that is not steady, and must not bring the zones up.
struct ShakeDetectorTests {

    /// Feeds a path of x positions at even intervals and says whether the
    /// last sample completed a shake.
    private func shakes(_ xs: [CGFloat], every step: TimeInterval = 0.05) -> Bool {
        var detector = ShakeDetector()
        var fired = false
        for (index, x) in xs.enumerated() {
            fired = detector.feed(x: x, at: Double(index) * step)
        }
        return fired
    }

    @Test func aQuickWiggleIsAShake() {
        // Right 60, left 60, right 60, left 60: three turns in 0.4s.
        #expect(shakes([0, 30, 60, 30, 0, 30, 60, 30, 0]))
    }

    @Test func aStraightDragIsNot() {
        #expect(!shakes([0, 20, 40, 60, 80, 100, 120, 140, 160]))
    }

    /// A hand that is not quite steady turns round by a few points; that
    /// is not a shake.
    @Test func smallJitterIsNot() {
        #expect(!shakes([0, 5, 0, 5, 0, 5, 0, 5, 0, 5, 0]))
    }

    @Test func aSlowWiggleIsNot() {
        // The same path as the shake, but a turn a second: too old by the third.
        #expect(!shakes([0, 30, 60, 30, 0, 30, 60, 30, 0], every: 0.5))
    }

    @Test func aResetForgetsTheWiggle() {
        var detector = ShakeDetector()
        for (index, x) in [CGFloat]([0, 60, 0, 60]).enumerated() {
            _ = detector.feed(x: x, at: Double(index) * 0.05)
        }
        detector.reset()
        let afterReset = detector.feed(x: 0, at: 0.25)
        let oneSwing = detector.feed(x: 60, at: 0.3)
        #expect(!afterReset && !oneSwing)
    }
}
