import ApplicationServices
import CoreGraphics
import Testing
@testable import plonk

/// The desk, per set of displays: what is kept, how a fresh walk is folded
/// into it, what a walk notes, and which switches it answers to.
struct DeskMemoryTests {

    private let half = FracRect(0, 0, 0.5, 1)
    private func entry(_ pid: pid_t, _ frac: FracRect? = nil, on screen: String = "A") -> DeskMemory.Entry {
        DeskMemory.Entry(window: element(pid), frac: frac ?? half, screenUUID: screen)
    }
    private func has(_ entries: [DeskMemory.Entry], _ pid: pid_t) -> Bool {
        entries.contains { CFEqual($0.window, element(pid)) }
    }

    @Test func aDeskNeverSeenHasNothingToPutBack() {
        #expect(DeskMemory().entries(for: ["A"]).isEmpty)
    }

    @Test func recordingReplacesWhatWasKnownForThatDesk() {
        let memory = DeskMemory()
        memory.record([entry(1)], for: ["A"])
        memory.record([entry(2), entry(3)], for: ["A"])
        let entries = memory.entries(for: ["A"])
        #expect(entries.count == 2 && !has(entries, 1))
    }

    /// Unplugging the external leaves the laptop's own desk; plugging it
    /// back in must find the two-display desk, not the one-display one.
    @Test func eachSetOfDisplaysKeepsItsOwnDesk() {
        let memory = DeskMemory()
        memory.record([entry(1)], for: ["A"])
        memory.record([entry(1, FracRect(0.5, 0, 0.5, 1), on: "B")], for: ["B", "A"])
        #expect(memory.entries(for: ["A"]).first?.screenUUID == "A")
        #expect(memory.entries(for: ["A", "B"]).first?.screenUUID == "B")
    }

    /// A Mac with its lid shut and nothing plugged in reports no displays;
    /// that is not a desk.
    @Test func noDisplaysIsNotADesk() {
        let memory = DeskMemory()
        memory.record([entry(1)], for: [])
        memory.note(entry(2), for: [])
        #expect(memory.entries(for: []).isEmpty)
    }

    /// A placement is known at once: the window's line in that desk is
    /// replaced and the rest are left as they were.
    @Test func notingOneWindowReplacesItsLineOnly() {
        let memory = DeskMemory()
        memory.record([entry(1), entry(2)], for: ["A"])
        memory.note(entry(1, FracRect(0.5, 0, 0.5, 1)), for: ["A"])
        let entries = memory.entries(for: ["A"])
        #expect(entries.count == 2 && has(entries, 2))
        #expect(entries.first { CFEqual($0.window, element(1)) }?.frac.x == 0.5)
    }

    @Test func clearingForgetsEveryDesk() {
        let memory = DeskMemory()
        memory.record([entry(1)], for: ["A"])
        memory.clear()
        #expect(memory.entries(for: ["A"]).isEmpty)
    }

    // MARK: - Folding a walk in

    /// A window seen now takes its new place; one on another Space, which a
    /// walk does not see, keeps its old one; one that has closed goes.
    @Test func aWalkIsMergedOverWhatWasKnown() {
        let known = [entry(1), entry(2), entry(3)]
        let fresh = [entry(1, FracRect(0.5, 0, 0.5, 1))]
        let merged = DeskMemory.merged(known, with: fresh) { !CFEqual($0, element(3)) }
        #expect(merged.count == 2 && has(merged, 2) && !has(merged, 3))
        #expect(merged.first { CFEqual($0.window, element(1)) }?.frac.x == 0.5)
    }

    // MARK: - What a walk notes

    private let screen = WindowManager.ScreenInfo(index: 0,
                                                  frame: CGRect(x: 0, y: 0, width: 1000, height: 600),
                                                  visible: CGRect(x: 0, y: 25, width: 1000, height: 575))
    private func noted(_ frame: CGRect) -> [DeskMemory.Entry] {
        DeskWatcher.entries(of: [(element(1), frame)], screens: [(screen, "A")])
    }

    @Test func aWindowIsNotedAsAFractionOfTheDisplayItsCentreIsOn() throws {
        let entry = try #require(noted(CGRect(x: 0, y: 25, width: 500, height: 575)).first)
        #expect(entry.screenUUID == "A")
        #expect(abs(entry.frac.x) < 0.001 && abs(entry.frac.y) < 0.001)
        #expect(abs(entry.frac.w - 0.5) < 0.001 && abs(entry.frac.h - 1) < 0.001)
    }

    @Test func aWindowOnNoDisplayIsSkipped() {
        #expect(noted(CGRect(x: 5000, y: 5000, width: 100, height: 100)).isEmpty)
    }

    /// Over the menu bar means fullscreen, on a Space of its own; putting
    /// that frame back later would push the window off the visible area.
    @Test func aFullscreenWindowIsSkipped() {
        #expect(noted(screen.frame).isEmpty)
    }

    @Test func aFrameThatHasNotMovedReadsAsClose() {
        let rect = CGRect(x: 10, y: 20, width: 300, height: 200)
        #expect(DeskWatcher.close(rect, rect.offsetBy(dx: 0.5, dy: -0.5)))
        #expect(!DeskWatcher.close(rect, rect.offsetBy(dx: 2, dy: 0)))
    }

    /// The inverse of the frame a fraction lands at, so what is noted is
    /// what puts the window back.
    @Test func aFractionRoundTripsThroughAFrame() throws {
        let visible = CGRect(x: 100, y: 25, width: 1000, height: 575)
        let frac = FracRect(0.2, 0.1, 0.5, 0.4)
        let frame = ZoneGeometry.frame(for: frac, in: visible)
        let back = try #require(ZoneGeometry.fraction(of: frame, in: visible))
        #expect(abs(back.x - 0.2) < 0.0001 && abs(back.w - 0.5) < 0.0001)
        #expect(ZoneGeometry.fraction(of: frame, in: .zero) == nil)
    }

    // MARK: - The switches

    /// The display-change switch is the master and the module above it;
    /// the every-window switch only widens what is already on.
    @Test func theDeskAnswersToTheMasterSwitchAndTheModule() {
        var config = Config()
        #expect(config.restoresPlacementsOnScreenChange && config.restoresDeskOnScreenChange)
        config.restoreEveryWindowOnScreenChange = false
        #expect(config.restoresPlacementsOnScreenChange && !config.restoresDeskOnScreenChange)
        config.restoreEveryWindowOnScreenChange = true
        config.restoreZonesOnScreenChange = false
        #expect(!config.restoresPlacementsOnScreenChange && !config.restoresDeskOnScreenChange)
        config.restoreZonesOnScreenChange = true
        config.setEnabled(.zones, false)
        #expect(!config.restoresPlacementsOnScreenChange && !config.restoresDeskOnScreenChange)
    }
}
