import Testing
import Foundation
@testable import plonk

/// Where an app's new windows open, as a rule rather than a habit.
struct AppRuleTests {

    private let rules = [
        AppRule(app: "com.tinyspeck.slackmacgap", zone: 1),
        AppRule(app: "code", zone: 2, screenUUID: "B"),
    ]

    @Test func matchesTheBundleIdOrTheName() {
        #expect(AppRules.match(name: "Slack", bundleID: "com.tinyspeck.slackmacgap", rules: rules)?.zone == 1)
        #expect(AppRules.match(name: "Visual Studio Code", bundleID: "com.microsoft.VSCode", rules: rules)?.zone == 2)
        #expect(AppRules.match(name: "Safari", bundleID: "com.apple.Safari", rules: rules) == nil)
    }

    /// A rule naming the app's bundle id wins, then one naming it exactly,
    /// then a bare word, wherever each sits in the list: picking an app from
    /// the chooser cannot be shadowed by a word typed earlier, even when the
    /// app calls itself by that word. Among bare words the first wins.
    @Test func aBundleIdBeatsANameBeatsABareWord() {
        let overlapping = [AppRule(app: "code", zone: 1), AppRule(app: "com.microsoft.VSCode", zone: 2)]
        #expect(AppRules.match(name: "Code", bundleID: "com.microsoft.VSCode", rules: overlapping)?.zone == 2)
        #expect(AppRules.match(name: "Xcode", bundleID: "com.apple.dt.Xcode", rules: overlapping)?.zone == 1)
        let named = [AppRule(app: "mail", zone: 1), AppRule(app: "Mail", zone: 2)]
        #expect(AppRules.match(name: "Mail", bundleID: "com.apple.mail", rules: named)?.zone == 1)
        let words = [AppRule(app: "code", zone: 1), AppRule(app: "visual", zone: 2)]
        #expect(AppRules.match(name: "Visual Studio Code", bundleID: nil, rules: words)?.zone == 1)
    }

    /// One bad rule must not cost the user every other setting, which is
    /// what a strict decoder would do to a hand-edited file.
    @Test func aBrokenRuleDecodesToSomethingClampCanDeal() throws {
        var config = try Config.decode(Data("""
        {"appRules": [{"app": "Safari"}, {"app": "Mail", "zone": "2"}, {"zone": 3}, {"app": "Notes", "zone": 2.5}]}
        """.utf8))
        #expect(config.appRules.count == 4)
        config.clamp()
        #expect(config.appRules == [AppRule(app: "Safari", zone: 1), AppRule(app: "Mail", zone: 1),
                                    AppRule(app: "Notes", zone: 1)])
    }

    @Test func clampKeepsOneRulePerApp() {
        var config = Config()
        config.appRules = [AppRule(app: "Safari", zone: 1), AppRule(app: " safari\n", zone: 2),
                           AppRule(app: " Mail ", zone: 3)]
        config.clamp()
        #expect(config.appRules == [AppRule(app: "Safari", zone: 1), AppRule(app: "Mail", zone: 3)])
    }

    @Test func settingARuleAgainReplacesIt() {
        let updated = AppRules.upsert(AppRule(app: "COM.TINYSPECK.SLACKMACGAP", zone: 3), in: rules)
        #expect(updated.count == 2)
        #expect(updated[0].zone == 3)
        #expect(updated[0].app == "COM.TINYSPECK.SLACKMACGAP")
    }

    @Test func removingIgnoresCase() {
        #expect(AppRules.remove(app: " Code ", from: rules).map(\.app) == ["com.tinyspeck.slackmacgap"])
        #expect(AppRules.remove(app: "nothing", from: rules).count == 2)
    }

    @Test func aRuleDecodesWithoutAScreen() throws {
        let config = try Config.decode(Data("""
        {"appRules": [{"app": "com.apple.Safari", "zone": 2}], "autoFillZones": true}
        """.utf8))
        #expect(config.appRules == [AppRule(app: "com.apple.Safari", zone: 2)])
        #expect(config.autoFillZones)
    }

    @Test func rulesAndFillingAreOffByDefault() throws {
        let config = try Config.decode(Data("{}".utf8))
        #expect(config.appRules.isEmpty)
        #expect(!config.autoFillZones)
    }

    /// A hand-edited file can point at zone 0, at nothing at all, or at a
    /// display called "". A zone past the set is left as written: the set
    /// may grow, and a rule for a zone it lacks is simply not followed.
    @Test func clampRepairsWhatItCanAndDropsAnEmptyPattern() {
        var config = Config()
        config.appRules = [AppRule(app: "x", zone: 99), AppRule(app: "   ", zone: 1),
                           AppRule(app: "y", zone: 0, screenUUID: " ")]
        config.clamp()
        #expect(config.appRules == [AppRule(app: "x", zone: 99), AppRule(app: "y", zone: 1)])
    }

    @Test func theScreenComesBackAsTheIndexTheCallerKnows() {
        let rule = AppRule(app: "x", zone: 2, screenUUID: "a-display")
        let attached = rule.asDict(screenIndex: 1)
        #expect(attached["app"] as? String == "x")
        #expect(attached["zone"] as? Int == 2)
        #expect(attached["screen_uuid"] as? String == "a-display")
        #expect(attached["screen"] as? Int == 1)
        let away = rule.asDict(screenIndex: nil)
        #expect(away["screen"] == nil && away["screen_uuid"] as? String == "a-display")
        #expect(AppRule(app: "x", zone: 2).asDict(screenIndex: nil)["screen_uuid"] == nil)
    }

    // MARK: - The first empty zone

    private let halves = [ZoneRect(0, 0, 0.5, 1), ZoneRect(0.5, 0, 0.5, 1)]
    /// A screen 1000 by 600, so the windows below are in points.
    private let visible = CGRect(x: 0, y: 0, width: 1000, height: 600)
    private func window(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat = 200, _ h: CGFloat = 200) -> CGRect {
        CGRect(x: x, y: y, width: w, height: h)
    }

    @Test func theFirstZoneNothingIsInIsEmpty() {
        #expect(ZoneGeometry.firstEmpty(halves, in: visible, occupied: []) == 0)
        #expect(ZoneGeometry.firstEmpty(halves, in: visible, occupied: [window(150, 200)]) == 1)
        #expect(ZoneGeometry.firstEmpty(halves, in: visible, occupied: [window(150, 200), window(650, 10)]) == nil)
    }

    /// A window overhanging the seam counts as being where its centre is,
    /// which is what the zone cycle says about it too.
    @Test func membershipIsByCentre() {
        #expect(ZoneGeometry.firstEmpty(halves, in: visible, occupied: [window(390, 200)]) == 1)
        #expect(ZoneGeometry.firstEmpty(halves, in: visible, occupied: [window(410, 200)]) == 0)
    }

    /// A window spanning both halves, or filling the screen, has its centre
    /// on the seam and takes every zone it covers, not just the one the seam
    /// falls on.
    @Test func aSpanningWindowTakesEveryZoneItCovers() {
        #expect(ZoneGeometry.firstEmpty(halves, in: visible, occupied: [visible]) == nil)
        let quarters = [ZoneRect(0, 0, 0.5, 0.5), ZoneRect(0.5, 0, 0.5, 0.5),
                        ZoneRect(0, 0.5, 0.5, 0.5), ZoneRect(0.5, 0.5, 0.5, 0.5)]
        let topRow = CGRect(x: 0, y: 0, width: 1000, height: 300)
        #expect(ZoneGeometry.firstEmpty(quarters, in: visible, occupied: [topRow]) == 2)
    }

    /// A window macOS restored into zone 2 is straightened into zone 2, not
    /// packed leftwards into zone 1.
    @Test func aWindowAlreadyInAnEmptyZoneKeepsThatZone() {
        let inTheRight = CGPoint(x: 700, y: 300)
        #expect(ZoneGeometry.firstEmpty(halves, in: visible, occupied: [], preferring: inTheRight) == 1)
        #expect(ZoneGeometry.firstEmpty(halves, in: visible, occupied: [window(650, 10)], preferring: inTheRight) == 0)
    }

    @Test func aScreenWithNoZonesHasNoEmptyOne() {
        #expect(ZoneGeometry.firstEmpty([], in: visible, occupied: []) == nil)
    }

    /// The window that just opened is on screen too, and is told apart from
    /// the rest by its frame: the window server rounds to whole points.
    @Test func theSameFrameThroughTwoAPIsIsTheSameWindow() {
        let ax = CGRect(x: 10.4, y: 20, width: 300, height: 200.6)
        #expect(WindowServer.sameFrame(ax, CGRect(x: 10, y: 20, width: 300, height: 201)))
        #expect(!WindowServer.sameFrame(ax, CGRect(x: 12, y: 20, width: 300, height: 200)))
    }
}
