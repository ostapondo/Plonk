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
    private(set) var status = ""
    private(set) var progress: Double = 0

    /// Fires on the main queue when the phase or the status text changes.
    var onChange: (() -> Void)?
    /// Fires on the main queue as bytes arrive, and only for that. It is kept
    /// apart from onChange because a download reports progress hundreds of
    /// times and every onChange bumps the change bus, which does not coalesce:
    /// one update would bury every listener on /events under its own progress.
    var onProgress: (() -> Void)?
    /// Whether launch and the daily timer check on their own. The user's
    /// setting; a check they ask for explicitly always runs.
    var automatic = true {
        didSet { scheduleAutomaticCheck() }
    }

    private let session: URLSession
    private var timer: Timer?
    private var observation: NSKeyValueObservation?
    private var inFlight = false

    private static let checkInterval: TimeInterval = 24 * 60 * 60

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 600
        config.httpAdditionalHeaders = [
            "Accept": "application/vnd.github+json",
            "User-Agent": "Plonk/\(UpdateManager.currentVersionText)",
        ]
        session = URLSession(configuration: config)
    }

    deinit {
        timer?.invalidate()
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
        guard let latest, let current = Self.currentVersion, current < latest.version else { return nil }
        return latest
    }

    // MARK: - Checking

    func start() {
        scheduleAutomaticCheck()
        guard automatic else { return }
        check()
    }

    private func scheduleAutomaticCheck() {
        timer?.invalidate()
        timer = nil
        guard automatic else { return }
        let timer = Timer(timeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            self?.check()
        }
        timer.tolerance = 60 * 60
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func check() {
        guard !inFlight else { return }
        inFlight = true
        set(phase: .checking, status: "Checking for updates…")

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
        guard let current = Self.currentVersion, current < release.version else {
            set(phase: .idle, status: "Plonk \(Self.currentVersionText) is the latest release.")
            return
        }
        set(phase: .available, status: "Plonk \(release.version) is available.")
    }

    // MARK: - Installing

    /// Downloads the newer release, checks it, and swaps it in. The app quits
    /// on success — the swap happens once it is gone, and the new copy is
    /// launched by the script that did it.
    func install() {
        guard let release = available else {
            check()
            return
        }
        // The route has already answered "installing"; going quiet here would
        // leave the caller waiting for a relaunch that is never coming.
        guard !inFlight else {
            set(phase: .failed, status: "A check is still running. Try again in a moment.")
            return
        }
        do {
            let installed = try installedBundleURL()
            guard !CodeSignature.selfIsAdHoc() else { throw UpdateError.adHocCopy }
            let requirement = try CodeSignature.selfRequirement()
            inFlight = true
            progress = 0
            set(phase: .downloading, status: "Downloading Plonk \(release.version)…")
            download(release) { [weak self] result in
                guard let self else { return }
                switch result {
                case .failure(let error):
                    finish(error)
                case .success(let archive):
                    stage(archive, of: release, requirement: requirement, into: installed)
                }
            }
        } catch {
            finish(error)
        }
    }

    private func download(_ release: Release, completion: @escaping (Result<URL, Error>) -> Void) {
        let task = session.downloadTask(with: release.downloadURL) { location, response, error in
            if let error { return completion(.failure(UpdateError.network(error.localizedDescription))) }
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(code), let location else {
                return completion(.failure(UpdateError.network("the download answered \(code)")))
            }
            // The temporary file is deleted the moment this returns, so it has
            // to be moved somewhere of our own first.
            let keep = FileManager.default.temporaryDirectory
                .appendingPathComponent("plonk-update-\(UUID().uuidString).zip")
            do {
                try FileManager.default.moveItem(at: location, to: keep)
                completion(.success(keep))
            } catch {
                completion(.failure(UpdateError.unpackFailed(error.localizedDescription)))
            }
        }
        observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            DispatchQueue.main.async {
                guard let self, self.phase == .downloading else { return }
                self.progress = progress.fractionCompleted
                self.onProgress?()
            }
        }
        task.resume()
    }

    /// Unpacks, checks, and hands over to the swap script. Runs off the main
    /// queue: it waits on `ditto` and on the signature check, and the main
    /// queue is where the routes are answered.
    private func stage(_ archive: URL, of release: Release,
                       requirement: SecRequirement, into installed: URL) {
        DispatchQueue.main.async { [weak self] in
            self?.set(phase: .verifying, status: "Checking the download…")
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("plonk-update-\(UUID().uuidString)", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: archive) }
            do {
                try checkDigest(of: archive, matches: release)
                try unpack(archive, into: directory)
                let staged = directory.appendingPathComponent(installed.lastPathComponent)
                try checkPayload(at: staged, matches: release)
                try CodeSignature.verify(bundleAt: staged, satisfies: requirement)
                DispatchQueue.main.async { [weak self] in
                    self?.swap(staged, into: installed)
                }
            } catch {
                try? FileManager.default.removeItem(at: directory)
                finish(error)
            }
        }
    }

    /// The cheapest check there is, and the first one: the bytes on disk have
    /// to be the bytes the feed described. It runs before `ditto` is handed
    /// the archive, so a download that went wrong on the way is never unpacked
    /// at all. Releases cut before GitHub published a digest carry none, and
    /// those fall through to the signature check exactly as they used to.
    private func checkDigest(of archive: URL, matches release: Release) throws {
        guard let expected = release.digest else { return }
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: archive)
        } catch {
            throw UpdateError.unpackFailed(error.localizedDescription)
        }
        defer { try? handle.close() }
        // Hashed in chunks rather than read whole: the archive is the entire
        // app, and this runs on a machine already busy launching one.
        var hasher = SHA256()
        while let chunk = try? handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        let actual = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        guard actual == expected else { throw UpdateError.digestMismatch }
    }

    private func unpack(_ archive: URL, into directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // ditto, not an unzip of our own: it is what made the archive, and it
        // is the only unpacker that keeps a bundle's signature intact.
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        task.arguments = ["-x", "-k", archive.path, directory.path]
        try task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            throw UpdateError.unpackFailed("ditto exited with \(task.terminationStatus)")
        }
    }

    /// The archive has to hold the app we were offered, at the version we were
    /// offered. Without this a stale or mismatched asset would pass the
    /// signature check on its way to being installed as an "update".
    private func checkPayload(at staged: URL, matches release: Release) throws {
        guard FileManager.default.fileExists(atPath: staged.path) else {
            throw UpdateError.wrongPayload("it holds no \(staged.lastPathComponent)")
        }
        guard let bundle = Bundle(url: staged),
              let identifier = bundle.bundleIdentifier,
              identifier == Bundle.main.bundleIdentifier else {
            throw UpdateError.wrongPayload("its bundle identifier is not \(Bundle.main.bundleIdentifier ?? "ours")")
        }
        let shipped = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        guard let version = ReleaseVersion(shipped), version == release.version else {
            throw UpdateError.wrongPayload("it contains \(shipped), not \(release.version)")
        }
    }

    private func swap(_ staged: URL, into installed: URL) {
        set(phase: .installing, status: "Installing…")
        // On the way out the script deletes the staged bundle; if we never get
        // that far, an unpacked copy of the whole app would sit in temp until
        // the next reboot, once per attempt.
        let staging = staged.deletingLastPathComponent()
        do {
            let script = FileManager.default.temporaryDirectory
                .appendingPathComponent("plonk-install-\(UUID().uuidString).sh")
            try Release.installScript.write(to: script, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)

            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/sh")
            task.arguments = [script.path, String(ProcessInfo.processInfo.processIdentifier),
                              staged.path, installed.path]
            try task.run()
        } catch {
            try? FileManager.default.removeItem(at: staging)
            finish(error)
            return
        }
        // The script is waiting on this process to go away.
        NSApp.terminate(nil)
    }

    private func installedBundleURL() throws -> URL {
        let url = Bundle.main.bundleURL
        guard url.pathExtension == "app" else { throw UpdateError.notInstalled }
        let parent = url.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: url.path),
              FileManager.default.isWritableFile(atPath: parent.path) else {
            throw UpdateError.notWritable(parent.path)
        }
        return url
    }

    // MARK: - State

    /// Every failure lands here, and every failure frees the manager to try
    /// again — a check that gave up still leaves the app usable.
    private func finish(_ error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        set(phase: .failed, status: message)
    }

    private func set(phase: Phase, status: String) {
        let apply = { [weak self] in
            guard let self else { return }
            if phase == .failed { inFlight = false }
            self.phase = phase
            self.status = status
            onChange?()
        }
        Thread.isMainThread ? apply() : DispatchQueue.main.async(execute: apply)
    }
}
