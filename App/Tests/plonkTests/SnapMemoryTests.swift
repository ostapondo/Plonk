import ApplicationServices
import CoreGraphics
import Testing
@testable import plonk

// An AXUIElement for a process that is not being driven still has stable
// identity, which is all these exercise.
private func element(_ pid: pid_t) -> AXUIElement {
    AXUIElementCreateApplication(pid)
}

struct SnapMemoryTests {

    private let before = CGRect(x: 10, y: 20, width: 300, height: 400)
    private let half = FracRect(0, 0, 0.5, 1)

    @Test func handsBackTheFrameFromBeforeTheFirstSnap() {
        let memory = SnapMemory()
        let window = element(1)
        memory.record(window, wasAt: before, placedAt: half, screenUUID: "A")
        #expect(memory.takeOriginal(of: window) == before)
    }

    /// Snapping left then right must still restore what the window looked like
    /// before any of it, not the left half.
    @Test func laterSnapsDoNotOverwriteTheOriginal() {
        let memory = SnapMemory()
        let window = element(2)
        memory.record(window, wasAt: before, placedAt: half, screenUUID: "A")
        memory.record(window, wasAt: CGRect(x: 0, y: 0, width: 500, height: 1000),
                      placedAt: FracRect(0.5, 0, 0.5, 1), screenUUID: "A")
        #expect(memory.takeOriginal(of: window) == before)
    }

    @Test func takingTheOriginalForgetsIt() {
        let memory = SnapMemory()
        let window = element(3)
        memory.record(window, wasAt: before, placedAt: half, screenUUID: "A")
        _ = memory.takeOriginal(of: window)
        #expect(memory.takeOriginal(of: window) == nil)
    }

    @Test func anUntouchedWindowHasNothingToRestore() {
        #expect(SnapMemory().takeOriginal(of: element(4)) == nil)
    }

    @Test func laterPlacementsReplaceTheEarlierOne() {
        let memory = SnapMemory()
        let window = element(5)
        memory.record(window, wasAt: before, placedAt: half, screenUUID: "A")
        memory.record(window, wasAt: before, placedAt: FracRect(0.5, 0, 0.5, 1), screenUUID: "B")
        #expect(memory.placements.count == 1)
        #expect(memory.placements[0].screenUUID == "B")
        #expect(memory.placements[0].frac.x == 0.5)
    }

    @Test func staysBoundedAsWindowsComeAndGo() {
        let memory = SnapMemory()
        for pid in 1...200 {
            memory.record(element(pid_t(pid)), wasAt: before, placedAt: half, screenUUID: "A")
        }
        #expect(memory.placements.count <= 64)
        // The most recent survive; the oldest are the ones dropped.
        #expect(memory.takeOriginal(of: element(200)) == before)
        #expect(memory.takeOriginal(of: element(1)) == nil)
    }
}
