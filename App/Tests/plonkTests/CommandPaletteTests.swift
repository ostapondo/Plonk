import Testing
@testable import plonk

// The palette's matching is the only part of it that is pure logic, and it is
// the part that decides whether typing three letters finds the right command.

private func command(_ title: String, group: String = "Zones") -> PlonkCommand {
    PlonkCommand(id: title, title: title, group: group) {}
}

private let sample = [
    command("Snap to zone 1"),
    command("Show the zone overlay"),
    command("Edit zone sets…"),
    command("Launch workspace “Deep work”", group: "Workspaces"),
    command("Open Keyboard", group: "Settings"),
]

@Suite struct CommandPaletteTests {
    @Test func anEmptyQueryKeepsEveryCommandInOrder() {
        #expect(sample.matching("").map(\.title) == sample.map(\.title))
        #expect(sample.matching("   ").count == sample.count)
    }

    @Test func lettersMatchOutOfOrderOnlyAsASubsequence() {
        #expect(sample.matching("zone").count == 3)
        // "enoz" is the same letters backwards, and matches nothing.
        #expect(sample.matching("enoz").isEmpty)
    }

    @Test func initialsBeatLettersBuriedInAWord() {
        // s-t-z appears in "Snap to zone" as three word starts, and in
        // "Edit zone sets" only inside words.
        #expect(sample.matching("stz").first?.title == "Snap to zone 1")
    }

    @Test func aRunOfLettersBeatsAScatteredOne() {
        #expect(sample.matching("overlay").first?.title == "Show the zone overlay")
        #expect(sample.matching("workspace").first?.title == "Launch workspace “Deep work”")
    }

    @Test func matchingIgnoresCaseAndSurroundingSpace() {
        #expect(sample.matching("  KEYBOARD ").first?.title == "Open Keyboard")
    }

    @Test func aQueryThatMatchesNothingReturnsNothing() {
        #expect(sample.matching("xylophone").isEmpty)
    }

    /// The scorer walks string indices by hand, so the ends are worth pinning.
    @Test func theEndsOfAStringDoNotCrashTheScorer() {
        #expect(sample.matching("1").first?.title == "Snap to zone 1")
        #expect(sample.matching("…").first?.title == "Edit zone sets…")
        #expect([command("a")].matching("aa").isEmpty)
    }
}
