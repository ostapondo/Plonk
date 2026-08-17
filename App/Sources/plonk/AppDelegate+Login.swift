import AppKit
import ServiceManagement

// The login item. macOS can refuse, so what the toggle shows is what it settled
// on rather than what it was asked for.

extension AppDelegate {
    var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Make the login item match `config.launchAtLogin`. Asking macOS is an
    /// XPC round trip and this runs after every write, so it only asks when
    /// the setting itself moved (or at launch, when nothing has been applied
    /// yet). A refusal shows on the toggle; turning it off and on asks again.
    func applyLoginItem(_ config: Config, previous: Config?) {
        guard previous?.launchAtLogin != config.launchAtLogin else { return }
        applyLaunchAtLogin(config.launchAtLogin)
        model.loginItemRegistered = isLaunchAtLoginEnabled
    }

    /// Registers the app bundle as a login item. Fails silently when the app
    /// runs unbundled (swift run), where there is nothing to register.
    func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Plonk: login item update failed: \(error)")
        }
    }
}
