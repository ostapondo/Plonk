import AppKit
import Foundation

// Keep-awake wiring: config in, model and menu bar out.

extension AppDelegate {
    func setupAwake() {
        awake.apply(store.config)
        awake.onChange = { [weak self] in
            guard let self else { return }
            refreshAwakeModel()
            refreshStatusMenu()
            persistAwakeSession()
            // Also fires when the power source or a timeout flips it, which
            // writes no config and would otherwise never reach a listener.
            router?.changes.bump("awake")
        }
        awake.startObservingPowerSource()
        if store.config.awakeRequested {
            awake.restore(sessionEnd: store.config.awakeSessionEnd.map(Date.init(timeIntervalSince1970:)))
        }
        awake.reevaluate()
    }

    /// What the manager is doing now. The settings behind it are read off
    /// `model.config` directly, so there is nothing here to keep in step.
    func refreshAwakeModel() {
        model.awakeOn = awake.isOn
        model.awakeHeld = awake.requested
    }

    /// Keep-awake is a user decision, not a session detail, so it has to
    /// outlive a relaunch. Written only when it actually changed, since
    /// onChange also fires on every power-source event.
    private func persistAwakeSession() {
        // A pid means nothing after a relaunch — the process it named may be
        // gone, or worse, reused — so those sessions are recorded as off and
        // simply end when the app does.
        let requested = awake.boundPID == nil && awake.requested
        let end = awake.sessionEnd?.timeIntervalSince1970
        guard store.config.awakeRequested != requested || store.config.awakeSessionEnd != end else { return }
        store.update {
            $0.awakeRequested = requested
            $0.awakeSessionEnd = end
        }
    }
}
