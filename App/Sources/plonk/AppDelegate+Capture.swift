import AppKit

// What the /shot routes need from the app: a capture, and somewhere to put the
// result. ShotRoutes decides what to answer; none of it can happen without
// AppKit, so the doing stays here.

extension AppDelegate {
    func setupShotRoutes() {
        let shots = router.shots
        shots.didSave = { [weak self] path in
            self?.model.shotStatus = String(localized: .hudSavedTo(path))
        }
        shots.announce = { text, path in
            HUD.shared.show(text, image: path.flatMap { NSImage(contentsOfFile: $0) })
        }
        shots.capture = { [weak self] mode, annotate, done in
            guard let self else { return done(nil) }
            runCapture(mode, openEditor: annotate, completion: done)
        }
        shots.captureWindow = { [weak self] query, annotate, done in
            guard let self else { return done(.failure(.shuttingDown)) }
            runWindowCapture(query, openEditor: annotate, completion: done)
        }
    }

    /// A window named rather than pointed at. Plonk's own windows stay where
    /// they are: only the target window is photographed, so nothing of ours can
    /// fall into the frame, and there is no flicker to hide.
    func runWindowCapture(_ query: WindowCapture.Query, openEditor: Bool,
                          completion: @escaping (Result<NSImage, WindowCapture.Failure>) -> Void) {
        WindowCapture.capture(query) { [weak self] result in
            if case .success(let image) = result, openEditor {
                self?.presenter.showShotEditor(image: image)
            }
            completion(result)
        }
    }

    /// Region capture straight into recognition: the text lands on the
    /// clipboard, and the HUD shows what was read so a bad crop is obvious
    /// without pasting it somewhere first.
    func captureText() {
        runCapture(.region, openEditor: false) { [weak self] image in
            guard let self, let image else { return }
            TextExtractor.recognize(in: image, languages: store.config.textLanguages) { result in
                switch result {
                case .failure(let error):
                    HUD.shared.show(error.localizedDescription)
                case .success(let lines):
                    let text = TextExtractor.joined(lines)
                    guard !text.isEmpty else {
                        HUD.shared.show(.hudNoTextFound)
                        return
                    }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    HUD.shared.show(String(localized: .hudCopied(text.prefix(80)
                                                  + (text.count > 80 ? "…" : ""))))
                }
            }
        }
    }
}
