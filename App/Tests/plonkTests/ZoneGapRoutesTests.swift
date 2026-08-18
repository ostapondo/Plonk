import Foundation
import Testing
@testable import plonk

/// A zone set's own gap, over the wire: how it is given, kept, dropped and read.
struct ZoneGapRoutesTests {
    @Test func savingAZoneSetCanGiveItAGap() {
        let h = RouterHarness()
        let zones: [[String: Any]] = [["x": 0, "y": 0, "w": 1, "h": 1]]
        #expect(h.post("/zones/save", ["name": "airy", "zones": zones, "gap": 20]).status == 200)
        #expect(h.store.config.zoneSetGaps["airy"] == 20)
        // Saving without a gap leaves the one it has.
        #expect(h.post("/zones/save", ["name": "airy", "zones": zones]).status == 200)
        #expect(h.store.config.zoneSetGaps["airy"] == 20)
        // Null puts it back on the default.
        #expect(h.post("/zones/save", ["name": "airy", "zones": zones, "gap": NSNull()]).status == 200)
        #expect(h.store.config.zoneSetGaps["airy"] == nil)
        #expect(h.post("/zones/save", ["name": "airy", "zones": zones, "gap": -1]).status == 400)
        #expect(h.post("/zones/save", ["name": "airy", "zones": zones, "gap": "wide"]).status == 400)
    }

    @Test func stateListsTheDefaultGapAndTheSetsThatKeepTheirOwn() {
        let h = RouterHarness()
        let zones: [[String: Any]] = [["x": 0, "y": 0, "w": 1, "h": 1]]
        _ = h.post("/zones/save", ["name": "airy", "zones": zones, "gap": 20])
        let state = h.get("/state").json
        #expect((state["zone_set_gaps"] as? [String: Double]) == ["airy": 20])
        #expect(state["zone_gap"] as? Double == h.store.config.zoneGap)
    }
}
