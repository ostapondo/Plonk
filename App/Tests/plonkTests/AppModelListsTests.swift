import Testing
import Foundation
@testable import plonk

// The names the pickers and palettes list are worked out from the config the
// model holds, so a write is enough to move them; nothing refreshes a copy.
struct AppModelListsTests {

    @Test func theListsFollowTheConfig() {
        let model = AppModel()
        #expect(model.workspaceNames.isEmpty)
        #expect(model.customZoneSetNames.isEmpty)
        #expect(model.zoneSetNames == BuiltinZoneSets.all.keys.sorted())

        model.config.workspaces["work"] = Workspace(items: [])
        model.config.workspaces["home"] = Workspace(items: [])
        model.config.zoneSets["Mine"] = [ZoneRect(0, 0, 1, 1)]

        #expect(model.workspaceNames == ["home", "work"])
        #expect(model.customZoneSetNames == ["Mine"])
        #expect(model.zoneSetNames.first == "Mine")
        #expect(model.zoneSets["Mine"]?.count == 1)
    }

    /// A user's set named like a built-in template replaces it in the list
    /// and in what is drawn, rather than appearing twice.
    @Test func aUserSetShadowsTheBuiltInOfTheSameName() {
        let model = AppModel()
        let name = BuiltinZoneSets.defaultName
        let mine = [ZoneRect(0, 0, 0.5, 1), ZoneRect(0.5, 0, 0.5, 1)]
        model.config.zoneSets[name] = mine

        #expect(model.zoneSetNames.filter { $0 == name }.count == 1)
        #expect(model.zoneSets[name]?.map(\.w) == mine.map(\.w))
        #expect(model.zoneSets.count == BuiltinZoneSets.all.count)
    }

    /// The name offered for a copy is one nobody has, built-ins included.
    @Test func aFreeNameSkipsBuiltInsToo() {
        let model = AppModel()
        let name = BuiltinZoneSets.defaultName
        #expect(model.freeZoneSetName(base: name) == "\(name) 2")
        #expect(model.freeZoneSetName(base: "Fresh") == "Fresh")
    }
}
