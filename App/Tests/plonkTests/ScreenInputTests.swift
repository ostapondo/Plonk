import Foundation
import Testing
@testable import plonk

struct ScreenInputTests {
    @Test func absentAndNullAreOmitted() {
        guard case .omitted = ScreenInput.parse(nil) else {
            Issue.record("nil was not omitted")
            return
        }
        guard case .omitted = ScreenInput.parse(NSNull()) else {
            Issue.record("null was not omitted")
            return
        }
    }

    @Test func stringsAndBooleansAreNotMonitorIndices() {
        guard case .invalidType = ScreenInput.parse("0") else {
            Issue.record("string screen was accepted")
            return
        }
        guard case .invalidType = ScreenInput.parse(true) else {
            Issue.record("boolean screen was accepted")
            return
        }
    }

    @Test func aMissingMonitorIsNamed() {
        guard case .notFound(let index) = ScreenInput.parse(Int.max) else {
            Issue.record("missing screen was accepted")
            return
        }
        #expect(index == Int.max)
    }

    @Test func zoneRoutesDoNotPersistAMissingMonitor() {
        let h = RouterHarness()
        let zones: [[String: Any]] = [["x": 0, "y": 0, "w": 1, "h": 1]]
        let missing = Int.max
        #expect(h.post("/zones/save", ["name": "lost", "zones": zones,
                                        "screen": missing]).status == 404)
        #expect(h.store.config.zoneSets["lost"] == nil)
        #expect(h.post("/zones/assign", ["screen": missing]).status == 404)
        #expect(h.store.config.screenZoneSets[String(missing)] == nil)
    }
}
