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
        #expect(try JSONDecoder().decode(Config.self, from: data).handleRectangleURLs)
    }

    /// Every field is optional on the way in, so a config written before this
    /// setting existed decodes rather than throwing.
    @Test func aConfigWrittenBeforeTheSettingDecodesWithItOff() throws {
        let config = try JSONDecoder().decode(Config.self, from: Data("{}".utf8))
        #expect(config.handleRectangleURLs == false)
    }
}
