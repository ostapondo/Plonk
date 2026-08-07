import Foundation
import IOKit.ps
import IOKit.pwr_mgt

// Keep-awake, with rules:
// - manual sessions, optionally time-limited
// - can be disallowed on battery (pauses until plugged back in)
// - can engage automatically while charging
// - holds either a display assertion or a system-only assertion

final class AwakeManager {
    private var assertionID: IOPMAssertionID = 0
    private(set) var isOn = false          // assertion currently held
    private(set) var requested = false     // user/agent asked for keep-awake
    private(set) var sessionEnd: Date?
    private var expiryTimer: Timer?
    var onChange: (() -> Void)?

    var allowOnBattery = true { didSet { reevaluate() } }
    var autoWhileCharging = false { didSet { reevaluate() } }
    var keepDisplayOn = true {
        didSet { if isOn { releaseAssertion(); reevaluate() } }
    }
    var timeoutMinutes = 0

    var isOnAC: Bool {
        // IOPSGetProvidingPowerSourceType returns "AC Power", "Battery Power" or "UPS Power".
        let type = IOPSGetProvidingPowerSourceType(nil)?.takeRetainedValue() as String?
        return type == nil || type == "AC Power"
    }

    var statusText: String {
        if isOn { return requested ? "on" : "auto (charging)" }
        if requested { return "paused on battery" }
        return "off"
    }

    func startObservingPowerSource() {
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        if let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let manager = Unmanaged<AwakeManager>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async { manager.reevaluate() }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    /// Start or stop a keep-awake session. `minutes` overrides the configured
    /// default timeout for this session; nil uses it, 0 means no limit.
    func set(_ on: Bool, minutes: Int? = nil) {
        let limit = minutes ?? timeoutMinutes
        let end = on && limit > 0 ? Date().addingTimeInterval(TimeInterval(limit) * 60) : nil
        begin(requested: on, sessionEnd: end)
    }

    /// Pick a session back up after a relaunch. An end date already in the past
    /// means the session ran out while the app was closed.
    func restore(sessionEnd end: Date?) {
        if let end, end <= Date() { return }
        begin(requested: true, sessionEnd: end)
    }

    private func begin(requested on: Bool, sessionEnd end: Date?) {
        requested = on
        expiryTimer?.invalidate()
        expiryTimer = nil
        sessionEnd = end
        if let end {
            let timer = Timer(fire: end, interval: 0, repeats: false) { [weak self] _ in
                self?.reevaluate()
            }
            RunLoop.main.add(timer, forMode: .common)
            expiryTimer = timer
        }
        reevaluate()
    }

    func toggle() { set(!requested) }

    func reevaluate() {
        if let end = sessionEnd, Date() >= end {
            requested = false
            sessionEnd = nil
            expiryTimer?.invalidate()
            expiryTimer = nil
        }
        let ac = isOnAC
        let shouldHold = (requested && (ac || allowOnBattery)) || (autoWhileCharging && ac)
        if shouldHold && !isOn {
            let type = keepDisplayOn ? kIOPMAssertionTypePreventUserIdleDisplaySleep
                                     : kIOPMAssertionTypePreventUserIdleSystemSleep
            let result = IOPMAssertionCreateWithName(
                type as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Plonk: keep awake" as CFString,
                &assertionID
            )
            isOn = (result == kIOReturnSuccess)
        } else if !shouldHold && isOn {
            releaseAssertion()
        }
        onChange?()
    }

    private func releaseAssertion() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
        isOn = false
    }
}
