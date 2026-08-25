import Testing
import Foundation
@testable import plonk

/// The /zones/rules routes: what an agent writes when it says "Slack always
/// in zone 1". Placement itself needs a desktop, so only the bookkeeping is
/// here.
struct AppRuleRoutesTests {

    @Test func aRuleIsStoredAndSettingItAgainReplacesIt() {
        let h = RouterHarness()
        let first = h.post("/zones/rules", ["app": "com.apple.Safari", "zone": 2])
        #expect(first.status == 200)
        #expect(first.json["rules"] as? Int == 1)
        #expect(h.store.config.appRules == [AppRule(app: "com.apple.Safari", zone: 2)])

        let again = h.post("/zones/rules", ["app": " com.apple.safari ", "zone": 3])
        #expect(again.status == 200)
        #expect(h.store.config.appRules.count == 1)
        #expect(h.store.config.appRules[0].zone == 3)
    }

    @Test func aRuleNeedsAnAppAndAZone() {
        let h = RouterHarness()
        #expect(h.post("/zones/rules", ["zone": 1]).status == 400)
        #expect(h.post("/zones/rules", ["app": "Safari"]).status == 400)
        #expect(h.post("/zones/rules", ["app": "   ", "zone": 1]).status == 400)
        #expect(h.post("/zones/rules", ["app": "\n", "zone": 1]).status == 400)
        #expect(h.post("/zones/rules", ["app": "Safari", "zone": 0]).status == 400)
        #expect(h.store.config.appRules.isEmpty)
    }

    /// The reply says what was kept, which is the trimmed pattern, and the
    /// display it is stored under.
    @Test func theReplyIsWhatWasStored() {
        let h = RouterHarness()
        let reply = h.post("/zones/rules", ["app": "com.apple.Safari\n", "zone": 2])
        #expect(reply.status == 200)
        let rule = reply.json["rule"] as? [String: Any]
        #expect(rule?["app"] as? String == "com.apple.Safari")
        #expect(rule?["zone"] as? Int == 2)
        #expect(rule?["screen_uuid"] == nil)
        #expect(h.store.config.appRules == [AppRule(app: "com.apple.Safari", zone: 2)])
    }

    /// A monitor that is not there cannot be named: the rule would be stored
    /// against nothing and never fire.
    @Test func aScreenThatIsNotAttachedIsRefused() {
        let h = RouterHarness()
        #expect(h.post("/zones/rules", ["app": "Safari", "zone": 1, "screen": 99]).status == 404)
        #expect(h.post("/zones/rules", ["app": "Safari", "zone": 1, "screen": "left"]).status == 400)
        #expect(h.store.config.appRules.isEmpty)
    }

    @Test func deletingARuleThatIsNotThereSaysSo() {
        let h = RouterHarness()
        #expect(h.post("/zones/rules/delete", ["app": "Safari"]).status == 404)
        #expect(h.post("/zones/rules/delete", [:]).status == 400)
        _ = h.post("/zones/rules", ["app": "com.apple.Safari", "zone": 1])
        let deleted = h.post("/zones/rules/delete", ["app": "COM.APPLE.SAFARI"])
        #expect(deleted.status == 200)
        #expect(h.store.config.appRules.isEmpty)
    }

    /// The rules are part of zones, so switching zones off refuses them the
    /// way it refuses the other /zones routes.
    @Test func theRoutesBelongToZones() {
        let h = RouterHarness()
        h.store.update { $0.setEnabled(.zones, false) }
        #expect(h.post("/zones/rules", ["app": "Safari", "zone": 1]).status == 409)
        #expect(h.post("/zones/rules/delete", ["app": "Safari"]).status == 409)
    }
}
