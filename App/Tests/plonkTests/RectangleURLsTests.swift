import Testing
import Foundation
@testable import plonk

/// Who holds the rectangle:// scheme. The NSWorkspace calls need a real
/// LaunchServices database, so what is checked here is the rule they follow.
struct RectangleURLsTests {
    @Test func askingForItWhenSomethingElseHasItTakesIt() {
        #expect(RectangleURLs.move(wanted: true, isHandler: false, rectangleInstalled: true) == .take)
        #expect(RectangleURLs.move(wanted: true, isHandler: false, rectangleInstalled: false) == .take)
    }

    @Test func askingForItWhenItIsAlreadyHeldDoesNothing() {
        #expect(RectangleURLs.move(wanted: true, isHandler: true, rectangleInstalled: true) == .nothing)
    }

    /// The case the setting exists for: the scheme was won by accident, and
    /// there is a Rectangle to give it back to.
    @Test func holdingItUnaskedGivesItBack() {
        #expect(RectangleURLs.move(wanted: false, isHandler: true, rectangleInstalled: true) == .giveBack)
    }

    /// Nothing to hand it to. Keeping it is not a decision, it is the only
    /// state there is, so the switch being off cannot mean anything else.
    @Test func holdingItWithNoRectangleInstalledStays() {
        #expect(RectangleURLs.move(wanted: false, isHandler: true, rectangleInstalled: false) == .nothing)
    }

    @Test func notHoldingItAndNotWantingItIsAlreadyRight() {
        #expect(RectangleURLs.move(wanted: false, isHandler: false, rectangleInstalled: true) == .nothing)
        #expect(RectangleURLs.move(wanted: false, isHandler: false, rectangleInstalled: false) == .nothing)
    }

    /// Whatever the state, asking again should not undo the first answer.
    @Test func theRuleSettlesAfterOneMove() {
        for installed in [true, false] {
            for wanted in [true, false] {
                let first = RectangleURLs.move(
                    wanted: wanted, isHandler: false, rectangleInstalled: installed
                )
                let settled = first == .take
                #expect(RectangleURLs.move(
                    wanted: wanted, isHandler: settled, rectangleInstalled: installed
                ) == .nothing)
            }
        }
    }

    /// URLCommand parses the scheme this names, so the two cannot drift apart
    /// without the URLs quietly going unanswered.
    @Test func theSchemeIsOneUrlCommandAnswersTo() {
        #expect(URLCommand.schemes.contains(RectangleURLs.scheme))
    }
}
