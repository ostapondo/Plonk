import AppKit

@MainActor
final class QuickShotSession: NSObject {
    private let previousApp: NSRunningApplication?
    private let folder: () -> String
    private let onEditor: (NSImage, AnnotationHistory) -> Void
    private let onFinish: (Bool, String?) -> Void
    private var onClose: (() -> Void)?
    private var windows: [QuickShotWindow] = []
    private var keyMonitor: Any?

    init(previousApp: NSRunningApplication?, folder: @escaping () -> String, onClose: @escaping () -> Void,
         onEditor: @escaping (NSImage, AnnotationHistory) -> Void, onFinish: @escaping (Bool, String?) -> Void) {
        self.previousApp = previousApp
        self.folder = folder
        self.onClose = onClose
        self.onEditor = onEditor
        self.onFinish = onFinish
    }

    func begin() {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return captureFailed() }
        NotificationCenter.default.addObserver(
            self, selector: #selector(cancel), name: NSApplication.didChangeScreenParametersNotification, object: NSApp
        )
        // Give the window server a turn after ordering Plonk's windows out.
        DispatchQueue.main.async { [weak self] in
            guard let self, onClose != nil else { return }
            for screen in screens {
                ScreenshotManager.captureRegion(CGSpace.flip(screen.frame)) { [weak self] image in
                    guard let self, onClose != nil else { return }
                    guard let bitmap = image?.representations.compactMap({ $0 as? NSBitmapImageRep })
                        .max(by: { $0.pixelsWide < $1.pixelsWide })?.cgImage else { return captureFailed() }
                    addWindow(for: screen, image: bitmap)
                    if windows.count == screens.count { present() }
                }
            }
        }
    }

    private func addWindow(for screen: NSScreen, image: CGImage) {
        let window = QuickShotWindow(screen: screen, image: image)
        window.canvas.onCancel = { [weak self] in self?.cancel() }
        window.canvas.onSelect = { [weak self, weak window] in
            self?.windows.filter { $0 !== window }.forEach { $0.canvas.clearSelection() }
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
        windows.forEach { $0.orderFrontRegardless() }
        NSApp.activate(ignoringOtherApps: true)
        let target = windows.first { $0.frame.contains(NSEvent.mouseLocation) } ?? windows.first
        target?.makeKey()
        target?.makeFirstResponder(target?.canvas)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.windows.contains(where: { $0.handleShortcut(event) }) == true { return nil }
            return event
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
            onEditor(crop.image, crop.history)
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
