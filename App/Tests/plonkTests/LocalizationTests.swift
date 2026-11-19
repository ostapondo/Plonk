import Testing
import Foundation
@testable import plonk

// The catalog is only worth having if the app can find it. These fail loudly
// when it cannot: a missed key comes back as the key itself, which is exactly
// what a shipped build with no .lproj folders would draw on screen.

struct LocalizationTests {

    private var usesSimplifiedChinese: Bool {
        Localization.bundle.preferredLocalizations.first?.lowercased() == "zh-hans"
    }

    @Test func theCatalogIsFound() {
        #expect(Localization.bundle.path(forResource: "en", ofType: "lproj") != nil)
    }

    @Test func keysResolveToTheSelectedLanguage() {
        #expect(String(localized: .commonChoose) == (usesSimplifiedChinese ? "选取" : "Choose"))
        #expect(String(localized: .shortcutLeftHalf) == (usesSimplifiedChinese ? "左半屏" : "Left Half"))
    }

    @Test func valuesAreFilledIn() {
        #expect(String(localized: .shortcutZone(3)) == (usesSimplifiedChinese ? "分屏 3" : "Zone 3"))
        #expect(String(localized: .aiAgentOffline("codex")) == (usesSimplifiedChinese ? "codex（离线）" : "codex (offline)"))
    }

    /// The counted strings come from Localizable.stringsdict, which is a
    /// separate file and a separate lookup.
    @Test func countedStringsPickTheRightForm() {
        #expect(String(localized: .workspacesAppCount(1)) == (usesSimplifiedChinese ? "1 个应用" : "1 app"))
        #expect(String(localized: .workspacesAppCount(4)) == (usesSimplifiedChinese ? "4 个应用" : "4 apps"))
        #expect(String(localized: .workspacesWindowCount(1)) == (usesSimplifiedChinese ? "1 个窗口" : "1 window"))
    }

    /// Nothing may reach the user as a raw key. Resolving to something other
    /// than the key itself is the only check that catches a typo in either the
    /// Swift declaration or the catalog.
    @Test func nothingResolvesToItsOwnKey() {
        #expect(String(localized: .zonesOverlayHelp) != "zones.overlayHelp")
        #expect(String(localized: .startProgress(1, 3)) == (usesSimplifiedChinese ? "1 / 3" : "1 of 3"))
    }

    @Test func simplifiedChineseResourcesArePackaged() throws {
        let language = try #require(Localization.bundle.localizations.first { $0.lowercased() == "zh-hans" })
        let url = try #require(Localization.bundle.url(forResource: language, withExtension: "lproj"))
        let bundle = try #require(Bundle(url: url))
        let locale = Locale(identifier: language)
        #expect(String(localized: LocalizedStringResource.commonChoose.defaultValue,
                       bundle: bundle, locale: locale) == "选取")
        #expect(String(localized: LocalizedStringResource.workspacesAppCount(1).defaultValue,
                       bundle: bundle, locale: locale) == "1 个应用")
        #expect(bundle.url(forResource: "InfoPlist", withExtension: "strings") != nil)
    }
}
