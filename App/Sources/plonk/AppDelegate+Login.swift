import AppKit
import ServiceManagement

// The login item. macOS can refuse, so what the toggle shows is what it settled
// on rather than what it was asked for.

extension AppDelegate {
    var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
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

    func setLaunchAtLogin(_ on: Bool) {
        applyLaunchAtLogin(on)
        update(\.launchAtLogin, to: on)
        // macOS can refuse, so the toggle shows what it settled on rather than
        // what it was asked for.
        model.loginItemRegistered = isLaunchAtLoginEnabled
    }
}
