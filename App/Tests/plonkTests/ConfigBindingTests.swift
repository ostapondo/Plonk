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

    @Test func setGapHoldsTheSameBoundsWhoeverCalls() {
        var config = Config()
        config.setGap(-1)
        #expect(config.zoneGap == 0)
        config.setGap(1000)
        #expect(config.zoneGap == Config.gapLimit)
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
