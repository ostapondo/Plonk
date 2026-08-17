import Testing
import Foundation
import Carbon.HIToolbox
@testable import plonk

/// The rules Config owns, which the shortcut recorder and the Rectangle import
/// both go through rather than each keeping a copy.
struct ConfigBindingTests {


    @Test func bindFreesTheCombinationWhereverElseItWas() {
        var config = Config()
        let taken = config.bind(.leftHalf, to: Hotkey(
            keyCode: UInt32(kVK_ANSI_T), control: true, option: true
        ))
        #expect(taken == [.captureText])
        #expect(config.hotkeys["captureText"] == "")
        #expect(config.resolvedHotkeys[.leftHalf]?.keyCode == UInt32(kVK_ANSI_T))
    }

    /// Every bound lives in clamp(), and ConfigStore runs it after each write,
    /// so no caller carries a range of its own.
    @Test func clampHoldsEveryBoundWhoeverWroteTheValue() {
        var config = Config()
        config.zoneGap = -1
        config.zoneOpacity = 0
        config.zoneEdgeSpanPoints = 1000
        config.rulerEdgeTolerance = 0
        config.awakeTimeoutMinutes = -5
        config.clamp()

        #expect(config.zoneGap == 0)
        #expect(config.zoneOpacity == Config.opacityRange.lowerBound)
        #expect(config.zoneEdgeSpanPoints == Config.edgeSpanLimit)
        #expect(config.rulerEdgeTolerance == EdgeDetector.toleranceRange.lowerBound)
        #expect(config.awakeTimeoutMinutes == 0)

        config.zoneGap = 1000
        config.clamp()
        #expect(config.zoneGap == Config.gapLimit)
    }

    /// Clamping is what a hand-edited config.json passes through, so it has to
    /// leave a value that was already legal exactly as it found it.
    @Test func clampLeavesALegalConfigAlone() {
        var config = Config()
        config.zoneGap = 12
        config.zoneOpacity = 0.5
        let before = config
        config.clamp()
        #expect(config.zoneGap == before.zoneGap)
        #expect(config.zoneOpacity == before.zoneOpacity)
    }

    @Test func theRectangleUrlSettingRoundTripsThroughJson() throws {
        var config = Config()
        config.handleRectangleURLs = true
        let data = try JSONEncoder().encode(config)
        #expect(try Config.decode(data).handleRectangleURLs)
    }

    /// Every field is optional on the way in, so a config written before this
    /// setting existed decodes rather than throwing.
    @Test func aConfigWrittenBeforeTheSettingDecodesWithItOff() throws {
        let config = try Config.decode(Data("{}".utf8))
        #expect(config.handleRectangleURLs == false)
    }

    /// The file is merged over the defaults key by key, and the merge recurses.
    /// A nested object naming one field keeps its siblings rather than
    /// arriving as an object with a hole in it.
    @Test func aPartialNestedObjectKeepsTheFieldsItDoesNotName() throws {
        let config = try Config.decode(Data(#"{"appearance": {"theme": "dark"}}"#.utf8))
        #expect(config.appearance.theme == "dark")
        #expect(config.appearance.accentHex == Config().appearance.accentHex)
    }

    /// An explicit null is a missing key, not a value. Reaching the decoder it
    /// would throw on any field that is not Optional, and that costs the whole
    /// file: ConfigStore sets an unreadable config aside, taking every
    /// workspace and zone set in it along with the one bad field.
    @Test func anExplicitNullFallsBackToTheDefault() throws {
        let config = try Config.decode(Data(#"""
        {"zoneGap": null, "zonesModifier": "option", "appearance": {"theme": null}}
        """#.utf8))
        #expect(config.zoneGap == 0)
        #expect(config.appearance.theme == Config().appearance.theme)
        // The keys either side of it still arrive, so this is a fallback and
        // not the file being thrown away.
        #expect(config.zonesModifier == "option")
    }

    /// A file that is valid JSON but not an object is as unreadable as one that
    /// is not JSON at all, and ConfigStore has to hear about it either way:
    /// that is what sets the file aside instead of overwriting it.
    @Test func aFileThatIsNotAnObjectIsRefused() {
        #expect(throws: (any Error).self) { try Config.decode(Data("[1,2]".utf8)) }
        #expect(throws: (any Error).self) { try Config.decode(Data("not json".utf8)) }
    }

    /// Arrays hold the data worth losing: a workspace's items, a zone set's
    /// rects, the excluded-app patterns. A null in any of them used to throw,
    /// and a throw is the whole file set aside rather than one field reset.
    @Test func anExplicitNullInsideAnArrayIsSkipped() throws {
        let config = try Config.decode(Data(#"{"excludedApps": ["Finder", null], "zoneGap": 7}"#.utf8))
        #expect(config.excludedApps == ["Finder"])
        #expect(config.zoneGap == 7)
    }

    /// Nulls are stripped before the rename runs, because a key set to null is
    /// present as far as a dictionary is concerned. Asking after they are gone
    /// is the only way "has this file been migrated already" means what it says.
    @Test func aNullWorkspacesKeyStillMigratesLegacyLayouts() throws {
        let json = #"""
        {"workspaces": null, "layouts": {"dev": [{"app": "Safari", "x": 0, "y": 0, "w": 1, "h": 1}]}}
        """#
        let config = try Config.decode(Data(json.utf8))
        #expect(config.workspaces["dev"]?.items.count == 1)
    }

    /// The merge has to recurse for a type whose defaults are not nil, which is
    /// what makes this different from the appearance case above: ActiveSchedule
    /// has a synthesized decoder and non-zero defaults, so a partial object
    /// without the recursion throws and costs the whole file.
    @Test func aPartialNestedObjectKeepsNonNilDefaults() throws {
        let config = try Config.decode(Data(#"{"activeSchedule": {"enabled": true}}"#.utf8))
        #expect(config.activeSchedule.enabled)
        #expect(config.activeSchedule.start == ActiveSchedule().start)
        #expect(config.activeSchedule.end == ActiveSchedule().end)
    }
}
