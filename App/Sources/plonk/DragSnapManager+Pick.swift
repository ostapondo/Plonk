import AppKit
import ApplicationServices

// The zones as things to click. Hold ⌃⌥Z and every screen's zones come up
// and stay up; click one, or press its digit, and the window that was in
// front goes there. Let go and they linger a moment, still clickable, then
// go. A tap of the key is the flash it always was.

extension DragSnapManager {
    /// How long the zones stay up after the key comes back up.
    static let pickLinger: TimeInterval = 1.5

    /// `target` is the window that was in front when the key went down, so
    /// clicking a zone over another app's window still moves the right one.
    /// Nil, for an excluded app or nothing in front, makes this the plain
    /// flash: the zones are drawn and nothing is waiting to be clicked.
    func beginPick(target: AXUIElement?) {
        previewGeneration += 1
        pickTarget = target
        for (index, screen) in NSScreen.screens.enumerated() {
            let zones = zonesForScreen?(index) ?? []
            guard !zones.isEmpty else { continue }
            let overlay = overlay(for: index)
            overlay.onPick = { [weak self] zone in self?.pick(zone: zone, on: index) }
            overlay.onHover = { [weak self] zone in self?.hover(zone: zone, on: index) }
            overlay.interactive = target != nil
            overlay.show(zones: zones, highlighted: [], visible: screen.visibleFrame,
                         appearance: look(on: index))
        }
    }

    /// The key came back up: the zones stay a moment longer, still clickable.
    func endPick() {
        let generation = previewGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.pickLinger) { [weak self] in
            guard let self, previewGeneration == generation else { return }
            cancelPick()
        }
    }

    /// The zones go, and stop listening. Also what a digit pressed while they
    /// are up does, once its zone has taken the window.
    func cancelPick() {
        previewGeneration += 1
        pickTarget = nil
        for overlay in overlays.values {
            overlay.interactive = false
            overlay.onPick = nil
            overlay.onHover = nil
        }
        hideUnlessDragging()
    }

    private func pick(zone: Int, on screenIndex: Int) {
        guard let target = pickTarget, let zones = zonesForScreen?(screenIndex),
              zones.indices.contains(zone) else { return }
        let frac = zones[zone].frac
        let before = windows.frame(ofWindow: target) ?? .zero
        windows.apply(frac: frac, toWindow: target, screenIndex: screenIndex, gap: look(on: screenIndex).gap)
        onSnap?(target, before, frac, screenIndex)
        cancelPick()
        // The click landed on the overlay, so the window it was for is
        // brought back in front of whatever it was over.
        if let app = windows.app(ofWindow: target) { windows.focus(target, of: app) }
    }

    private func hover(zone: Int?, on screenIndex: Int) {
        guard pickTarget != nil, NSScreen.screens.indices.contains(screenIndex),
              let zones = zonesForScreen?(screenIndex), !zones.isEmpty else { return }
        overlay(for: screenIndex).show(zones: zones, highlighted: Set(zone.map { [$0] } ?? []),
                                       visible: NSScreen.screens[screenIndex].visibleFrame,
                                       appearance: look(on: screenIndex))
    }
}
