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

    /// The hold outlives the app: a guard left running by the copy of Plonk this
    /// one replaced is adopted rather than asked for again, so an update or a
    /// relaunch costs no password. Only a launch that finds no guard at all has
    /// to put the prompt up, and only when the switch was left on.
    func setupLidSleep() {
        model.hasLid = LidSleep.hasLid
        lidSleep.adopt()
        lidSleep.onRefused = { [weak self] in self?.store.update { $0.awakeLidClosed = false } }
        lidSleep.onChange = { [weak self] in
            guard let self else { return }
            refreshStatusMenu()
            router?.changes.bump("awake")
        }
        // The password prompt this may put up is app-modal, and launch is not
        // the moment to block on one.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            lidSleep.apply(store.config)
        }
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
