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
    private var inputMonitor: Any?
    private weak var magnifierWindow: QuickShotWindow?
    private var magnifierZoom: ShotMagnifierZoom = .standard
    private var pickerMonitor: Any?
    private var picker: Process?
    private var pickLocation: CGPoint?

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
        // Give the window server a turn after ordering Plonk's windows out.
        DispatchQueue.main.async { [weak self] in
            guard let self, onClose != nil else { return }
            switch mode {
            case .region: captureRegions(screens)
            case .window: pickWindow()
            case .screen:
                guard let screen else { return captureFailed() }
                ScreenshotManager.captureDisplay(screen) { [weak self] image in
                    self?.presentFixed(image, on: screen)
                }
            }
        }
    }

    private func captureRegions(_ screens: [NSScreen]) {
        for screen in screens {
            ScreenshotManager.captureDisplay(screen) { [weak self] image in
                guard let self, onClose != nil else { return }
                guard let bitmap = ShotBitmap(capture: image, displaySize: screen.frame.size) else {
                    return captureFailed()
                }
                addWindow(for: screen, bitmap: bitmap, fixed: false)
                if windows.count == screens.count { present() }
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
        let window = QuickShotWindow(screen: screen, bitmap: bitmap, fixed: fixed, model: model,
                                     annotation: annotation)
        window.canvas.onCancel = { [weak self] in self?.cancel() }
        if !fixed {
            window.onRegionPointerChange = { [weak self] in self?.updateMagnifier(at: $0) }
        }
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
        windows.forEach { $0.orderFrontRegardless() }
        NSApp.activate(ignoringOtherApps: true)
        let target = windows.first { $0.frame.contains(NSEvent.mouseLocation) } ?? windows.first
        target?.makeKey()
        target?.makeFirstResponder(target?.canvas)
        inputMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .mouseMoved, .mouseEntered, .mouseExited]
        ) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown {
                return handleShortcut(event) ? nil : event
            }
            if event.type == .mouseMoved, let window = event.window {
                updateMagnifier(at: window.convertPoint(toScreen: event.locationInWindow))
            } else {
                updateMagnifier(at: NSEvent.mouseLocation)
            }
            return event
        }
        updateMagnifier(at: NSEvent.mouseLocation)
    }

    private var isWaitingForRegion: Bool { windows.allSatisfy { $0.canvas.isWaitingForRegion } }

    private func regionWindow(at pointer: CGPoint) -> QuickShotWindow? {
        windows.first { $0.canvas.magnifier != nil && $0.canvas.bounds.contains($0.canvasPoint(at: pointer)) }
    }

    private func updateMagnifier(at pointer: CGPoint) {
        guard onClose != nil else { return }
        let waiting = isWaitingForRegion
        // During a drag only its starting canvas can sample, even on another display.
        let target = windows.first { $0.canvas.isDraggingRegionBoundary } ?? (waiting ? regionWindow(at: pointer) : nil)
        if let previous = magnifierWindow?.canvas, magnifierWindow !== target {
            previous.magnifier?.hide()
            previous.regionTips?.isHidden = true
        }
        magnifierWindow = target
        guard let target else { return }
        let canvas = target.canvas
        canvas.regionTips?.isHidden = !waiting
        let obstacle = waiting ? canvas.regionTips?.frame : canvas.regionFrame
        canvas.magnifier?.update(at: target.canvasPoint(at: pointer), in: canvas.bounds, avoiding: obstacle,
                                 zoom: magnifierZoom)
    }

    private func handleShortcut(_ event: NSEvent) -> Bool {
        guard let keyWindow = windows.first(where: \.isKeyWindow), let command = keyWindow.shortcut(for: event)
        else { return false }
        let magnifier = magnifierWindow?.canvas.magnifier
        switch command {
        case .copyColor:
            guard keyWindow.canvas.magnifier != nil else { return false }
            if let hex = magnifier?.hex {
                NSPasteboard.general.replaceContents(with: hex)
                close(restoreFocus: true)
            }
        case .zoomMagnifier(let increasing):
            guard keyWindow.canvas.magnifier != nil else { return false }
            if let magnifier, !magnifier.isHidden {
                magnifierZoom = magnifierZoom.stepped(increasing: increasing)
                magnifier.setZoom(magnifierZoom)
            }
        case .selectDisplay:
            guard keyWindow.canvas.magnifier != nil else { return false }
            let pointer = NSEvent.mouseLocation
            if isWaitingForRegion, NSEvent.pressedMouseButtons & 1 == 0, let target = regionWindow(at: pointer) {
                target.makeKey()
                target.makeFirstResponder(target.canvas)
                target.canvas.handle(command)
                updateMagnifier(at: pointer)
            }
        default:
            keyWindow.canvas.handle(command)
        }
        return true
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
        stopPicker()
        NotificationCenter.default.removeObserver(self)
        if let inputMonitor { NSEvent.removeMonitor(inputMonitor) }
        inputMonitor = nil
        magnifierWindow = nil
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
