import AppKit
import CoreGraphics
import Foundation

// Stay active: keep the system idle timer at zero, so chat apps go on showing
// you as available.
//
// This is the one place in Plonk that fakes input, and it does so because there
// is no other way. Slack and Teams read the seconds since the last HID event
// (`powerMonitor.getSystemIdleTime` and what sits under it); a power assertion
// like AwakeManager's stops the Mac sleeping without touching that counter, so
// keep-awake alone still leaves you Away. Only an event resets it.
//
// A consequence worth knowing rather than discovering: resetting the idle timer
// also postpones idle sleep and the screen saver. Stay active implies keep
// awake, not the other way round.

final class ActiveManager {
    private(set) var isOn = false
    private(set) var sessionEnd: Date?
    var onChange: (() -> Void)?

    /// How often the idle timer is reset. Teams gives up after about five
    /// minutes and Slack after ten, so two minutes clears both with room for a
    /// missed tick.
    private static let nudgeSeconds: TimeInterval = 120
    /// How often the schedule and the app list are re-read. The window has to
    /// be noticed shortly after it opens, not on the minute.
    private static let watchSeconds: TimeInterval = 30

    /// Shift, chosen because it changes nothing on its own: it types no
    /// character, moves no cursor and cannot disturb a drag the way a synthetic
    /// mouse move would.
    private static let shiftKey: CGKeyCode = 56

    // Guarded on the value changing, because `apply` re-sends the whole config
    // after any setting is written and a hold made by hand must survive that.
    var schedule = ActiveSchedule() { didSet { if schedule != oldValue { reevaluate() } } }
    /// Bundle ids. Stay active runs while any of them is running.
    var apps: [String] = [] { didSet { if apps != oldValue { reevaluate() } } }
    var allowOnBattery = false { didSet { if allowOnBattery != oldValue { reevaluate() } } }
    var timeoutMinutes = 0

    /// Take the settings as they now stand. Called after every config change.
    func apply(_ config: Config) {
        schedule = config.activeSchedule
        apps = config.activeApps
        allowOnBattery = config.activeAllowOnBattery
        timeoutMinutes = config.activeTimeoutMinutes
    }

    /// nil follows the schedule and the app list. A value is the user having
    /// decided by hand, and it holds until the automatic answer itself changes
    /// — switching off at lunch lasts until the window closes, not for ten
    /// seconds until the next tick puts it back on.
    private(set) var manual: Bool?
    private var manualBaseline = false

    private var nudgeTimer: Timer?
    private var watchTimer: Timer?
    private var expiryTimer: Timer?

    /// Whether posting events is permitted at all. Without Accessibility the
    /// events are dropped silently, which would look like the feature simply
    /// not working.
    var isTrusted: Bool { AXIsProcessTrusted() }

    var isOnAC: Bool { AwakeManager.isOnAC }

    /// One phrase for the page and for an agent asking what state this is in.
    var statusText: LocalizedStringResource {
        if !isTrusted { return .activeStatusNoAccessibility }
        guard isOn else {
            if wants && !isOnAC { return .activeStatusPausedOnBattery }
            return .activeStatusOff
        }
        if manual == nil {
            return scheduleIsOpen ? .activeStatusSchedule : .activeStatusApp
        }
        if let end = sessionEnd { return .activeStatusUntil(Self.clock(end)) }
        return .activeStatusOn
    }

    private static func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - Wanting to run

    private var scheduleIsOpen: Bool { schedule.contains(Date()) }

    private var appIsRunning: Bool {
        guard !apps.isEmpty else { return false }
        let wanted = Set(apps.map { $0.lowercased() })
        return NSWorkspace.shared.runningApplications.contains {
            guard let id = $0.bundleIdentifier?.lowercased() else { return false }
            return wanted.contains(id)
        }
    }

    /// What the settings ask for, before the user overrides it by hand.
    private var automatic: Bool { scheduleIsOpen || appIsRunning }

    /// What is wanted once the manual hold is taken into account, still before
    /// the power check. What the toggle on the page shows.
    var wants: Bool { manual ?? automatic }

    // MARK: - Control

    /// Turn stay-active on or off by hand. `minutes` overrides the configured
    /// timeout for this session; nil uses it, 0 means no limit.
    @discardableResult
    func set(_ on: Bool, minutes: Int? = nil, until: Date? = nil) -> String? {
        if on, let until {
            guard until > Date() else {
                return "\(ISO8601DateFormatter().string(from: until)) has already passed"
            }
            hold(on, end: until)
            return nil
        }
        let limit = minutes ?? timeoutMinutes
        hold(on, end: on && limit > 0 ? Date().addingTimeInterval(TimeInterval(limit) * 60) : nil)
        return nil
    }

    /// Give the hand-set state back to the schedule.
    func clearManual() {
        manual = nil
        sessionEnd = nil
        expiryTimer?.invalidate()
        expiryTimer = nil
        reevaluate()
    }

    func toggle() { set(!wants) }

    private func hold(_ on: Bool, end: Date?) {
        manual = on
        manualBaseline = automatic
        sessionEnd = end
        expiryTimer?.invalidate()
        expiryTimer = nil
        if let end {
            let timer = Timer(fire: end, interval: 0, repeats: false) { [weak self] _ in
                self?.clearManual()
            }
            RunLoop.main.add(timer, forMode: .common)
            expiryTimer = timer
        }
        reevaluate()
    }

    /// Watch the clock and the app list. Called once at startup; the timer runs
    /// for the life of the app, because the schedule can open at any time.
    func startWatching() {
        let timer = Timer(timeInterval: Self.watchSeconds, repeats: true) { [weak self] _ in
            self?.reevaluate()
        }
        RunLoop.main.add(timer, forMode: .common)
        watchTimer = timer
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // A Mac that slept through the start of the window never saw the
            // tick that would have opened it.
            self?.reevaluate()
        }
        reevaluate()
    }

    func reevaluate() {
        if let end = sessionEnd, Date() >= end {
            manual = nil
            sessionEnd = nil
        }
        // The hold was against a particular automatic answer. Once that answer
        // changes the hold has served its purpose and the schedule takes over.
        if manual != nil, automatic != manualBaseline { manual = nil }

        let shouldRun = wants && (isOnAC || allowOnBattery) && isTrusted
        if shouldRun && !isOn {
            isOn = true
            nudge()
            let timer = Timer(timeInterval: Self.nudgeSeconds, repeats: true) { [weak self] _ in
                self?.nudge()
            }
            RunLoop.main.add(timer, forMode: .common)
            nudgeTimer = timer
        } else if !shouldRun && isOn {
            isOn = false
            nudgeTimer?.invalidate()
            nudgeTimer = nil
        }
        onChange?()
    }

    // MARK: - The event

    /// Reset the idle counter. Posted to the HID tap rather than the session
    /// tap: the session tap inserts the event above the HID layer, where it
    /// reaches applications but does not necessarily count as user activity.
    private func nudge() {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source,
                                 virtualKey: Self.shiftKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source,
                               virtualKey: Self.shiftKey, keyDown: false)
        else { return }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    /// Seconds since the last input event, real or posted here. What the chat
    /// apps read, and the only way to tell whether any of this works.
    static var systemIdleSeconds: Double {
        guard let any = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: any)
    }
}
