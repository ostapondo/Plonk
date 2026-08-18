import Foundation
import Testing
@testable import plonk

// "Keep awake until 17:00" is parsed here; the clock and calendar are injected
// so the tests do not depend on when they run or where they run.

struct DeadlineTests {

    @Test func aTimeStillAheadIsToday() {
        let parsed = Router.parseDeadline("17:00", now: at("2026-08-08T09:30:00Z"), calendar: utc)
        #expect(parsed == at("2026-08-08T17:00:00Z"))
    }

    /// Asking at half past five for "17:00" means tomorrow, the same way an
    /// alarm does. Otherwise the session would end before it began.
    @Test func aTimeAlreadyPastIsTomorrow() {
        let parsed = Router.parseDeadline("17:00", now: at("2026-08-08T17:30:00Z"), calendar: utc)
        #expect(parsed == at("2026-08-09T17:00:00Z"))
    }

    @Test func secondsAreAccepted() {
        let parsed = Router.parseDeadline("08:15:30", now: at("2026-08-08T07:00:00Z"), calendar: utc)
        #expect(parsed == at("2026-08-08T08:15:30Z"))
    }

    @Test func anIsoTimestampIsTakenAsWritten() {
        let parsed = Router.parseDeadline("2026-12-31T23:59:00Z", now: at("2026-08-08T09:30:00Z"), calendar: utc)
        #expect(parsed == at("2026-12-31T23:59:00Z"))
    }

    @Test func anIsoTimestampWithFractionalSecondsParses() {
        let parsed = Router.parseDeadline("2026-12-31T23:59:00.500Z", now: at("2026-08-08T09:30:00Z"),
                                          calendar: utc)
        #expect(parsed != nil)
    }

    @Test func anIsoTimestampInThePastIsStillReturned() {
        // The route rejects it; parsing does not silently move it a day on.
        let parsed = Router.parseDeadline("2020-01-01T00:00:00Z", now: at("2026-08-08T09:30:00Z"), calendar: utc)
        #expect(parsed == at("2020-01-01T00:00:00Z"))
    }

    @Test func nonsenseIsRefused() {
        for raw in ["", "later", "25:00", "12:60", "12", "12:00:00:00", "-1:00", "aa:bb"] {
            #expect(Router.parseDeadline(raw, now: at("2026-08-08T09:30:00Z"), calendar: utc) == nil,
                    Comment(rawValue: raw))
        }
    }

    @Test func surroundingSpaceIsForgiven() {
        let parsed = Router.parseDeadline("  17:00 ", now: at("2026-08-08T09:30:00Z"), calendar: utc)
        #expect(parsed == at("2026-08-08T17:00:00Z"))
    }

    @Test func midnightTonightIsTomorrowMorning() {
        let parsed = Router.parseDeadline("00:00", now: at("2026-08-08T09:30:00Z"), calendar: utc)
        #expect(parsed == at("2026-08-09T00:00:00Z"))
    }
}
