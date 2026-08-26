import CoreGraphics
import Foundation

// A window wiggled sideways while it is dragged: the gesture PowerToys and
// MacsyZones use to ask for the zones without a modifier. Fed the pointer's x
// on every drag event, and true once it has turned round often enough, far
// enough, recently enough to be a shake rather than a wobbly hand.

struct ShakeDetector {
    /// How many times the pointer has to change direction.
    static let reversals = 3
    /// How far a swing has to go, in points, for its end to count as a turn.
    static let minimumSwing: CGFloat = 40
    /// How recent the turns have to be, in seconds.
    static let window: TimeInterval = 0.7

    private var lastX: CGFloat?
    private var direction = 0
    private var swing: CGFloat = 0
    private var turns: [TimeInterval] = []

    /// True on the sample that completes a shake. Keep feeding it and it
    /// stays true for as long as the wiggle goes on.
    mutating func feed(x: CGFloat, at time: TimeInterval) -> Bool {
        defer { lastX = x }
        guard let lastX, x != lastX else { return isShaking(at: time) }
        let heading = x > lastX ? 1 : -1
        if heading == direction {
            swing += abs(x - lastX)
        } else {
            // A turn is the end of a swing long enough to have been meant.
            if direction != 0, swing >= Self.minimumSwing { turns.append(time) }
            direction = heading
            swing = abs(x - lastX)
        }
        return isShaking(at: time)
    }

    mutating func reset() {
        lastX = nil
        direction = 0
        swing = 0
        turns = []
    }

    private mutating func isShaking(at time: TimeInterval) -> Bool {
        turns.removeAll { time - $0 > Self.window }
        return turns.count >= Self.reversals
    }
}
