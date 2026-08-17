import Foundation
import Network

// When a check runs without the user asking for one. UpdateManager does the
// asking; this decides when, and it is the only thing in the app that watches
// the network path.
//
// Both halves are off together: with automatic checks turned off there is no
// timer and no monitor, so the buttons on the update page stay the only way a
// connection is opened.

/// A path change, weighed against what the updater is waiting for. The monitor
/// reports every change — a Wi-Fi hop, a VPN coming up, a cable pulled — and
/// almost none of them are worth another check.
struct ConnectivityChange: Equatable {
    /// Whether a request could go out now.
    let isSatisfied: Bool
    /// Whether the last check gave up for want of a network. A feed that
    /// answered badly is a different problem, and changing Wi-Fi does not fix
    /// it: only this failure is worth retrying on the network coming back.
    let awaitingNetwork: Bool
    /// The user's setting.
    let automatic: Bool

    var warrantsCheck: Bool { isSatisfied && awaitingNetwork && automatic }
}

final class UpdateSchedule {

    /// Fires on the main queue when a check is due.
    var onDue: (() -> Void)?

    /// Guarded on the value changing. `start` restarts the countdown from
    /// zero, and applyConfig re-sends every setting after each write, so an
    /// unguarded assignment here would mean a Mac whose settings are touched
    /// once a day never reaches the deadline and never checks at all.
    var automatic = false {
        didSet {
            guard automatic != oldValue else { return }
            automatic ? start() : stop()
        }
    }

    /// Set when a check gives up with a network error, cleared by the next
    /// check whatever becomes of it. Without it the daily timer is the whole
    /// recovery: a copy that launched with the Wi-Fi off would sit on "the
    /// Internet connection appears to be offline" for a day after it came back.
    var awaitingNetwork = false

    private var timer: Timer?
    private var monitor: NWPathMonitor?

    private static let interval: TimeInterval = 24 * 60 * 60

    deinit { stop() }

    private func start() {
        stop()
        let timer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            self?.onDue?()
        }
        timer.tolerance = 60 * 60
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        // A cancelled monitor cannot be restarted, so turning the setting back
        // on gets one of its own rather than reusing the old one.
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let satisfied = path.status == .satisfied
            DispatchQueue.main.async { self?.networkChanged(satisfied: satisfied) }
        }
        monitor.start(queue: DispatchQueue.global(qos: .utility))
        self.monitor = monitor
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        monitor?.cancel()
        monitor = nil
    }

    private func networkChanged(satisfied: Bool) {
        let change = ConnectivityChange(isSatisfied: satisfied,
                                        awaitingNetwork: awaitingNetwork,
                                        automatic: automatic)
        guard change.warrantsCheck else { return }
        // The check clears this too, on the way to reporting what it found.
        // Clearing it here as well is what keeps the next path change — the
        // rest of a reconnection arriving as several — from queueing more.
        awaitingNetwork = false
        onDue?()
    }
}
