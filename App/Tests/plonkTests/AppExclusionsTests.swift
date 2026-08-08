import Testing
@testable import plonk

struct AppExclusionsTests {

    @Test func matchesAnywhereInTheNameRegardlessOfCase() {
        #expect(AppExclusions.matches(name: "Steam Helper", bundleID: nil, patterns: ["steam"]))
        #expect(AppExclusions.matches(name: "Parsec", bundleID: nil, patterns: ["PARSEC"]))
    }

    @Test func matchesTheBundleIdentifierToo() {
        #expect(AppExclusions.matches(name: "Some Launcher", bundleID: "com.valvesoftware.steam",
                                      patterns: ["valvesoftware"]))
    }

    @Test func doesNotMatchUnrelatedApps() {
        #expect(!AppExclusions.matches(name: "Safari", bundleID: "com.apple.Safari", patterns: ["steam", "parsec"]))
    }

    @Test func anEmptyListExcludesNothing() {
        #expect(!AppExclusions.matches(name: "Steam", bundleID: "com.valvesoftware.steam", patterns: []))
    }

    /// A blank entry hand-edited into config.json must not turn into
    /// "matches everything".
    @Test func blankPatternsAreIgnored() {
        #expect(!AppExclusions.matches(name: "Safari", bundleID: "com.apple.Safari", patterns: ["", "   "]))
    }
}
