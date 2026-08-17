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

    func runCapture(_ mode: CaptureMode, openEditor: Bool,
                            completion: @escaping (NSImage?) -> Void = { _ in }) {
        let hidden = hideOwnWindows()
        ScreenshotManager.capture(mode) { [weak self] image in
            self?.showOwnWindows(hidden)
            if let image, openEditor { self?.presenter.showShotEditor(image: image) }
            completion(image)
        }
    }

    /// Everything Plonk has on screen, ordered out so it cannot end up in a
    /// capture: settings and editors, but also the crosshairs and any pinned
    /// crop, which are floating over exactly the area being photographed.
    func hideOwnWindows() -> [NSWindow] {
        // Counted, because a capture can start while a pinned crop is still
        // choosing its region: the first one to finish must not put the
        // overlays back into the other one's photograph.
        captureDepth += 1
        mouse.suspend()
        let hidden = (presenter.visible + crops.visibleWindows + [guidePanel].compactMap { $0 })
            .filter { $0.isVisible }
        hidden.forEach { $0.orderOut(nil) }
        return hidden
    }

    func showOwnWindows(_ hidden: [NSWindow]) {
        captureDepth = max(0, captureDepth - 1)
        hidden.forEach { $0.orderFront(nil) }
        guard captureDepth == 0 else { return }
        mouse.resume()
    }

    func finishShot(copied: Bool, path: String?) {
        if let path, store.config.shotCopyToClipboard, !copied,
           let saved = NSImage(contentsOfFile: path) {
            ScreenshotManager.copyToClipboard(saved)
        }
        model.shotStatus = String(localized: path.map { .hudSavedTo($0) } ?? .hudCopiedToClipboard)
    }
}
