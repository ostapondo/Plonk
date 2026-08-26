import AppKit
import Testing
@testable import plonk

/// What the pointer tools draw with: which colour each of them falls back to,
/// and the bounds the numbers are held inside.
struct PointerAppearanceTests {
    private func hex(_ color: NSColor) -> String { ZoneAppearance.hex(from: color) }

    @Test func everythingFollowsTheZoneColourUntilItIsGivenOne() {
        var config = Config()
        config.zoneColorHex = "#3B9DFF"
        let look = PointerAppearance(config)
        #expect(hex(look.tint) == "#3B9DFF")
        #expect(hex(look.click) == "#3B9DFF")
        #expect(hex(look.rightClick) == "#3B9DFF")
        #expect(hex(look.crosshair) == "#3B9DFF")
    }

    @Test func aClickColourLeavesTheCrosshairsAlone() {
        var config = Config()
        config.zoneColorHex = "#3B9DFF"
        config.clickColorHex = "#E5484D"
        let look = PointerAppearance(config)
        #expect(hex(look.click) == "#E5484D")
        // A right click with no colour of its own is a left click, wherever
        // that colour came from.
        #expect(hex(look.rightClick) == "#E5484D")
        #expect(hex(look.crosshair) == "#3B9DFF")
    }

    @Test func rightClicksCanCarryTheirOwnColour() {
        var config = Config()
        config.clickColorHex = "#E5484D"
        config.rightClickColorHex = "#34D17F"
        let look = PointerAppearance(config)
        #expect(hex(look.click) == "#E5484D")
        #expect(hex(look.rightClick) == "#34D17F")
        #expect(hex(look.clickColor(right: true)) == "#34D17F")
        #expect(hex(look.clickColor(right: false)) == "#E5484D")
    }

    @Test func aStyleNobodyWroteReadsAsARing() {
        var config = Config()
        config.clickStyle = "sunburst"
        #expect(PointerAppearance(config).clickStyle == .ring)
        config.clickStyle = "dot"
        #expect(PointerAppearance(config).clickStyle == .dot)
    }

    @Test func clampReplacesAnUnknownStyleButKeepsAKnownOne() {
        var config = Config()
        config.clickStyle = "sunburst"
        config.clamp()
        #expect(config.clickStyle == "ring")
        config.clickStyle = "both"
        config.clamp()
        #expect(config.clickStyle == "both")
    }

    @Test func theNumbersAreHeldInsideTheirBounds() {
        var config = Config()
        config.clickRadius = 4000
        config.clickLineWidth = 0
        config.clickFadeSeconds = 0
        config.crosshairLineWidth = 99
        config.crosshairOpacity = 0
        config.spotlightRadius = 1
        config.spotlightDim = 1
        config.clamp()
        #expect(config.clickRadius == Config.clickRadiusRange.upperBound)
        #expect(config.clickLineWidth == Config.clickLineWidthRange.lowerBound)
        #expect(config.clickFadeSeconds == Config.clickFadeRange.lowerBound)
        #expect(config.crosshairLineWidth == Config.crosshairLineWidthRange.upperBound)
        #expect(config.crosshairOpacity == Config.opacityRange.lowerBound)
        #expect(config.spotlightRadius == Config.spotlightRadiusRange.lowerBound)
        #expect(config.spotlightDim == Config.dimRange.upperBound)
    }

    /// A ring of nothing, or one that never leaves, would be a setting the
    /// user cannot see well enough to change back.
    @Test func theBoundsThemselvesAreDrawable() {
        #expect(Config.clickRadiusRange.lowerBound > 0)
        #expect(Config.clickFadeRange.lowerBound > 0)
        #expect(Config.dimRange.upperBound < 1)
    }

    @Test func anOldConfigComesUpLookingTheWayItDid() {
        // Nothing in this file mentions the pointer, the way every config
        // written before these settings existed does not.
        let json = Data(#"{"crosshairsEnabled": true}"#.utf8)
        let config = try? Config.decode(json)
        #expect(config?.crosshairsEnabled == true)
        #expect(config?.clickRadius == 34)
        #expect(config?.clickStyle == "ring")
        #expect(config?.spotlightDim == 0.55)
    }
}
