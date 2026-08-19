import Testing
import Foundation
@testable import plonk

// A feature switched off is off for every surface that asks config: the
// hotkeys it owns, the routes it answers, and the list an agent reads.
struct FeatureTests {

    @Test func everythingIsOnByDefault() {
        let config = Config()
        for feature in Feature.allCases {
            #expect(config.isEnabled(feature))
        }
        #expect(config.activeHotkeys.count == config.resolvedHotkeys.count)
    }

    @Test func switchingOffIsRememberedOnceAndSwitchingOnForgetsIt() {
        var config = Config()
        config.setEnabled(.shot, false)
        config.setEnabled(.shot, false)
        #expect(config.disabledFeatures == ["shot"])
        #expect(!config.isEnabled(.shot))
        config.setEnabled(.shot, true)
        #expect(config.disabledFeatures.isEmpty)
    }

    /// A hand-edited file can repeat an id or name one that does not exist.
    @Test func clampKeepsKnownIdsOnceInAFixedOrder() {
        var config = Config()
        config.disabledFeatures = ["voice", "shot", "voice", "teleport"]
        config.clamp()
        #expect(config.disabledFeatures == ["shot", "voice"])
    }

    @Test func anOffFeatureLosesItsHotkeysAndNothingElse() {
        var config = Config()
        config.setEnabled(.shot, false)
        let active = config.activeHotkeys
        #expect(active[.captureRegion] == nil)
        #expect(active[.cropLive] == nil)
        #expect(active[.leftHalf] != nil)
        #expect(active[.commandPalette] != nil)
    }

    @Test func everyRouteOfAnOffFeatureAnswersConflict() {
        let h = RouterHarness()
        h.store.update {
            $0.setEnabled(.workspaces, false)
            $0.setEnabled(.awake, false)
        }
        for path in ["/workspaces/save", "/layouts/apply", "/workspaces/delete", "/awake"] {
            let response = h.post(path, ["name": "work", "on": true])
            #expect(response.status == 409, "\(path)")
            #expect((response.json["error"] as? String)?.contains("switched off") == true)
        }
        // Not on: routes of features that are, and the ones that are the app.
        #expect(h.post("/zones/save", ["name": "x", "zones": [["x": 0, "y": 0, "w": 1, "h": 1]]]).status == 200)
        #expect(h.get("/ping").status == 200)
    }

    @Test func routePrefixesDoNotSwallowNeighbours() {
        #expect(Feature.owning(path: "/layout") == .zones)
        #expect(Feature.owning(path: "/layout/zone") == .zones)
        #expect(Feature.owning(path: "/layouts/apply") == .workspaces)
        #expect(Feature.owning(path: "/agents/hello") == nil)
        #expect(Feature.owning(path: "/activeness") == nil)
    }

    @Test func aPageIsHiddenWithItsFeatureAndTheRestStay() {
        let model = AppModel()
        model.settingsPages = SettingsPages.all
        var config = Config()
        config.setEnabled(.ruler, false)
        model.config = config
        let ids = model.visiblePages.map(\.id)
        #expect(!ids.contains("ruler"))
        #expect(ids.contains("features"))
        #expect(ids.contains("zones"))
        model.selectedPage = "ruler"
        #expect(model.currentPage?.id == "home")
    }
}
