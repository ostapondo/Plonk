import CoreGraphics
import Testing
@testable import plonk

/// The order a new window's placement is decided in: a rule, then the habit,
/// then an empty zone, with every fall-through the docs promise.
struct NewWindowPlacementTests {

    private let halves = [ZoneRect(0, 0, 0.5, 1), ZoneRect(0.5, 0, 0.5, 1)]
    private let thirds = [ZoneRect(0, 0, 1.0 / 3, 1), ZoneRect(1.0 / 3, 0, 1.0 / 3, 1), ZoneRect(2.0 / 3, 0, 1.0 / 3, 1)]
    private let habit = NewWindowPlacement.Habit(frac: FracRect(0.5, 0, 0.5, 1), screenUUID: "A", zoneIndex: 1)

    /// Screen 0 is display A wearing Halves, screen 1 is display B wearing
    /// Thirds, and zone 1 on the screen a window opens on is empty.
    private func desk(rules: [AppRule] = [], habit on: Bool = false, fill: Bool = false,
                      firstEmpty: Int? = 0) -> NewWindowPlacement {
        NewWindowPlacement(
            rules: rules, placeNewWindows: on, autoFillZones: fill,
            screenIndex: { ["A": 0, "B": 1][$0] },
            zones: { [self.halves, self.thirds][$0] },
            firstEmpty: { _ in firstEmpty }
        )
    }

    @Test func aRuleBeatsTheHabitAndTheEmptyZone() {
        let placement = desk(rules: [AppRule(app: "com.apple.Safari", zone: 3, screenUUID: "B")], habit: true, fill: true)
        let answer = placement.decide(name: "Safari", bundleID: "com.apple.Safari", habit: habit, openedOn: 0)
        #expect(answer == NewWindowPlacement.Answer(frac: thirds[2].frac, screen: 1, zoneIndex: 2))
    }

    @Test func aRuleForADisplayThatIsAwayUsesTheScreenTheWindowOpenedOn() {
        let placement = desk(rules: [AppRule(app: "com.apple.Safari", zone: 2, screenUUID: "gone")])
        let answer = placement.decide(name: "Safari", bundleID: "com.apple.Safari", habit: nil, openedOn: 0)
        #expect(answer == NewWindowPlacement.Answer(frac: halves[1].frac, screen: 0, zoneIndex: 1))
    }

    /// A rule for zone 3 on a screen wearing Halves is left unfollowed, and
    /// the habit gets its turn.
    @Test func aRuleForAZoneTheSetLacksFallsThroughToTheHabit() {
        let placement = desk(rules: [AppRule(app: "com.apple.Safari", zone: 3)], habit: true)
        let answer = placement.decide(name: "Safari", bundleID: "com.apple.Safari", habit: habit, openedOn: 0)
        #expect(answer == NewWindowPlacement.Answer(frac: halves[1].frac, screen: 0, zoneIndex: 1))
    }

    @Test func theHabitFollowsTheZoneNumberAndNeedsItsSwitch() {
        #expect(desk(habit: true).decide(name: "Safari", bundleID: "com.apple.Safari", habit: habit, openedOn: 0)
                == NewWindowPlacement.Answer(frac: halves[1].frac, screen: 0, zoneIndex: 1))
        #expect(desk(habit: false).decide(name: "Safari", bundleID: "com.apple.Safari", habit: habit, openedOn: 0) == nil)
    }

    @Test func aHabitOnADisplayThatIsAwayFallsThroughToTheEmptyZone() {
        let away = NewWindowPlacement.Habit(frac: FracRect(0, 0, 0.5, 1), screenUUID: "gone", zoneIndex: 0)
        let placement = desk(habit: true, fill: true, firstEmpty: 1)
        let answer = placement.decide(name: "Safari", bundleID: "com.apple.Safari", habit: away, openedOn: 0)
        #expect(answer == NewWindowPlacement.Answer(frac: halves[1].frac, screen: 0, zoneIndex: 1))
    }

    @Test func theEmptyZoneIsLastAndOnlyWhenSwitchedOn() {
        #expect(desk(fill: true).decide(name: "Safari", bundleID: nil, habit: nil, openedOn: 0)
                == NewWindowPlacement.Answer(frac: halves[0].frac, screen: 0, zoneIndex: 0))
        #expect(desk(fill: true, firstEmpty: nil).decide(name: "Safari", bundleID: nil, habit: nil, openedOn: 0) == nil)
        #expect(desk(fill: false).decide(name: "Safari", bundleID: nil, habit: nil, openedOn: 0) == nil)
    }

    /// The cheap question before any window is asked about: whether any of
    /// the three has anything to say about this app at all.
    @Test func anAppNobodyHasARuleOrHabitForCostsNothing() {
        let slack = desk(rules: [AppRule(app: "com.tinyspeck.slackmacgap", zone: 1)], habit: true)
        #expect(slack.wants(name: "Slack", bundleID: "com.tinyspeck.slackmacgap", hasHabit: false))
        #expect(!slack.wants(name: "Safari", bundleID: "com.apple.Safari", hasHabit: false))
        #expect(slack.wants(name: "Safari", bundleID: "com.apple.Safari", hasHabit: true))
        #expect(desk(fill: true).wants(name: "Safari", bundleID: nil, hasHabit: false))
    }
}
