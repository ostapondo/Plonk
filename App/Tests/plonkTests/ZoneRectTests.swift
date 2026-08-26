import Testing
import Foundation
@testable import plonk

/// A zone with a name: how the name is read, kept and looked up.
struct ZoneRectTests {

    @Test func aZoneDecodesWithoutAName() throws {
        let zones = try JSONDecoder().decode([ZoneRect].self, from: Data("""
        [{"x": 0, "y": 0, "w": 0.5, "h": 1}]
        """.utf8))
        #expect(zones.count == 1)
        #expect(zones[0].name == nil)
    }

    @Test func aNameSurvivesTheConfigRoundTrip() throws {
        let data = try JSONEncoder().encode([ZoneRect(0, 0, 0.5, 1, name: "chat"), ZoneRect(0.5, 0, 0.5, 1)])
        let back = try JSONDecoder().decode([ZoneRect].self, from: data)
        #expect(back[0].name == "chat")
        #expect(back[1].name == nil)
        // Nothing is written for a zone that has no name, so a hand-edited
        // file stays as short as it was.
        #expect(!String(decoding: data, as: UTF8.self).contains("null"))
    }

    @Test func aNameFromARequestIsTrimmedAndCapped() {
        let padded = ZoneRect(dict: ["x": 0, "y": 0, "w": 1, "h": 1, "name": "  chat \n"])
        #expect(padded?.name == "chat")
        let blank = ZoneRect(dict: ["x": 0, "y": 0, "w": 1, "h": 1, "name": "   "])
        #expect(blank?.name == nil)
        let long = ZoneRect(dict: ["x": 0, "y": 0, "w": 1, "h": 1, "name": String(repeating: "a", count: 40)])
        #expect(long?.name?.count == ZoneRect.nameLimit)
    }

    /// A number already means the zone in that place, so it is no name.
    @Test func aNumberIsNoName() {
        #expect(ZoneRect(0, 0, 1, 1, name: "2").name == nil)
        #expect(ZoneRect(0, 0, 1, 1, name: " 12 ").name == nil)
        #expect(ZoneRect(0, 0, 1, 1, name: "+3").name == nil)
        #expect(ZoneRect(0, 0, 1, 1, name: "2nd").name == "2nd")
        #expect(ZoneRect.isRefusedName("2") && !ZoneRect.isRefusedName("   ") && !ZoneRect.isRefusedName("chat"))
    }

    /// Cleaning a clean name changes nothing, even when the cut lands on a
    /// space, so what is stored is what finds it.
    @Test func cleaningIsIdempotent() throws {
        let raw = "abcdefghijklmnopqrstuvw x"
        let once = try #require(ZoneRect.cleanName(raw))
        #expect(once == "abcdefghijklmnopqrstuvw")
        #expect(ZoneRect.cleanName(once) == once)
    }

    /// A hand-edited file gets the same cleaning as everything else, and a
    /// name that is not text is no name rather than a config that will not
    /// load.
    @Test func aHandEditedNameIsCleanedOnTheWayIn() throws {
        let zones = try JSONDecoder().decode([ZoneRect].self, from: Data("""
        [{"x": 0, "y": 0, "w": 0.5, "h": 1, "name": " chat "},
         {"x": 0.5, "y": 0, "w": 0.25, "h": 1, "name": ""},
         {"x": 0.75, "y": 0, "w": 0.25, "h": 1, "name": 2}]
        """.utf8))
        #expect(zones.map(\.name) == ["chat", nil, nil])
    }

    @Test func theDictionaryCarriesTheNameOnlyWhenThereIsOne() {
        #expect(ZoneRect(0, 0, 1, 1, name: "chat").asDict["name"] as? String == "chat")
        #expect(ZoneRect(0, 0, 1, 1).asDict["name"] == nil)
    }

    // MARK: - Names through the editor

    /// Splitting a zone keeps its name on the half that stays where it was;
    /// the new half is unnamed until somebody names it.
    @Test func splittingKeepsTheNameOnTheFirstHalf() throws {
        let zones = [ZoneRect(0, 0, 1, 1, name: "editor")]
        let split = try #require(ZoneGeometry.split(zones, at: 0, fraction: 0.5, vertical: true))
        #expect(split[0].name == "editor")
        #expect(split[1].name == nil)
    }

    /// The editor holds a half-typed name; an edit to the zone's shape must
    /// not clean it out from under the cursor.
    @Test func anEditKeepsADraftNameAsTyped() throws {
        var draft = [ZoneRect(0, 0, 1, 1)]
        draft[0].name = "build "
        let split = try #require(ZoneGeometry.split(draft, at: 0, fraction: 0.5, vertical: true))
        #expect(split[0].name == "build ")
        let nudged = try #require(ZoneGeometry.adjust(split, at: 0, dx: -0.05, dy: 0, resizing: true))
        #expect(nudged[0].name == "build ")
    }

    /// A hand-edited file with two zones of one name loads with the later
    /// one unnamed, the way every writer would have refused it.
    @Test func aDuplicateFromAFileLosesItsName() {
        var config = Config()
        config.zoneSets["desk"] = [ZoneRect(0, 0, 0.5, 1, name: "Chat"), ZoneRect(0.5, 0, 0.5, 1, name: "chat")]
        config.clamp()
        #expect(config.zoneSets["desk"]?.map(\.name) == ["Chat", nil])
    }

    @Test func movingOrResizingKeepsTheName() throws {
        let zones = [ZoneRect(0, 0, 0.5, 1, name: "chat"), ZoneRect(0.5, 0, 0.5, 1)]
        let moved = try #require(ZoneGeometry.adjust(zones, at: 0, dx: 0, dy: 0, resizing: false))
        #expect(moved[0].name == "chat")
        let resized = try #require(ZoneGeometry.adjust(zones, at: 0, dx: -0.05, dy: 0, resizing: true))
        #expect(resized[0].name == "chat")
    }

    // MARK: - Looking one up

    private let named = [ZoneRect(0, 0, 0.5, 1, name: "Editor"), ZoneRect(0.5, 0, 0.5, 1, name: "build log")]

    @Test func aNameIsFoundIgnoringCaseAndPadding() {
        #expect(ZoneGeometry.index(named: "editor", in: named) == 0)
        #expect(ZoneGeometry.index(named: " Build Log ", in: named) == 1)
        #expect(ZoneGeometry.index(named: "chat", in: named) == nil)
    }

    /// A number is the zone in that place, never a name, so the two ways of
    /// addressing a zone cannot contradict each other.
    @Test func aNumberIsNotAName() {
        #expect(ZoneGeometry.index(named: "2", in: named) == nil)
        #expect(ZoneGeometry.index(named: "", in: named) == nil)
    }

    /// A query with a line break from dictation, or longer than a name can
    /// be, finds the name the same text was stored as.
    @Test func theQueryIsCleanedTheWayTheNameWas() {
        #expect(ZoneGeometry.index(named: "editor\n", in: named) == 0)
        let long = String(repeating: "a", count: 30)
        #expect(ZoneGeometry.index(named: long, in: [ZoneRect(0, 0, 1, 1, name: long)]) == 0)
    }

    @Test func aNameUsedTwiceIsFound() {
        #expect(ZoneGeometry.duplicateName(in: named) == nil)
        let twice = [ZoneRect(0, 0, 0.5, 1, name: "Chat"), ZoneRect(0.5, 0, 0.5, 1, name: "chat")]
        #expect(ZoneGeometry.duplicateName(in: twice) == "chat")
    }
}
