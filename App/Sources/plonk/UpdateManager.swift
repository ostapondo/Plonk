import AppKit
import CryptoKit
import Security

// Checks GitHub for a newer release and, when the user asks, installs it.
//
// The one place in the app that opens an outbound connection. It talks to
// api.github.com and the release asset's host, sends no identifier beyond a
// User-Agent naming the app and its version, and does nothing at all when the
// user turns the check off.
//
// Every step off the happy path leaves the installed copy exactly as it was:
// nothing is swapped in until the download has been unpacked, matched against
// the release that was offered, and checked against this copy's own signature.

final class UpdateManager {

    enum Phase: String {
        case idle, checking, available, downloading, verifying, installing, failed
    }

    private(set) var phase: Phase = .idle
    private(set) var latest: Release?
    /// One line for the UI, always in step with `phase`.
    private(set) var status: LocalizedStringResource = ""
    var progress: Double = 0

    /// Fires on the main queue when the phase or the status text changes.
    var onChange: (() -> Void)?
    /// Fires on the main queue as bytes arrive, and only for that. It is kept
    /// apart from onChange because a download reports progress hundreds of
    /// times and every onChange bumps the change bus, which does not coalesce:
    /// one update would bury every listener on /events under its own progress.
    var onProgress: (() -> Void)?
    /// Whether launch and the schedule check on their own. The user's
    /// setting; a check they ask for explicitly always runs. Off until
    /// applied, the same as the schedule behind it, so the first apply of an
    /// "on" reaches it.
    var automatic = false {
        didSet { if automatic != oldValue { schedule.automatic = automatic } }
    }

    /// Take the settings as they now stand. `automatic` guards on the value
    /// changing, because turning the schedule on restarts its countdown.
    func apply(_ config: Config) {
        automatic = config.updateCheckAutomatically
    }

    let session: URLSession
    private let schedule = UpdateSchedule()
    var observation: NSKeyValueObservation?
    var inFlight = false

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 600
        config.httpAdditionalHeaders = [
            "Accept": "application/vnd.github+json",
            "User-Agent": "Plonk/\(UpdateManager.currentVersionText)",
        ]
        session = URLSession(configuration: config)
        schedule.onDue = { [weak self] in self?.check() }
    }

    deinit {
        observation?.invalidate()
    }

    // MARK: - Version

    static var currentVersionText: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static var currentVersion: ReleaseVersion? {
        ReleaseVersion(currentVersionText)
    }

    /// The newer release, when there is one to offer.
    var available: Release? {
        UpdateDecision.offering(running: Self.currentVersion, latest: latest).offered
    }

    // MARK: - Checking

    func start() {
        guard automatic else { return }
        check()
    }

    func check() {
        guard !inFlight else { return }
        inFlight = true
        set(phase: .checking, status: .updateChecking)

        let task = session.dataTask(with: Release.latestURL) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                finish(UpdateError.network(error.localizedDescription))
                return
            }
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(code), let data else {
                finish(UpdateError.network("GitHub answered \(code)"))
                return
            }
            do {
                let release = try Release.parse(data)
                DispatchQueue.main.async { [weak self] in self?.offer(release) }
            } catch {
                finish(error)
            }
        }
        task.resume()
    }

    private func offer(_ release: Release) {
        latest = release
        inFlight = false
        guard case .offer = UpdateDecision.offering(running: Self.currentVersion, latest: release) else {
            set(phase: .idle, status: .updateUpToDate(Self.currentVersionText))
            return
        }
        set(phase: .available, status: .updateIsAvailable(release.version.text))
    }

    // MARK: - State

    /// Every failure lands here, and every failure frees the manager to try
    /// again — a check that gave up still leaves the app usable.
    func finish(_ error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        var offline = false
        if case UpdateError.network = error { offline = true }
        set(phase: .failed, status: "\(message)", offline: offline)
    }

    /// `offline` marks the one failure the schedule can undo on its own, and
    /// every other call clears it: whatever a check ends up saying, it is the
    /// current answer, and the network coming back does not change it.
    func set(phase: Phase, status: LocalizedStringResource, offline: Bool = false) {
        let apply = { [weak self] in
            guard let self else { return }
            if phase == .failed { inFlight = false }
            schedule.awaitingNetwork = offline
            self.phase = phase
            self.status = status
            onChange?()
        }
        Thread.isMainThread ? apply() : DispatchQueue.main.async(execute: apply)
    }
}
