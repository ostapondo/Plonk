import AppKit
import Foundation

// Keep-awake wiring: config in, model and menu bar out.

extension AppDelegate {
    func setupAwake() {
        awake.allowOnBattery = store.config.awakeAllowOnBattery
        awake.autoWhileCharging = store.config.awakeAutoWhileCharging
        awake.keepDisplayOn = store.config.awakeKeepDisplayOn
        awake.timeoutMinutes = store.config.awakeTimeoutMinutes
        awake.onChange = { [weak self] in
            guard let self else { return }
            model.awakeOn = awake.isOn
            model.awakeRequested = awake.requested
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

    func refreshAwakeModel() {
        model.awakeOn = awake.isOn
        model.awakeRequested = awake.requested
        model.awakeAllowOnBattery = store.config.awakeAllowOnBattery
        model.awakeAutoWhileCharging = store.config.awakeAutoWhileCharging
        model.awakeKeepDisplayOn = store.config.awakeKeepDisplayOn
        model.awakeTimeoutMinutes = store.config.awakeTimeoutMinutes
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
