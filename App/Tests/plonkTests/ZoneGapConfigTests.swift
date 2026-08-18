import Foundation
import Testing
@testable import plonk

/// A zone set's own gap in config: which screen gets it, and what happens to
/// it when the set goes.
struct ZoneGapConfigTests {
    @Test func forgettingASetDropsItsGap() {
        var config = Config()
        config.zoneSets["Mine"] = [ZoneRect(0, 0, 1, 1)]
        config.zoneSetGaps["Mine"] = 12
        config.forgetZoneSet(named: "Mine")
        #expect(config.zoneSetGaps["Mine"] == nil)
    }

    @Test func aSetGapOverridesTheDefaultOnlyForThatSet() {
        var config = Config()
        config.zoneGap = 8
        config.zoneSets["Airy"] = [ZoneRect(0, 0, 1, 1)]
        config.zoneSetGaps["Airy"] = 24
        config.assignZoneSet("Airy", forKeys: ["uuid-1"])
        config.assignZoneSet("Thirds", forKeys: ["uuid-2"])
        #expect(config.zoneGap(forKeys: ["uuid-1"]) == 24)
        #expect(config.zoneGap(forKeys: ["uuid-2"]) == 8)
        // An unassigned screen wears the default set, which can have its own.
        #expect(config.zoneGap(forKeys: ["uuid-3"]) == 8)
        config.zoneSetGaps[BuiltinZoneSets.defaultName] = 2
        #expect(config.zoneGap(forKeys: ["uuid-3"]) == 2)
    }

    @Test func setGapsAreClampedLikeTheDefault() {
        var config = Config()
        config.zoneSetGaps["Wild"] = Config.gapLimit + 100
        config.zoneSetGaps["Neg"] = -5
        config.clamp()
        #expect(config.zoneSetGaps["Wild"] == Config.gapLimit)
        #expect(config.zoneSetGaps["Neg"] == 0)
    }
}
