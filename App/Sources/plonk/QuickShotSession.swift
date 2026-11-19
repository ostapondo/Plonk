import AppKit

final class QuickShotSession: NSObject {
    private let config: () -> Config
    private let onFinish: (Bool, String?) -> Void
    private var onClose: (() -> Void)?
    private var windows: [QuickShotWindow] = []

    init(config: @escaping () -> Config, onFinish: @escaping (Bool, String?) -> Void,
         onClose: @escaping () -> Void) {
        self.config = config
        self.onFinish = onFinish
        self.onClose = onClose
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
                let window = QuickShotWindow(screen: screen, bitmap: bitmap)
                window.onCancel = { [weak self] in self?.close() }
                window.canvas.onSelect = { [weak self, weak window] in
                    self?.windows.filter { $0 !== window }.forEach { $0.canvas.clearSelection() }
                }
                window.canvas.onOutput = { [weak self] image, save in
                    self?.output(image, save: save)
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
    }

    private func failCapture() {
        close()
        HUD.shared.show(.shotCaptureFailed)
    }

    private func output(_ image: NSImage, save: Bool) {
        if save {
            guard let path = ScreenshotManager.save(image, to: .folder(config().shotFolder)) else {
                HUD.shared.show(.shotEditorWriteFailed)
                return
            }
            close()
            onFinish(false, path)
        } else {
            guard ScreenshotManager.copyToClipboard(image) else {
                HUD.shared.show(.shotCopyFailed)
                return
            }
            close()
            onFinish(true, nil)
        }
    }

    @objc func close() {
        guard let onClose else { return }
        self.onClose = nil
        NotificationCenter.default.removeObserver(self)
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        onClose()
    }
}
