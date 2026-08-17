import AppKit
import Foundation

// Stay-active wiring, and the actions the page calls.
//
// Nothing here is restored from the last run except settings: the schedule and
// the app list are what the user configured, but a hold made by hand yesterday
// says nothing about today, so stay active always starts off and lets the
// schedule decide.

extension AppDelegate {
    func setupActive() {
        active.apply(store.config)
        active.onChange = { [weak self] in
            guard let self else { return }
            refreshActiveModel()
            // Fires on a schedule boundary and on a battery change too, neither
            // of which writes config, so a listener would otherwise miss them.
            router?.changes.bump("active")
        }
        active.startWatching()
    }

    /// What the manager is doing now. The settings behind it are read off
    /// `model.config` directly, so there is nothing here to keep in step.
    func refreshActiveModel() {
        model.activeOn = active.isOn
        model.activeRequested = active.wants
        model.activeStatus = active.statusText
        model.activeTrusted = active.isTrusted
    }

    func setActive(_ on: Bool) { active.set(on) }

    func openAccessibilitySettings() { PrivacySettings.openAccessibility() }
}
