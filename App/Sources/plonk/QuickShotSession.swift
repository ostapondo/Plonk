import AppKit

final class QuickShotSession: NSObject {
    private let previousApp: NSRunningApplication?
    private let onEditor: (NSImage) -> Void
    private var onClose: (() -> Void)?
    private var windows: [QuickShotWindow] = []

    init(previousApp: NSRunningApplication?, onClose: @escaping () -> Void,
         onEditor: @escaping (NSImage) -> Void) {
        self.previousApp = previousApp
        self.onClose = onClose
        self.onEditor = onEditor
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
        window.canvas.onEditor = { [weak self] image in
            guard let self, onClose != nil else { return }
            close(restoreFocus: false)
            onEditor(image)
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
    }

    private func captureFailed() {
        cancel()
        HUD.shared.show(.shotCaptureFailed)
    }

    @objc private func cancel() {
        close(restoreFocus: true)
    }

    private func close(restoreFocus: Bool) {
        guard let onClose else { return }
        self.onClose = nil
        NotificationCenter.default.removeObserver(self)
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        onClose()
        if restoreFocus, NSApp.isActive, let previousApp,
           previousApp.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp.activate()
        }
    }
}
