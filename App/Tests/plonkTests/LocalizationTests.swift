import Testing
import Foundation
@testable import plonk

struct LocalizationTests {
    @Test func keysResolveToThePreferredCatalog() throws {
        let language = try #require(Localization.bundle.preferredLocalizations.first)
        let bundle = try catalog(language)
        let expected = bundle.localizedString(forKey: "common.choose", value: nil, table: nil)

        #expect(expected != "common.choose")
        #expect(String(localized: .commonChoose) == expected)
        #expect(String(AttributedString(localized: .commonChoose).characters) == expected)
    }

    @Test func englishCountsPickTheRightForm() throws {
        let bundle = try catalog("en")
        let locale = Locale(identifier: "en")
        let one = LocalizedStringResource.workspacesAppCount(1)
        let many = LocalizedStringResource.workspacesAppCount(4)

        #expect(String(localized: one.defaultValue, bundle: bundle, locale: locale) == "1 app")
        #expect(String(localized: many.defaultValue, bundle: bundle, locale: locale) == "4 apps")
    }

    @Test func simplifiedChineseCatalogResolvesInterpolatedText() throws {
        let bundle = try catalog("zh-Hans")
        let locale = Locale(identifier: "zh-Hans")
        let resource = LocalizedStringResource.shortcutZone(3)
        let text = String(localized: resource.defaultValue, bundle: bundle, locale: locale)

        #expect(containsHan(text))
        #expect(text.contains("3"))
    }

    @Test func waitingHUDNamesTheAgent() {
        #expect(String(localized: .hudWaitingFor("codex")).contains("codex"))
    }

    @Test func aLocaleThatSpeaksTheCatalogIsKept() {
        let chinese = Locale(identifier: "zh_CN")
        #expect(Localization.locale(showing: "zh-Hans", current: chinese) == chinese)
        let english = Locale(identifier: "en_GB")
        #expect(Localization.locale(showing: "en", current: english) == english)
        #expect(Localization.locale(showing: nil, current: english) == english)
    }

    @Test func aFallbackCatalogBringsItsOwnLanguageAndKeepsTheRegion() {
        let ukrainian = Localization.locale(showing: "en", current: Locale(identifier: "uk_UA"))
        #expect(ukrainian.language.languageCode == .english)
        #expect(ukrainian.region == .ukraine)

        let traditional = Localization.locale(showing: "en", current: Locale(identifier: "zh_TW"))
        #expect(traditional.language.languageCode == .english)

        let simplified = Localization.locale(showing: "zh-Hans", current: Locale(identifier: "en_US"))
        #expect(simplified.language.languageCode == .chinese)
        #expect(simplified.language.script == .hanSimplified)
        #expect(simplified.region == .unitedStates)
    }

    @Test(arguments: [1, 4])
    func countsThroughTheModuleFollowTheShownCatalog(count: Int) throws {
        let language = try #require(Localization.bundle.preferredLocalizations.first)
        let resource = LocalizedStringResource.workspacesAppCount(count)
        let expected = String(localized: resource.defaultValue, bundle: try catalog(language),
                              locale: Locale(identifier: language))

        #expect(String(localized: resource) == expected)
    }

    @Test(arguments: ["zoneSet.halves", "zoneSet.thirds", "zoneSet.quarters", "zoneSet.priority"])
    func builtInZoneSetNamesAreTranslated(key: String) throws {
        let bundle = try catalog("zh-Hans")
        #expect(containsHan(bundle.localizedString(forKey: key, value: nil, table: nil)))
    }

    @Test(arguments: [0, 1, 4])
    func simplifiedChineseCountsResolve(count: Int) throws {
        let bundle = try catalog("zh-Hans")
        let locale = Locale(identifier: "zh-Hans")
        let resource = LocalizedStringResource.workspacesAppCount(count)
        let text = String(localized: resource.defaultValue, bundle: bundle, locale: locale)

        #expect(containsHan(text))
        #expect(text.contains(String(count)))
    }

    @Test(arguments: ["NSMicrophoneUsageDescription", "NSSpeechRecognitionUsageDescription"])
    func simplifiedChinesePermissionPromptsArePackaged(key: String) throws {
        let bundle = try catalog("zh-Hans")
        #expect(containsHan(bundle.localizedString(forKey: key, value: nil, table: "InfoPlist")))
    }

    private func catalog(_ language: String) throws -> Bundle {
        let folder = try #require(Localization.bundle.localizations.first {
            $0.caseInsensitiveCompare(language) == .orderedSame
        })
        let url = try #require(Localization.bundle.url(forResource: folder, withExtension: "lproj"))
        return try #require(Bundle(url: url))
    }

    private func containsHan(_ text: String) -> Bool {
        text.range(of: #"\p{Han}"#, options: .regularExpression) != nil
    }
}
