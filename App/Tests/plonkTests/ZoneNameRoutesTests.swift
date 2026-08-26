import Testing
import Foundation
@testable import plonk

/// Zone names over the API: saved with a set, and accepted by /layout/zone in
/// place of the number. Placing needs a desktop, so the lookup is tested on
/// its own.
struct ZoneNameRoutesTests {

    private let namedZones: [[String: Any]] = [
        ["x": 0, "y": 0, "w": 0.5, "h": 1, "name": "chat"],
        ["x": 0.5, "y": 0, "w": 0.5, "h": 1],
    ]

    @Test func savingASetKeepsTheNames() {
        let h = RouterHarness()
        #expect(h.post("/zones/save", ["name": "desk", "zones": namedZones]).status == 200)
        let zones = h.store.config.zoneSets["desk"] ?? []
        #expect(zones.count == 2)
        #expect(zones[0].name == "chat")
        #expect(zones[1].name == nil)
    }

    /// Two zones called the same thing would make "put this in chat" a coin
    /// toss, so the set is refused whole.
    @Test func twoZonesWithOneNameAreRefused() {
        let h = RouterHarness()
        let twice: [[String: Any]] = [
            ["x": 0, "y": 0, "w": 0.5, "h": 1, "name": "Chat"],
            ["x": 0.5, "y": 0, "w": 0.5, "h": 1, "name": "chat"],
        ]
        #expect(h.post("/zones/save", ["name": "desk", "zones": twice]).status == 400)
        #expect(h.store.config.zoneSets["desk"] == nil)
    }

    @Test func placingNeedsAZoneOfSomeKind() {
        let h = RouterHarness()
        #expect(h.post("/layout/zone", ["app": "Safari"]).status == 400)
    }

    // MARK: - Which zone a request means

    private let zones = [ZoneRect(0, 0, 0.5, 1, name: "chat"), ZoneRect(0.5, 0, 0.5, 1)]

    @Test func aNumberIsTheZoneInThatPlace() {
        #expect(Router.zoneIndex(NSNumber(value: 2), in: zones) == 1)
        #expect(Router.zoneIndex("2", in: zones) == 1)
        #expect(Router.zoneIndex(NSNumber(value: 3), in: zones) == nil)
        #expect(Router.zoneIndex(NSNumber(value: 0), in: zones) == nil)
        // A body can hold any integer, and the smallest one must not trap.
        #expect(Router.zoneIndex(NSNumber(value: Int.min), in: zones) == nil)
        #expect(Router.zoneIndex(NSNumber(value: -1e300), in: zones) == nil)
    }

    /// A zone called "2" would fight the zone in second place, and a caller
    /// is told so rather than finding the name gone.
    @Test func aNumberIsRefusedAsAName() {
        let h = RouterHarness()
        let numbered: [[String: Any]] = [["x": 0, "y": 0, "w": 0.5, "h": 1, "name": "2"],
                                         ["x": 0.5, "y": 0, "w": 0.5, "h": 1, "name": "chat"]]
        #expect(h.post("/zones/save", ["name": "desk", "zones": numbered]).status == 400)
        #expect(h.store.config.zoneSets["desk"] == nil)
    }

    @Test func aZoneThatIsNeitherANumberNorAName() {
        let h = RouterHarness()
        #expect(h.post("/layout/zone", ["app": "Safari", "zone": NSNull()]).status == 400)
        #expect(h.post("/layout/zone", ["app": "Safari", "zone": [1]]).status == 400)
    }

    @Test func aNameIsTheZoneCalledThat() {
        #expect(Router.zoneIndex("Chat", in: zones) == 0)
        #expect(Router.zoneIndex(" chat ", in: zones) == 0)
        #expect(Router.zoneIndex("editor", in: zones) == nil)
        #expect(Router.zoneIndex("", in: zones) == nil)
        #expect(Router.zoneIndex(NSNull(), in: zones) == nil)
    }
}
