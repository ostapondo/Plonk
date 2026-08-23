import AppKit
import ApplicationServices
import IOKit.ps

// What starts a session on its own, and what the app is told about it.
//
// Every trigger is asked rather than caught: a Mac that slept through 09:00 and
// woke at 11:00 never fires a start timer, and would sit idle until tomorrow.
// The tick, the wake notification and the power-source callback all lead to the
// same `reevaluate`, which derives the answer from the clock, the app list and
// the charger each time.

extension AwakeManager {
    /// What the settings ask for, before the user overrides it by hand.
    var automatic: Bool { scheduleIsOpen || appIsRunning || (autoWhileCharging && isOnAC) }

    var scheduleIsOpen: Bool { schedule.contains(Date()) }

    var appIsRunning: Bool {
        guard !apps.isEmpty else { return false }
        let wanted = Set(apps.map { $0.lowercased() })
        return NSWorkspace.shared.runningApplications.contains {
            guard let id = $0.bundleIdentifier?.lowercased() else { return false }
            return wanted.contains(id)
        }
    }

    /// Whether posting events is permitted at all. Without Accessibility the
    /// keypress is dropped silently, which would look like the level simply not
    /// working. The assertion needs no grant, so only `available` is affected.
    var isTrusted: Bool { AXIsProcessTrusted() }

    var isOnAC: Bool { Self.isOnAC }

    static var isOnAC: Bool {
        // IOPSGetProvidingPowerSourceType returns "AC Power", "Battery Power" or
        // "UPS Power". A "Get" function, so the string is not ours to release.
        let type = IOPSGetProvidingPowerSourceType(nil)?.takeUnretainedValue() as String?
        return type == nil || type == "AC Power"
    }

    /// Signal 0 checks for a process without touching it. EPERM means it is
    /// alive and owned by somebody else — a job started under sudo, say —
    /// which is still alive.
    static func isRunning(_ pid: Int) -> Bool {
        errno = 0
        return kill(pid_t(pid), 0) == 0 || errno == EPERM
    }

    /// One phrase for the page, for the menu bar tooltip and for an agent
    /// asking what state this is in.
    var statusText: LocalizedStringResource {
        guard isOn else {
            if wants && !isOnAC { return .awakeStatusPausedOnBattery }
            return .awakeStatusOff
        }
        if available && !isTrusted { return .awakeStatusNoAccessibility }
        if manual == nil {
            if scheduleIsOpen { return .awakeStatusSchedule }
            if appIsRunning { return .awakeStatusApp }
            return .awakeStatusAutoCharging
        }
        if let boundPID { return .awakeStatusUntilProcess(boundPID) }
        if let end = sessionEnd { return .awakeStatusUntil(Self.clock(end)) }
        return isAvailable ? .awakeStatusAvailable : .awakeStatusOn
    }

    static func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    /// Watch the clock, the app list and the charger. Called once at startup;
    /// the timers run for the life of the app, because a window can open at any
    /// time.
    func startWatching() {
        watchTimer = Timer.common(every: Self.watchSeconds) { [weak self] in self?.reevaluate() }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // A Mac that slept through the start of the window never saw the
            // tick that would have opened it.
            self?.reevaluate()
        }
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        if let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let manager = Unmanaged<AwakeManager>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async { manager.reevaluate() }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        reevaluate()
    }
}
