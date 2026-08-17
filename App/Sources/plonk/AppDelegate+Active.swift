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
        active.schedule = store.config.activeSchedule
        active.apps = store.config.activeApps
        active.allowOnBattery = store.config.activeAllowOnBattery
        active.timeoutMinutes = store.config.activeTimeoutMinutes
        active.onChange = { [weak self] in
            guard let self else { return }
            refreshActiveModel()
            // Fires on a schedule boundary and on a battery change too, neither
            // of which writes config, so a listener would otherwise miss them.
            router?.changes.bump("active")
        }
        active.startWatching()
    }

    func refreshActiveModel() {
        model.activeOn = active.isOn
        model.activeRequested = active.wants
        model.activeStatus = active.statusText
        model.activeTrusted = active.isTrusted
        model.activeSchedule = store.config.activeSchedule
        model.activeApps = store.config.activeApps
        model.activeAllowOnBattery = store.config.activeAllowOnBattery
        model.activeTimeoutMinutes = store.config.activeTimeoutMinutes
    }

    func setActive(_ on: Bool) { active.set(on) }

    func setActiveTimeout(minutes: Int) {
        store.update { $0.activeTimeoutMinutes = minutes }
        model.activeTimeoutMinutes = minutes
        active.timeoutMinutes = minutes
    }

    func setActiveSchedule(_ schedule: ActiveSchedule) {
        store.update { $0.activeSchedule = schedule }
        model.activeSchedule = schedule
        active.schedule = schedule
    }

    func setActiveApps(_ bundleIDs: [String]) {
        store.update { $0.activeApps = bundleIDs }
        model.activeApps = bundleIDs
        active.apps = bundleIDs
    }

    func setActiveAllowOnBattery(_ on: Bool) {
        store.update { $0.activeAllowOnBattery = on }
        model.activeAllowOnBattery = on
        active.allowOnBattery = on
    }

    func openAccessibilitySettings() { PrivacySettings.openAccessibility() }
}
