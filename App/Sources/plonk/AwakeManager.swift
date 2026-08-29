import Foundation
import IOKit.ps
import IOKit.pwr_mgt

// Pulse: one session that keeps the Mac up, and optionally keeps you shown as
// available in the apps that watch for idleness.
//
// These were two features until they were not. A power assertion stops the Mac
// sleeping without touching the idle counter Slack and Teams read, so keeping
// the Mac awake alone still left you Away; resetting that counter postpones
// idle sleep, so staying available always implied staying awake. Two switches
// for one thing, one of which silently did the other's job.
//
// So: one session with a level.
// - `.awake` holds a power assertion.
// - `.available` holds the assertion and resets the idle timer with it.
//
// And one set of ways to start that session, all of which now work at either
// level: by hand, for a number of minutes, until a wall-clock time, until a
// process exits, inside scheduled hours, while a watched app runs, or while the
// Mac is charging. Before the merge the process binding belonged to one half
// and the schedule to the other, for no reason either half could give.

final class AwakeManager {
    private var assertionID: IOPMAssertionID = 0
    private let nudge = IdleNudge()

    /// The assertion is held right now.
    private(set) var isOn = false
    /// The idle timer is being reset right now. Needs the level, Accessibility
    /// and a session that is actually holding, so it is not `available`.
    private(set) var isAvailable = false
    private(set) var sessionEnd: Date?
    /// Set while the session lasts only as long as another process does.
    private(set) var boundPID: Int?

    /// nil follows the schedule, the watched apps and the charger. A value is
    /// the user having decided by hand, and a bare hand-toggle holds until the
    /// automatic answer itself changes — switching off at lunch lasts until the
    /// scheduled window closes, not for thirty seconds until the next tick puts
    /// it back on.
    private(set) var manual: Bool?
    private var manualBaseline = false

    private var expiryTimer: Timer?
    private var processWatch: Timer?
    /// Watches the clock and the app list; owned here because an extension
    /// cannot hold a stored property. Started by `startWatching`.
    var watchTimer: Timer?
    var wakeToken: NSObjectProtocol?
    var powerSource: CFRunLoopSource?
    var onChange: (() -> Void)?

    /// How often a process-bound session checks that its process is still
    /// there. Long enough to be free, short enough that nobody notices.
    static let processPollSeconds: TimeInterval = 5
    /// How often the schedule and the app list are re-read. The window has to
    /// be noticed shortly after it opens, not on the minute.
    static let watchSeconds: TimeInterval = 30

    // Each guards on the value actually changing. `apply` hands over the whole
    // config after any setting is written, so most of these are set to what
    // they already held; re-taking the power assertion for a change to some
    // other page's setting is not something the sleep timer should feel.
    var available = false { didSet { if available != oldValue { reevaluate() } } }
    var allowOnBattery = true { didSet { if allowOnBattery != oldValue { reevaluate() } } }
    var autoWhileCharging = false { didSet { if autoWhileCharging != oldValue { reevaluate() } } }
    var schedule = AwakeSchedule() { didSet { if schedule != oldValue { reevaluate() } } }
    /// Bundle ids. The session runs while any of them is running, and only
    /// while the list is switched on: an unused list is kept, not emptied.
    var apps: [String] = [] { didSet { if apps != oldValue { reevaluate() } } }
    var appsEnabled = false { didSet { if appsEnabled != oldValue { reevaluate() } } }
    /// The feature as a whole. Off drops the hold and ignores the triggers
    /// until it is on again; both are kept, so nothing has to be set up twice.
    var enabled = true { didSet { if enabled != oldValue { reevaluate() } } }
    var keepDisplayOn = true {
        didSet {
            guard keepDisplayOn != oldValue, isOn else { return }
            releaseAssertion()
            reevaluate()
        }
    }
    var timeoutMinutes = 0

    deinit {
        stopWatching()
    }

    /// Take the settings as they now stand. Called after every config change,
    /// so it has to be cheap and safe to run when nothing it reads moved.
    func apply(_ config: Config) {
        enabled = config.isEnabled(.awake)
        available = config.awakeAvailable
        allowOnBattery = config.awakeAllowOnBattery
        autoWhileCharging = config.awakeAutoWhileCharging
        keepDisplayOn = config.awakeKeepDisplayOn
        timeoutMinutes = config.awakeTimeoutMinutes
        schedule = config.awakeSchedule
        appsEnabled = config.awakeAppsEnabled
        apps = config.awakeApps
    }

    /// What is wanted once the hand-set hold is taken into account, still
    /// before the power check. What the toggle on the page shows.
    var wants: Bool { enabled && (manual ?? automatic) }

    // MARK: - Control

    /// Start or stop a session by hand. Returns an error string when the
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
            hold(false, end: nil, pid: nil)
            return nil
        }
        if let pid {
            // pid_t is Int32, and converting anything larger traps rather than
            // failing. The API takes whatever JSON hands it.
            guard pid > 0, pid <= Int(Int32.max), Self.isRunning(pid) else {
                return "no process with pid \(pid) is running"
            }
            hold(true, end: nil, pid: pid)
            return nil
        }
        if let until {
            guard until > Date() else {
                return "\(ISO8601DateFormatter().string(from: until)) has already passed"
            }
            hold(true, end: until, pid: nil)
            return nil
        }
        let limit = minutes ?? timeoutMinutes
        hold(true,
             end: limit > 0 ? Date().addingTimeInterval(TimeInterval(limit) * 60) : nil,
             pid: nil)
        return nil
    }

    func toggle() { set(!wants) }

    /// Give the hand-set state back to the schedule, the app list and the
    /// charger.
    func endSession() {
        manual = nil
        clearSession()
        reevaluate()
    }

    /// Pick a session back up after a relaunch. An end date already in the past
    /// means the session ran out while the app was closed. Process-bound
    /// sessions are never restored — see `AppDelegate.persistAwakeSession`.
    func restore(sessionEnd end: Date?) {
        if let end, end <= Date() { return }
        hold(true, end: end, pid: nil)
    }

    private func hold(_ on: Bool, end: Date?, pid: Int?) {
        manual = on
        manualBaseline = automatic
        clearSession()
        sessionEnd = end
        boundPID = pid
        if let end {
            expiryTimer = Timer.common(at: end) { [weak self] in self?.endSession() }
        }
        if let pid {
            // Polled rather than watched with a kqueue process source: that
            // cannot register on a process belonging to another user, and its
            // failure is silent, which would leave the Mac awake for good after
            // `sudo make`. A signal-0 probe every few seconds always works, and
            // a handful of seconds either way is nothing to a power assertion.
            processWatch = Timer.common(every: Self.processPollSeconds) { [weak self] in
                guard let self, boundPID == pid else { return }
                if !Self.isRunning(pid) { endSession() }
            }
        }
        reevaluate()
    }

    private func clearSession() {
        sessionEnd = nil
        boundPID = nil
        expiryTimer?.invalidate()
        expiryTimer = nil
        processWatch?.invalidate()
        processWatch = nil
    }

    // MARK: - Doing it

    func reevaluate() {
        if let end = sessionEnd, Date() >= end {
            manual = nil
            clearSession()
        }
        // The bare hold was made against a particular automatic answer, so once
        // that answer changes it has served its purpose. A session with an end
        // of its own — a countdown, a time, a process — is not bare and ends on
        // its own terms instead.
        if manual != nil, sessionEnd == nil, boundPID == nil, automatic != manualBaseline {
            manual = nil
        }

        let shouldHold = wants && (isOnAC || allowOnBattery)
        if shouldHold && !isOn {
            takeAssertion()
        } else if !shouldHold && isOn {
            releaseAssertion()
        }

        let shouldNudge = shouldHold && available && isTrusted
        if shouldNudge && !nudge.isRunning {
            nudge.start()
        } else if !shouldNudge && nudge.isRunning {
            nudge.stop()
        }
        isAvailable = nudge.isRunning
        onChange?()
    }

    private func takeAssertion() {
        let type = keepDisplayOn ? kIOPMAssertionTypePreventUserIdleDisplaySleep
                                 : kIOPMAssertionTypePreventUserIdleSystemSleep
        let result = IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Plonk: keep awake" as CFString,
            &assertionID
        )
        isOn = (result == kIOReturnSuccess)
    }

    private func releaseAssertion() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
        isOn = false
    }
}
