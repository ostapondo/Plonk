import Testing
@testable import plonk

/// The parser that decides whether a spoken sentence runs here or goes to an
/// agent. Both halves matter, and the second one more: a sentence wrongly
/// claimed is a window moved somewhere nobody asked for, while a sentence
/// wrongly passed on still gets done, just slower.
struct VoiceCommandTests {

    private func parse(_ text: String, workspaces: [String] = []) -> VoiceCommand? {
        VoiceCommand.parse(text, workspaces: workspaces)
    }

    // MARK: - What it should catch

    @Test func halvesAndQuarters() {
        #expect(parse("snap this left") == .preset(.leftHalf))
        #expect(parse("move it right") == .preset(.rightHalf))
        #expect(parse("left half") == .preset(.leftHalf))
        #expect(parse("put this top right") == .preset(.topRight))
        #expect(parse("bottom left quarter") == .preset(.bottomLeft))
        #expect(parse("maximize") == .preset(.maximize))
        #expect(parse("centre this") == .preset(.center))
    }

    @Test func numberedZones() {
        #expect(parse("zone three") == .zone(3))
        #expect(parse("put this in zone 7") == .zone(7))
        #expect(parse("snap it to zone one") == .zone(1))
        // Zones only go to nine, and a tenth is a sentence about something else.
        #expect(parse("zone twelve") == nil)
    }

    @Test func theSmallVerbs() {
        #expect(parse("put it back") == .putBack)
        #expect(parse("undo that") == .putBack)
        #expect(parse("next window") == .cycleZone)
        #expect(parse("show me the zones") == .showZones)
        #expect(parse("focus left") == .focus(.left))
        #expect(parse("focus the window above") == .focus(.up))
    }

    @Test func keepAwakeWithAndWithoutALimit() {
        #expect(parse("keep the mac awake") == .awake(minutes: nil))
        #expect(parse("keep awake for an hour") == .awake(minutes: 60))
        #expect(parse("stay awake for two hours") == .awake(minutes: 120))
        #expect(parse("keep awake for 45 minutes") == .awake(minutes: 45))
        #expect(parse("keep awake half an hour") == .awake(minutes: 30))
        #expect(parse("stop keeping awake") == .awakeOff)
        #expect(parse("let it sleep") == .awakeOff)
    }

    @Test func workspacesOnlyWhenTheNameIsReal() {
        #expect(parse("launch my review workspace", workspaces: ["review", "work"])
            == .launchWorkspace("review"))
        #expect(parse("open work", workspaces: ["work"]) == .launchWorkspace("work"))
        // No such workspace: the agent can ask what was meant.
        #expect(parse("launch my review workspace", workspaces: ["work"]) == nil)
        // A verb is required, or every mention of the word claims it.
        #expect(parse("what is in my work workspace", workspaces: ["work"]) == nil)
    }

    /// Longest match wins, or "work" would swallow "work notes".
    @Test func theLongerWorkspaceNameWins() {
        #expect(parse("launch work notes", workspaces: ["work", "work notes"])
            == .launchWorkspace("work notes"))
    }

    @Test func dictationPunctuationDoesNotMatter() {
        #expect(parse("Snap this left.") == .preset(.leftHalf))
        #expect(parse("  ZONE   THREE  ") == .zone(3))
    }

    // MARK: - What it must not catch

    /// The whole point of the fallback: anything with a layout in it is a job
    /// for something that can hold a layout in its head.
    @Test func layoutsGoToTheAgent() {
        #expect(parse("browser on the left 60% and terminal top right") == nil)
        #expect(parse("put safari left 60 percent") == nil)
    }

    /// Placement here acts on the front window. A sentence that names an app
    /// means a different window, and only the agent can find that one.
    @Test func aNamedAppGoesToTheAgent() {
        #expect(parse("move chrome to the left half") == nil)
        #expect(parse("put slack in zone three") == nil)
        #expect(parse("maximize xcode") == nil)
        // The same sentences about the front window are still commands.
        #expect(parse("move this to the left half") == .preset(.leftHalf))
        #expect(parse("put it in zone three") == .zone(3))
    }

    @Test func twoThingsAtOnceGoToTheAgent() {
        #expect(parse("snap this left and open the terminal") == nil)
        #expect(parse("put it back, then launch review", workspaces: ["review"]) == nil)
        #expect(parse("zone three then maximise") == nil)
    }

    /// "keep awake until the build finishes" is the example in the README, and
    /// it is exactly what this parser cannot do — so it must not try.
    @Test func conditionsGoToTheAgent() {
        #expect(parse("keep the mac awake until this build finishes") == nil)
        #expect(parse("keep awake when the tests are running") == nil)
    }

    /// A bare direction is far more often part of a sentence than a command.
    @Test func bareDirectionsAreNotCommands() {
        #expect(parse("what is left on my calendar") == nil)
        #expect(parse("the terminal is on the right") == nil)
        #expect(parse("left") == nil)
    }

    @Test func nonsenseAndSilenceAreNothing() {
        #expect(parse("") == nil)
        #expect(parse("   ") == nil)
        #expect(parse("hello") == nil)
    }

    // MARK: - What the user is told

    /// Resolved through the catalog, the way the HUD does it: the announcement
    /// is a key now, and a test comparing keys would pass while the app drew
    /// nothing but keys on screen.
    @Test func everyCommandSaysWhatItDid() {
        let said = { (command: VoiceCommand) in String(localized: command.announcement) }
        #expect(said(.preset(.leftHalf)) == "Left Half")
        #expect(said(.zone(3)) == "Zone 3")
        #expect(said(.awake(minutes: 60)) == "Awake for 1h")
        #expect(said(.awake(minutes: 45)) == "Awake for 45m")
        #expect(said(.awake(minutes: nil)) == "Keep awake")
        #expect(said(.launchWorkspace("review")) == "Launch \"review\"")
    }
}
