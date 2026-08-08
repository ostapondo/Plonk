import Foundation
import IOKit.ps
import IOKit.pwr_mgt

// Keep-awake, with rules:
// - manual sessions, optionally time-limited or ending at a wall-clock time
// - or bound to a process, ending the moment that process does
// - can be disallowed on battery (pauses until plugged back in)
// - can engage automatically while charging
// - holds either a display assertion or a system-only assertion

final class AwakeManager {
    private var assertionID: IOPMAssertionID = 0
    private(set) var isOn = false          // assertion currently held
    private(set) var requested = false     // user/agent asked for keep-awake
    private(set) var sessionEnd: Date?
    /// Set while the session lasts only as long as another process does.
    private(set) var boundPID: Int?
    private var expiryTimer: Timer?
    private var processWatch: Timer?
    var onChange: (() -> Void)?

    /// How often a process-bound session checks that its process is still
    /// there. Long enough to be free, short enough that nobody notices.
    private static let processPollSeconds: TimeInterval = 5

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
        if isOn {
            guard requested else { return "auto (charging)" }
            if let boundPID { return "on until process \(boundPID) exits" }
            return "on"
        }
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

    /// Start or stop a keep-awake session. Returns an error string when the
    /// request cannot be honoured, nil otherwise.
    ///
    /// - `minutes` overrides the configured default timeout for this session;
    ///   nil uses it, 0 means no limit.
    /// - `until` ends it at a wall-clock moment instead, and wins over minutes.
    /// - `pid` ends it when that process exits, and wins over both: a build or
    ///   a render knows when it is finished better than a guess at how long it
    ///   will take.
    @discardableResult
    func set(_ on: Bool, minutes: Int? = nil, until: Date? = nil, pid: Int? = nil) -> String? {
        guard on else {
            begin(requested: false, sessionEnd: nil, pid: nil)
            return nil
        }
        if let pid {
            guard pid > 0, Self.isRunning(pid) else {
                return "no process with pid \(pid) is running"
            }
            begin(requested: true, sessionEnd: nil, pid: pid)
            return nil
        }
        if let until {
            guard until > Date() else {
                return "\(ISO8601DateFormatter().string(from: until)) has already passed"
            }
            begin(requested: true, sessionEnd: until, pid: nil)
            return nil
        }
        let limit = minutes ?? timeoutMinutes
        begin(requested: true,
              sessionEnd: limit > 0 ? Date().addingTimeInterval(TimeInterval(limit) * 60) : nil,
              pid: nil)
        return nil
    }

    /// Pick a session back up after a relaunch. An end date already in the past
    /// means the session ran out while the app was closed. Process-bound
    /// sessions are never restored — see `AppDelegate.persistAwakeSession`.
    func restore(sessionEnd end: Date?) {
        if let end, end <= Date() { return }
        begin(requested: true, sessionEnd: end, pid: nil)
    }

    /// Signal 0 checks for a process without touching it. EPERM means it is
    /// alive and owned by somebody else — a job started under sudo, say —
    /// which is still alive.
    private static func isRunning(_ pid: Int) -> Bool {
        errno = 0
        return kill(pid_t(pid), 0) == 0 || errno == EPERM
    }

    private func begin(requested on: Bool, sessionEnd end: Date?, pid: Int?) {
        requested = on
        expiryTimer?.invalidate()
        expiryTimer = nil
        processWatch?.invalidate()
        processWatch = nil
        boundPID = pid
        sessionEnd = end
        if let end {
            let timer = Timer(fire: end, interval: 0, repeats: false) { [weak self] _ in
                self?.reevaluate()
            }
            RunLoop.main.add(timer, forMode: .common)
            expiryTimer = timer
        }
        if let pid {
            // Polled rather than watched with a kqueue process source: that
            // cannot register on a process belonging to another user, and its
            // failure is silent, which would leave the Mac awake for good after
            // `sudo make`. A signal-0 probe every few seconds always works, and
            // a handful of seconds either way is nothing to a power assertion.
            let timer = Timer(timeInterval: Self.processPollSeconds, repeats: true) { [weak self] _ in
                guard let self, boundPID == pid else { return }
                if !Self.isRunning(pid) { set(false) }
            }
            RunLoop.main.add(timer, forMode: .common)
            processWatch = timer
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
            processWatch?.invalidate()
            processWatch = nil
            boundPID = nil
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
