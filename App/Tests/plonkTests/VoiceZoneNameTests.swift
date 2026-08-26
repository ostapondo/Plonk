import Testing
@testable import plonk

/// A zone named out loud. The names are the ones on the front window's
/// screen, in zone order, so the answer is the number that zone has today,
/// with the name kept for the HUD to say back.
struct VoiceZoneNameTests {

    private let names = ["editor", "chat", "build log"]

    private func parse(_ text: String) -> VoiceCommand? {
        VoiceCommand.parse(text, zoneNames: names)
    }

    @Test func aNameAfterAPlaceVerbIsThatZone() {
        #expect(parse("put this in chat") == .namedZone(2, "chat"))
        #expect(parse("snap it to the editor") == .namedZone(1, "editor"))
        #expect(parse("move this to chat please") == .namedZone(2, "chat"))
    }

    @Test func aNameAfterTheWordZoneIsThatZone() {
        #expect(parse("zone chat") == .namedZone(2, "chat"))
        #expect(parse("the chat zone") == .namedZone(2, "chat"))
    }

    /// Two words are one name when the set says so, and the longer name
    /// wins over a shorter one it happens to contain.
    @Test func aTwoWordNameIsMatchedWhole() {
        #expect(parse("throw it in the build log") == .namedZone(3, "build log"))
        #expect(VoiceCommand.parse("put it in the build log", zoneNames: ["log", "build log"]) == .namedZone(2, "build log"))
    }

    /// A bare name is a word, not a command; a sentence that names an app,
    /// or says where beside the name, belongs to the agent or to the place
    /// it says.
    @Test func whatStillGoesToTheAgent() {
        #expect(parse("chat") == nil)
        #expect(parse("move chrome to chat") == nil)
        #expect(parse("put this in chat and open the terminal") == nil)
        #expect(VoiceCommand.parse("put this in chat") == nil)
        #expect(VoiceCommand.parse("move terminal to the left", zoneNames: ["editor", "chat", "terminal"]) == nil)
        #expect(VoiceCommand.parse("put the chat window in zone one", zoneNames: ["editor", "chat"]) == nil)
    }

    @Test func numbersStillWorkBesideNames() {
        #expect(parse("put this in zone two") == .zone(2))
        #expect(parse("snap this left") == .preset(.leftHalf))
    }

    /// An unnamed zone is an empty string in the list, and matches nothing.
    @Test func anEmptyNameIsNotAName() {
        #expect(VoiceCommand.parse("put this in the", zoneNames: ["", "chat"]) == nil)
    }

    /// "zone two" is the second zone whatever the zones are called, even
    /// when a hand-edited file has called the first one "two".
    @Test func aNameThatIsANumberDoesNotHijackTheNumber() {
        #expect(VoiceCommand.parse("put this in zone two", zoneNames: ["two", "chat"]) == .zone(2))
        #expect(VoiceCommand.parse("put this in zone 2", zoneNames: ["2", "chat"]) == .zone(2))
    }

    /// A zone can be called by a word the parser knows, and it still yields
    /// to a number or a placement said beside it: "put this window in zone
    /// 2" is zone 2, "the top left" is the corner.
    @Test func aNameMadeOfKnownWordsYieldsToAPlacement() {
        let columns = ["left", "middle", "right"]
        #expect(VoiceCommand.parse("put this in left", zoneNames: columns) == .namedZone(1, "left"))
        #expect(VoiceCommand.parse("zone right", zoneNames: columns) == .namedZone(3, "right"))
        #expect(VoiceCommand.parse("move this to the top left", zoneNames: columns) == .preset(.topLeft))
        #expect(VoiceCommand.parse("snap this to the left half", zoneNames: columns) == .preset(.leftHalf))
        #expect(VoiceCommand.parse("put this window in zone 2", zoneNames: ["window", "chat"]) == .zone(2))
        #expect(VoiceCommand.parse("put this in zone 2", zoneNames: ["zone", "chat"]) == .zone(2))
    }
}
