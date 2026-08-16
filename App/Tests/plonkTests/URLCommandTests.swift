import Testing
import Foundation
@testable import plonk

/// The names other people's scripts hold. A rename here breaks a Stream Deck
/// button somebody set up a year ago, so most of this is about pinning the
/// vocabulary down rather than about parsing.
struct URLCommandTests {
    private func parse(_ string: String) -> Result<URLCommand, URLCommand.Failure> {
        guard let url = URL(string: string) else {
            return .failure(.unknownHost("unparseable"))
        }
        return URLCommand.parse(url)
    }

    @Test func aRectangleStyleUrlRunsTheSameAction() {
        #expect(parse("plonk://execute-action?name=left-half") == .success(.action(.leftHalf)))
        #expect(parse("plonk://execute-action?name=bottom-right") == .success(.action(.bottomRight)))
        #expect(parse("plonk://execute-action?name=maximize") == .success(.action(.maximize)))
    }

    /// Rectangle's word for giving a window back the frame it started with.
    @Test func restoreIsAcceptedForUnsnap() {
        #expect(parse("plonk://execute-action?name=restore") == .success(.action(.unsnap)))
        #expect(parse("plonk://execute-action?name=unsnap") == .success(.action(.unsnap)))
    }

    @Test func theZonesAndTheToolsAreReachableToo() {
        #expect(parse("plonk://execute-action?name=zone-3") == .success(.action(.zone3)))
        #expect(parse("plonk://execute-action?name=zone-set-2") == .success(.action(.layout2)))
        #expect(parse("plonk://execute-action?name=ruler") == .success(.action(.ruler)))
        #expect(parse("plonk://execute-action?name=capture-text") == .success(.action(.captureText)))
    }

    @Test func theNameIsNotCaseSensitive() {
        #expect(parse("plonk://execute-action?name=Left-Half") == .success(.action(.leftHalf)))
    }

    // MARK: - Saying no clearly

    /// A script asking for thirds is not broken, it is asking for something
    /// that is a zone set here. It gets told which of the two it is.
    @Test func aFixedGridActionSaysWhatItIs() {
        for name in ["first-third", "top-left-ninth", "last-two-thirds", "second-fourth"] {
            #expect(parse("plonk://execute-action?name=\(name)") == .failure(.fixedGridAction(name)))
        }
    }

    /// Rectangle keeps adding fractions — twelfths and sixteenths are already
    /// there — and a hand-kept list would answer "nothing is called that" for
    /// each new one, which is the least useful thing it could say.
    @Test func fractionsRectangleAddedLaterAreStillRecognised() {
        for name in ["top-left-twelfth", "bottom-right-sixteenth", "top-vertical-third"] {
            #expect(parse("plonk://execute-action?name=\(name)") == .failure(.fixedGridAction(name)))
        }
    }

    /// Rectangle answers to both names for a half, so a script may hold either
    /// and the documented one-line swap has to carry both.
    @Test func rectanglesOtherNameForEachHalfWorks() {
        #expect(parse("plonk://execute-action?name=left-side") == .success(.action(.leftHalf)))
        #expect(parse("plonk://execute-action?name=bottom-side") == .success(.action(.bottomHalf)))
    }

    /// Moving a window to the next display is a different thing from moving the
    /// pointer there, so this is refused rather than quietly doing the other.
    @Test func theDisplayActionsAreNotPretendedTo() {
        #expect(parse("plonk://execute-action?name=next-display") == .failure(.unknownAction("next-display")))
    }

    /// Push-to-talk finishes on the key coming back up. A URL has no second
    /// half, so starting the microphone from one would never stop it.
    @Test func voiceIsRefusedRatherThanLeftListening() {
        #expect(parse("plonk://execute-action?name=voice") == .failure(.heldDownAction("voice")))
    }

    /// It still has a name, because the hotkey and the command palette use it.
    /// Refusing it is a property of the URL surface, not of the action.
    @Test func theRefusedActionStillHasAName() {
        #expect(HotkeyAction.voice.urlName == "voice")
        #expect(URLCommand.heldDown == [.voice])
    }

    @Test func aMissingOrEmptyNameIsItsOwnAnswer() {
        #expect(parse("plonk://execute-action") == .failure(.missingName))
        #expect(parse("plonk://execute-action?name=") == .failure(.missingName))
    }

    /// Both schemes parse the same. Whether macOS actually delivers a
    /// rectangle:// URL here is a separate question, and the user's.
    @Test func bothSchemesAreUnderstood() {
        #expect(parse("rectangle://execute-action?name=left-half") == .success(.action(.leftHalf)))
        #expect(parse("PLONK://execute-action?name=left-half") == .success(.action(.leftHalf)))
    }

    @Test func aSchemeThisAppDoesNotAnswerToIsRefused() {
        #expect(parse("spectacle://execute-action?name=left-half")
            == .failure(.unknownScheme("spectacle")))
    }

    @Test func anotherVerbIsRefused() {
        #expect(parse("plonk://execute-task?name=ignore-app") == .failure(.unknownHost("execute-task")))
    }

    @Test func somethingNobodyAnswersToIsRefused() {
        #expect(parse("plonk://execute-action?name=fly-away") == .failure(.unknownAction("fly-away")))
    }

    // MARK: - The vocabulary itself

    @Test func everyActionHasAName() {
        for action in HotkeyAction.allCases {
            #expect(!action.urlName.isEmpty)
        }
    }

    @Test func noTwoActionsShareAName() {
        let names = HotkeyAction.allCases.map(\.urlName)
        #expect(Set(names).count == names.count)
    }

    /// An alias that shadowed a real name would make one of the two
    /// unreachable, and which one wins would depend on lookup order.
    @Test func noAliasShadowsARealName() {
        let names = Set(HotkeyAction.allCases.map(\.urlName))
        for alias in URLCommand.aliases.keys {
            #expect(!names.contains(alias))
        }
        for name in names {
            #expect(!URLCommand.isFixedGrid(name))
        }
    }

    /// The ten placements are the reason the vocabulary is Rectangle's. If one
    /// of these is ever renamed, somebody's existing script stops working.
    @Test func theSharedPlacementsKeepRectanglesSpelling() {
        let shared: [HotkeyAction: String] = [
            .leftHalf: "left-half", .rightHalf: "right-half",
            .topHalf: "top-half", .bottomHalf: "bottom-half",
            .topLeft: "top-left", .topRight: "top-right",
            .bottomLeft: "bottom-left", .bottomRight: "bottom-right",
            .maximize: "maximize", .center: "center",
        ]
        for (action, name) in shared {
            #expect(action.urlName == name)
        }
    }
}
