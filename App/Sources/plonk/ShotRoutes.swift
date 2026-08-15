import AppKit

// The routes that end in a picture: taking one, drawing on one, and reading the
// words off one.
//
// They live apart from Router because they are the only routes that do not
// finish inside the request. A capture may wait five minutes on a person with a
// crosshair, and recognition runs on another queue, so each of these hands its
// answer to a closure while Router has already moved on. Router owns the table
// of routes; this owns what happens after one of them is answered late.

final class ShotRoutes {
    /// Longest side of the copy handed to agents, matching what the Claude API
    /// accepts without resampling.
    static let previewMaxDimension: CGFloat = 1568

    private let store: ConfigStore

    /// Set by AppDelegate; the editor and permission prompts need AppKit.
    var capture: ((CaptureMode, Bool, @escaping (NSImage?) -> Void) -> Void)?
    /// Set by AppDelegate. Separate from `capture` because it fails in ways a
    /// caller can act on — the window was never there, or it is minimized — and
    /// those deserve better than one nil standing for all of them.
    var captureWindow: ((WindowCapture.Query, Bool,
                         @escaping (Result<NSImage, WindowCapture.Failure>) -> Void) -> Void)?
    var didSave: ((String) -> Void)?
    var announce: ((_ text: String, _ imagePath: String?) -> Void)?

    init(store: ConfigStore) {
        self.store = store
    }

    // MARK: - Capture

    func captureRoute(_ body: [String: Any], respond: @escaping (HTTPResponse) -> Void) {
        let annotate = (body["annotate"] as? Bool) ?? false
        let requested = (body["mode"] as? String) ?? "screen"

        // "app" is not one of screencapture's modes: it names the window it
        // wants instead of waiting for the user to point at one, so it takes
        // its own road and rejoins at the saving.
        if requested == "app" {
            appCaptureRoute(body, annotate: annotate, respond: respond)
            return
        }

        guard let capture else {
            respond(.failed("capture is not available"))
            return
        }
        let mode = CaptureMode(rawValue: requested) ?? .screen

        capture(mode, annotate) { [weak self] image in
            guard let self else { return }
            guard let image else {
                respond(HTTPResponse(status: 409, json: [
                    "error": "capture was cancelled, or Screen Recording permission is missing",
                ]))
                return
            }
            self.finish(image, body: body, annotate: annotate, respond: respond)
        }
    }

    /// Photographs a named window, whatever is stacked in front of it.
    private func appCaptureRoute(_ body: [String: Any], annotate: Bool,
                                 respond: @escaping (HTTPResponse) -> Void) {
        let query = WindowCapture.Query(app: trimmed(body["app"]),
                                        titleContains: trimmed(body["title_contains"]))
        // Checked before the closure, so a request that names no window is
        // answered the same way whether or not capture has been wired up yet.
        guard !query.isEmpty else {
            respond(.badRequest(WindowCapture.Failure.nothingAsked.localizedDescription))
            return
        }
        guard let captureWindow else {
            respond(.failed("capture is not available"))
            return
        }

        captureWindow(query, annotate) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let image):
                self.finish(image, body: body, annotate: annotate, respond: respond)
            case .failure(let failure):
                let message = failure.localizedDescription
                switch failure {
                // Naming no window, or one that is not there, is the caller's
                // mistake; refusing to photograph a real one is the desktop's.
                case .nothingAsked: respond(.badRequest(message))
                case .noMatch: respond(.notFound(message))
                case .notPermitted, .captureFailed:
                    respond(HTTPResponse(status: 409, json: ["error": message]))
                case .shuttingDown: respond(.failed(message))
                }
            }
        }
    }

    /// What every capture does once it has an image: hand it to the editor, or
    /// write it, copy it and say where it went.
    private func finish(_ image: NSImage, body: [String: Any], annotate: Bool,
                        respond: @escaping (HTTPResponse) -> Void) {
        if annotate {
            respond(.ok(["ok": true, "editor_open": true]))
            return
        }

        let destination: ScreenshotManager.Destination = (body["path"] as? String)
            .map { .path($0) } ?? .folder(store.config.shotFolder)
        guard let path = ScreenshotManager.save(image, to: destination) else {
            respond(.failed("could not write \(destination.url.path)"))
            return
        }

        var result: [String: Any] = ["ok": true, "path": path]
        if (body["clipboard"] as? Bool) ?? store.config.shotCopyToClipboard {
            ScreenshotManager.copyToClipboard(image)
            result["clipboard"] = true
        }
        if (body["preview"] as? Bool) == true,
           let preview = ScreenshotManager.writePreview(image, maxDimension: Self.previewMaxDimension) {
            result["preview_path"] = preview
        }
        didSave?(path)
        respond(.ok(result))
    }

    // MARK: - Annotate

    /// Burns agent-supplied marks into an existing capture.
    func annotateRoute(_ body: [String: Any]) -> HTTPResponse {
        guard let path = trimmed(body["path"]), let raw = body["marks"] as? [[String: Any]], !raw.isEmpty else {
            return .badRequest("body must be {\"path\", \"marks\": [{kind, points:[{x,y}], color?, width?}]}")
        }
        let marks = raw.compactMap { Annotation(dict: $0) }
        guard marks.count == raw.count else {
            let kinds = Annotation.Kind.allCases.map(\.rawValue).joined(separator: ", ")
            return .badRequest("every mark needs a kind (\(kinds)) and at least two points in 0..1")
        }
        let expanded = (path as NSString).expandingTildeInPath
        guard let image = NSImage(contentsOfFile: expanded) else {
            return .notFound("no readable image at \(expanded)")
        }
        let destination: ScreenshotManager.Destination = (body["output"] as? String)
            .map { .path($0) } ?? .path(Self.markedPath(for: expanded))
        let copy = (body["clipboard"] as? Bool) ?? true

        // Rendering is main-actor work; keeping the image inside the hop means
        // only plain strings cross back out.
        let written: (path: String, preview: String?)? = MainActor.assumeIsolated {
            guard let marked = image.annotated(with: marks),
                  let saved = ScreenshotManager.save(marked, to: destination) else { return nil }
            if copy { ScreenshotManager.copyToClipboard(marked) }
            return (saved, ScreenshotManager.writePreview(marked, maxDimension: Self.previewMaxDimension))
        }
        guard let written else { return .failed("could not render or write \(destination.url.path)") }

        var result: [String: Any] = ["ok": true, "path": written.path, "marks": marks.count]
        if copy { result["clipboard"] = true }
        if let preview = written.preview { result["preview_path"] = preview }
        announce?(String(localized: copy ? LocalizedStringResource.hudCopiedToClipboard : .hudSaved),
                  written.preview ?? written.path)
        return .ok(result)
    }

    // MARK: - Text

    /// Reads the text off a capture, or off a file that is already on disk.
    /// Recognition is on-device; nothing leaves the Mac.
    func textRoute(_ body: [String: Any], respond: @escaping (HTTPResponse) -> Void) {
        let languages = (body["languages"] as? [String])?.filter { !$0.isEmpty } ?? store.config.textLanguages
        let copy = (body["clipboard"] as? Bool) ?? true

        let read: (NSImage) -> Void = { image in
            TextExtractor.recognize(in: image, languages: languages) { result in
                switch result {
                case .failure(let error):
                    respond(.failed(error.localizedDescription))
                case .success(let lines):
                    let joined = TextExtractor.joined(lines)
                    var payload: [String: Any] = [
                        "ok": true,
                        "text": joined,
                        "lines": lines.map(\.asDict),
                    ]
                    if copy, !joined.isEmpty {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(joined, forType: .string)
                        payload["clipboard"] = true
                    }
                    if lines.isEmpty { payload["note"] = "no text was recognized in that area" }
                    respond(.ok(payload))
                }
            }
        }

        if let path = trimmed(body["path"]) {
            let expanded = (path as NSString).expandingTildeInPath
            guard let image = NSImage(contentsOfFile: expanded) else {
                respond(.notFound("no readable image at \(expanded)"))
                return
            }
            read(image)
            return
        }
        guard let capture else {
            respond(.failed("capture is not available"))
            return
        }
        let mode = CaptureMode(rawValue: (body["mode"] as? String) ?? "region") ?? .region
        capture(mode, false) { image in
            guard let image else {
                respond(HTTPResponse(status: 409, json: [
                    "error": "capture was cancelled, or Screen Recording permission is missing",
                ]))
                return
            }
            read(image)
        }
    }

    // MARK: - Helpers

    private static func markedPath(for path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let stem = url.deletingPathExtension().lastPathComponent
        return url.deletingLastPathComponent().appendingPathComponent("\(stem) marked.png").path
    }

    private func trimmed(_ value: Any?) -> String? {
        guard let name = (value as? String)?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return nil }
        return name
    }
}
