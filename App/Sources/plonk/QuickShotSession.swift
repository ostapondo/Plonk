import AppKit

final class QuickShotSession: NSObject {
    private let config: () -> Config
    private let onFinish: (Bool, String?) -> Void
    private let onEditor: (NSImage, AnnotationHistory) -> Void
    private let onPresented: () -> Void
    private var onClose: (() -> Void)?
    private var windows: [QuickShotWindow] = []

    init(config: @escaping () -> Config, onFinish: @escaping (Bool, String?) -> Void,
         onEditor: @escaping (NSImage, AnnotationHistory) -> Void,
         onClose: @escaping () -> Void, onPresented: @escaping () -> Void) {
        self.config = config
        self.onFinish = onFinish
        self.onEditor = onEditor
        self.onClose = onClose
        self.onPresented = onPresented
    }

    func begin() {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return failCapture() }
        NotificationCenter.default.addObserver(
            self, selector: #selector(close), name: NSApplication.didChangeScreenParametersNotification, object: NSApp
        )
        // Give the window server a turn after ordering Plonk's windows out.
        DispatchQueue.main.async { [weak self] in self?.capture(screens) }
    }

    private func capture(_ screens: [NSScreen]) {
        guard onClose != nil else { return }
        var pending = screens.count
        for screen in screens {
            ScreenshotManager.captureRegion(CGSpace.flip(screen.frame)) { [weak self] image in
                guard let self, onClose != nil else { return }
                guard let image, let bitmap = ShotBitmap(image) else { return failCapture() }
                let window = QuickShotWindow(screen: screen, bitmap: bitmap, accent: config().appearance.accent)
                window.onCancel = { [weak self] in self?.close() }
                window.canvas.onSelect = { [weak self, weak window] in
                    self?.windows.filter { $0 !== window }.forEach { $0.canvas.clearSelection() }
                }
                window.canvas.onAction = { [weak self, weak window] image, history, action in
                    guard let window else { return }
                    self?.perform(action, image: image, history: history, window: window)
                }
                windows.append(window)
                pending -= 1
                if pending == 0 { present() }
            }
        }
    }

    private func present() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(close), name: NSApplication.didResignActiveNotification, object: NSApp
        )
        windows.forEach { $0.orderFrontRegardless() }
        NSApp.activate(ignoringOtherApps: true)
        let target = windows.first { $0.frame.contains(NSEvent.mouseLocation) } ?? windows.first
        target?.makeKey()
        target?.makeFirstResponder(target?.canvas)
        onPresented()
    }

    private func failCapture() {
        close()
        HUD.shared.show(.shotCaptureFailed)
    }

    private func perform(_ action: QuickShotAction, image: NSImage, history: AnnotationHistory,
                         window: QuickShotWindow) {
        switch action {
        case .editor:
            close()
            onEditor(image, history)
        case .recognizeText:
            guard let token = window.canvas.beginRecognition() else { return }
            TextExtractor.recognize(in: image, languages: config().textLanguages) { [weak self, weak window] result in
                guard self?.onClose != nil else { return }
                window?.canvas.finishRecognition(result, token: token)
            }
        case .saveAs:
            window.beginShotSavePanel(in: config().shotFolder) { [weak self] url in
                guard let self, onClose != nil, let url else { return }
                withRendered(image, history: history) { self.save($0, to: .path(url.path)) }
            }
        case .save(let forceCopy):
            withRendered(image, history: history) { save($0, to: .folder(config().shotFolder), forceCopy: forceCopy) }
        case .copy:
            withRendered(image, history: history, use: copy)
        case .preview:
            withRendered(image, history: history) { output in
                close()
                ScreenshotManager.openInPreview(output) { success in
                    if !success { HUD.shared.show(.shotPreviewFailed) }
                }
            }
        }
    }

    private func withRendered(_ image: NSImage, history: AnnotationHistory, use: (NSImage) -> Void) {
        MainActor.assumeIsolated {
            let marks = history.annotations
            guard let output = marks.isEmpty ? image : image.annotated(with: marks) else {
                HUD.shared.show(.shotEditorRenderFailed)
                return
            }
            use(output)
        }
    }

    private func save(_ image: NSImage, to destination: ScreenshotManager.Destination, forceCopy: Bool = false) {
        guard let path = ScreenshotManager.save(image, to: destination) else {
            HUD.shared.show(.shotEditorWriteFailed)
            return
        }
        let copied = forceCopy && ScreenshotManager.copyToClipboard(image)
        if forceCopy && !copied { HUD.shared.show(.shotCopyFailed) }
        close()
        onFinish(copied, path)
    }

    private func copy(_ image: NSImage) {
        guard ScreenshotManager.copyToClipboard(image) else {
            HUD.shared.show(.shotCopyFailed)
            return
        }
        close()
        onFinish(true, nil)
    }

    @objc func close() {
        guard let onClose else { return }
        self.onClose = nil
        NotificationCenter.default.removeObserver(self)
        for window in windows {
            if let sheet = window.attachedSheet { window.endSheet(sheet, returnCode: .cancel) }
            window.orderOut(nil)
        }
        windows.removeAll()
        onClose()
    }
}
