import AppKit

// The pointer tools and the pinned crop windows: everything drawn over the
// desktop that is not a zone.

extension AppDelegate {
    /// Drag out a region and float it above everything, live or frozen.
    func pinCrop(live: Bool) {
        let report: (Result<String, Error>) -> Void = { result in
            if case .failure(let error) = result {
                HUD.shared.show(error.localizedDescription)
            }
        }
        // Plonk's own windows would otherwise be in the shot, and the picker
        // has to be the only thing on top.
        let hidden = hideOwnWindows()
        let finish: (Result<String, Error>) -> Void = { [weak self] result in
            self?.showOwnWindows(hidden)
            report(result)
        }
        if live {
            crops.createLive(completion: finish)
        } else {
            crops.createStill(completion: finish)
        }
    }

    func setupMouseTools() {
        applyMouseSettings()
    }

    /// Same rule as grab-and-move: no tap unless something needs one. Finding
    /// the pointer is a shortcut and draws without watching anything.
    func applyMouseSettings() {
        mouse.highlightEnabled = store.config.highlightClicksEnabled
        mouse.crosshairsEnabled = store.config.crosshairsEnabled
        mouse.tint = zoneAppearance.tint
        if store.config.highlightClicksEnabled || store.config.crosshairsEnabled {
            mouse.start()
        } else {
            mouse.stop()
        }
    }
}
