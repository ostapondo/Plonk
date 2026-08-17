import AppKit
import CryptoKit
import Security

// Downloading a release and swapping it in.
//
// Every step off the happy path leaves the installed copy exactly as it was:
// nothing is swapped in until the download has been unpacked, matched against
// the release that was offered, and checked against this copy's own signature.
//
// The state it reads and writes is not private only because the type is split
// across two files; nothing outside UpdateManager should touch it.

extension UpdateManager {
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
            set(phase: .failed, status: .updateCheckRunning)
            return
        }
        do {
            let installed = Bundle.main.bundleURL
            if let refusal = UpdateDecision.preflight(installedCopy(at: installed)).refusal { throw refusal }
            let requirement = try CodeSignature.selfRequirement()
            inFlight = true
            progress = 0
            set(phase: .downloading, status: .updateDownloading(release.version.text))
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
            self?.set(phase: .verifying, status: .updateVerifying)
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("plonk-update-\(UUID().uuidString)", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: archive) }
            let ours = Bundle.main.bundleIdentifier
            do {
                // Each step fills in one more field and asks again, so the first
                // refusal stops the step below it from ever running.
                var verification = VerificationResult()
                verification.digestMatched = try digestMatches(archive, of: release)
                try verification.checked(against: release, identifier: ours)
                try unpack(archive, into: directory)
                let staged = directory.appendingPathComponent(installed.lastPathComponent)
                verification.payload = readPayload(at: staged)
                try verification.checked(against: release, identifier: ours)
                verification.signature = CodeSignature.check(bundleAt: staged, satisfies: requirement)
                if case .install = try verification.checked(against: release, identifier: ours) {
                    DispatchQueue.main.async { [weak self] in self?.swap(staged, into: installed) }
                }
            } catch {
                try? FileManager.default.removeItem(at: directory)
                finish(error)
            }
        }
    }

    /// The cheapest check there is, and the first one: the bytes on disk have
    /// to be the bytes the feed described. It runs before `ditto` is handed the
    /// archive, so a download that went wrong on the way is never unpacked at
    /// all. Releases cut before GitHub published a digest carry none and answer
    /// nil, falling through to the signature check exactly as they used to.
    private func digestMatches(_ archive: URL, of release: Release) throws -> Bool? {
        guard let expected = release.digest else { return nil }
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
        return actual == expected
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

    /// What the unpacked archive holds. Whether that is the app we were offered
    /// is `StagedPayload.refusal` to say.
    private func readPayload(at staged: URL) -> StagedPayload {
        let bundle = Bundle(url: staged)
        return StagedPayload(
            name: staged.lastPathComponent,
            exists: FileManager.default.fileExists(atPath: staged.path),
            identifier: bundle?.bundleIdentifier,
            shortVersion: bundle?.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
    }

    private func swap(_ staged: URL, into installed: URL) {
        set(phase: .installing, status: .updateInstalling)
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

    /// Everything the preflight needs about the copy being installed over.
    /// Reading it is this manager's job; deciding on it is not.
    private func installedCopy(at url: URL) -> InstalledCopy {
        let parent = url.deletingLastPathComponent()
        let files = FileManager.default
        return InstalledCopy(
            isApplicationBundle: url.pathExtension == "app",
            isWritable: files.isWritableFile(atPath: url.path) && files.isWritableFile(atPath: parent.path),
            parentPath: parent.path,
            isAdHoc: CodeSignature.selfIsAdHoc())
    }
}
