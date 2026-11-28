import AppKit

@MainActor
final class QuickShotSession: NSObject {
    private let previousApp: NSRunningApplication?
    private let model: AppModel
    private let folder: () -> String
    private let annotation: ShotAnnotationState
    private let onEditor: (NSImage, AnnotationHistory, ShotAnnotationState) -> Void
    private let onFinish: (Bool, String?) -> Void
    private var onClose: (() -> Void)?
    private var windows: [QuickShotWindow] = []
    private var keyMonitor: Any?
    private var pickerMonitor: Any?
    private var picker: Process?
    private var pickLocation: CGPoint?
    private var captureTask: Task<Void, Never>?

    init(previousApp: NSRunningApplication?, model: AppModel, folder: @escaping () -> String,
         onClose: @escaping () -> Void,
         onEditor: @escaping (NSImage, AnnotationHistory, ShotAnnotationState) -> Void,
         onFinish: @escaping (Bool, String?) -> Void) {
        self.previousApp = previousApp
        self.model = model
        annotation = ShotAnnotationState(defaults: model.config.shotAnnotationStyles)
        self.folder = folder
        self.onClose = onClose
        self.onEditor = onEditor
        self.onFinish = onFinish
    }

    func begin(_ mode: CaptureMode, screen: NSScreen?) {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return captureFailed() }
        NotificationCenter.default.addObserver(
            self, selector: #selector(cancel), name: NSApplication.didChangeScreenParametersNotification, object: NSApp
        )
        switch mode {
        case .region:
            captureDisplays(screens, fixed: false)
        case .window:
            // Give the window server a turn after ordering Plonk's windows out.
            DispatchQueue.main.async { [weak self] in
                guard let self, onClose != nil else { return }
                pickWindow()
            }
        case .screen:
            guard let screen else { return captureFailed() }
            captureDisplays([screen], fixed: true)
        }
    }

    private func captureDisplays(_ screens: [NSScreen], fixed: Bool) {
        captureTask = Task { [weak self] in
            do {
                let bitmaps = try await ShotDisplayCapture.capture(screens)
                try Task.checkCancellation()
                guard let self, onClose != nil else { return }
                for (screen, bitmap) in zip(screens, bitmaps) {
                    addWindow(for: screen, bitmap: bitmap, fixed: fixed)
                }
                present()
            } catch {
                guard let self, onClose != nil else { return }
                captureFailed()
            }
        }
    }

    private func pickWindow() {
        pickerMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.pickLocation = event.cgEvent.map { CGSpace.flip($0.location) } ?? NSEvent.mouseLocation
        }
        picker = ScreenshotManager.pickWindow { [weak self] result in
            guard let self, onClose != nil else { return }
            stopPicker()
            switch result {
            case .captured(let image):
                let screen = ScreenIdentity.screen(at: pickLocation ?? NSEvent.mouseLocation)
                presentFixed(image, on: screen)
            case .noImage where CGPreflightScreenCaptureAccess():
                cancel()
            default:
                captureFailed()
            }
        }
    }

    private func stopPicker() {
        if let pickerMonitor { NSEvent.removeMonitor(pickerMonitor) }
        pickerMonitor = nil
        if let picker, picker.isRunning { picker.terminate() }
        picker = nil
    }

    private func presentFixed(_ image: NSImage?, on screen: NSScreen?) {
        guard onClose != nil else { return }
        guard let screen, let bitmap = ShotBitmap(capture: image) else { return captureFailed() }
        addWindow(for: screen, bitmap: bitmap, fixed: true)
        present()
    }

    private func addWindow(for screen: NSScreen, bitmap: ShotBitmap, fixed: Bool) {
        let window = QuickShotWindow(frame: screen.frame, visibleFrame: screen.visibleFrame,
                                     bitmap: bitmap, fixed: fixed, model: model, annotation: annotation)
        window.canvas.onCancel = { [weak self] in self?.cancel() }
        window.canvas.onSelect = { [weak self, weak window] in
            self?.windows.filter { $0 !== window }.forEach { $0.canvas.clearSelection() }
        }
        window.canvas.marksAnywhere = { [weak self] in
            self?.windows.contains { $0.canvas.hasMarks } ?? false
        }
        window.canvas.onOutput = { [weak self, weak window] action, crop in
            guard let self, let window, onClose != nil else { return }
            perform(action, crop: crop, in: window)
        }
        windows.append(window)
    }

    private func present() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(cancel), name: NSApplication.didResignActiveNotification, object: NSApp
        )
        for window in windows {
            NotificationCenter.default.addObserver(
                self, selector: #selector(windowResignedKey), name: NSWindow.didResignKeyNotification, object: window
            )
            window.show()
        }
        let target = windows.first { $0.frame.contains(NSEvent.mouseLocation) } ?? windows.first
        target?.makeKey()
        target?.makeFirstResponder(target?.canvas)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.windows.contains(where: { $0.handleShortcut(event) }) == true { return nil }
            return event
        }
    }

    @objc private func windowResignedKey() {
        // Another display's panel or the Save As sheet can take focus during this event.
        DispatchQueue.main.async { [weak self] in
            guard let self, onClose != nil,
                  !windows.contains(where: { $0.isKeyWindow || $0.attachedSheet?.isKeyWindow == true })
            else { return }
            cancel()
        }
    }

    private func captureFailed() {
        cancel()
        HUD.shared.show(.shotCaptureFailed)
    }

    private func perform(_ action: QuickShotOutput, crop: ShotCrop, in window: QuickShotWindow) {
        switch action {
        case .editor:
            close(restoreFocus: false)
            onEditor(crop.image, crop.history, annotation)
        case .copy:
            guard let image = render(crop) else { return }
            guard ScreenshotManager.copyToClipboard(image) else {
                HUD.shared.show(.shotCopyFailed)
                return
            }
            close(restoreFocus: true)
            onFinish(true, nil)
        case .save:
            save(crop, to: .folder(folder()))
        case .saveAs:
            guard window.attachedSheet == nil else { return }
            let panel = ShotSavePanel.make(in: folder())
            panel.beginSheetModal(for: window) { [weak self] response in
                guard let self, onClose != nil, response == .OK, let url = panel.url else { return }
                save(crop, to: .path(url.path))
            }
        }
    }

    private func render(_ crop: ShotCrop) -> NSImage? {
        let image = crop.rendered()
        if image == nil { HUD.shared.show(.shotEditorRenderFailed) }
        return image
    }

    private func save(_ crop: ShotCrop, to destination: ScreenshotManager.Destination) {
        guard let image = render(crop) else { return }
        guard let path = ScreenshotManager.save(image, to: destination) else {
            HUD.shared.show(.shotEditorWriteFailed)
            return
        }
        close(restoreFocus: true)
        onFinish(false, path)
    }

    @objc private func cancel() {
        close(restoreFocus: true)
    }

    private func close(restoreFocus: Bool) {
        guard let onClose else { return }
        let shouldRestore = restoreFocus && NSApp.isActive
        self.onClose = nil
        captureTask?.cancel()
        captureTask = nil
        stopPicker()
        NotificationCenter.default.removeObserver(self)
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        for window in windows {
            if let sheet = window.attachedSheet { window.endSheet(sheet, returnCode: .cancel) }
            window.orderOut(nil)
        }
        windows.removeAll()
        onClose()
        if shouldRestore, let previousApp,
           previousApp.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp.activate()
        }
    }
}
