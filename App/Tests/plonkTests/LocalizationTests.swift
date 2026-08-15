import Testing
import Foundation
@testable import plonk

// The catalog is only worth having if the app can find it. These fail loudly
// when it cannot: a missed key comes back as the key itself, which is exactly
// what a shipped build with no .lproj folders would draw on screen.

struct LocalizationTests {

    @Test func theCatalogIsFound() {
        #expect(Localization.bundle.path(forResource: "en", ofType: "lproj") != nil)
    }

    @Test func keysResolveToEnglish() {
        #expect(String(localized: .commonChoose) == "Choose")
        #expect(String(localized: .shortcutLeftHalf) == "Left Half")
    }

    @Test func valuesAreFilledIn() {
        #expect(String(localized: .shortcutZone(3)) == "Zone 3")
        #expect(String(localized: .aiAgentOffline("codex")) == "codex (offline)")
    }

    /// The counted strings come from Localizable.stringsdict, which is a
    /// separate file and a separate lookup.
    @Test func countedStringsPickTheRightForm() {
        #expect(String(localized: .workspacesAppCount(1)) == "1 app")
        #expect(String(localized: .workspacesAppCount(4)) == "4 apps")
        #expect(String(localized: .workspacesWindowCount(1)) == "1 window")
    }

    /// Nothing may reach the user as a raw key. Resolving to something other
    /// than the key itself is the only check that catches a typo in either the
    /// Swift declaration or the catalog.
    @Test func nothingResolvesToItsOwnKey() {
        #expect(String(localized: .zonesOverlayHelp) != "zones.overlayHelp")
        #expect(String(localized: .startProgress(1, 3)) == "1 of 3")
    }
}
