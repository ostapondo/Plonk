import AppKit

// What the ruler needs from the app: the accent it draws in, the setting that
// decides what counts as an edge, somewhere to say what it copied, and Plonk's
// own windows out of the frame before it photographs anything.

extension AppDelegate {
    func setupRuler() {
        let ruler = ScreenRuler.shared
        ruler.announce = { HUD.shared.show($0) }
        // Read when the ruler opens rather than pushed at it, so the accent and
        // the tolerance are whatever settings say at that moment.
        ruler.appearance = { [weak self] in
            (self?.zoneAppearance.tint ?? .controlAccentColor,
             self?.store.config.rulerEdgeTolerance ?? EdgeDetector.defaultTolerance)
        }
        // The ruler measures a photograph of the screen, so Plonk's own windows
        // have to be out of it — a pinned crop or the crosshairs sitting over
        // the thing being measured would be measured instead.
        ruler.hideOwnWindows = { [weak self] in
            guard let self else { return {} }
            let hidden = hideOwnWindows()
            return { [weak self] in self?.showOwnWindows(hidden) }
        }
    }

    /// Whatever was measured has already been said by the HUD as it happened,
    /// so only a reason it could not run is worth reporting here. Walking away
    /// from the ruler is not one.
    func startRuler() {
        ScreenRuler.shared.begin { result in
            guard case .failure(let failure) = result, failure.isWorthSaying else { return }
            HUD.shared.show(failure.localizedDescription)
        }
    }
}
