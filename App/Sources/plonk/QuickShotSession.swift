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
    private var displayCaptures: [Process] = []
    private var keyMonitor: Any?
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
        if mode != .window {
            NSWorkspace.shared.notificationCenter.addObserver(
                self, selector: #selector(frontmostAppChanged), name: NSWorkspace.didActivateApplicationNotification,
                object: nil
            )
        }
        // Give the window server a turn after ordering Plonk's windows out.
        DispatchQueue.main.async { [weak self] in
            guard let self, onClose != nil else { return }
            switch mode {
            case .region: captureRegions(screens)
            case .window: pickWindow()
            case .screen:
                guard let screen else { return captureFailed() }
                captureRegions([screen], selectingEntireDisplay: true)
            }
        }
    }

    private func captureRegions(_ screens: [NSScreen], selectingEntireDisplay: Bool = false) {
        let windowBounds = selectingEntireDisplay ? [] : WindowServer.screenshotWindowBounds()
        for screen in screens {
            let process = ScreenshotManager.captureDisplay(screen) { [weak self] image in
                guard let self, onClose != nil else { return }
                guard let bitmap = ShotBitmap(capture: image, displaySize: screen.frame.size) else {
                    return captureFailed()
                }
                let window = addWindow(for: screen, bitmap: bitmap, fixed: false)
                let origin = CGSpace.flip(screen.frame).origin
                window.canvas.startsOnWindow = { point in
                    let location = CGPoint(x: origin.x + point.x, y: origin.y + point.y)
                    return windowBounds.contains { $0.contains(location) }
                }
                guard windows.count == screens.count else { return }
                displayCaptures.removeAll()
                guard !hasSwitchedApps else { return cancelOnAppSwitch() }
                if selectingEntireDisplay { selectEntireDisplay(in: window) }
                present()
            }
            if let process { displayCaptures.append(process) }
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
                presentWindowCapture(image, on: screen)
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

    private func presentWindowCapture(_ image: NSImage?, on screen: NSScreen?) {
        guard onClose != nil else { return }
        guard let screen, let bitmap = ShotBitmap(capture: image) else { return captureFailed() }
        addWindow(for: screen, bitmap: bitmap, fixed: true)
        present()
    }

    @discardableResult
    private func addWindow(for screen: NSScreen, bitmap: ShotBitmap, fixed: Bool) -> QuickShotWindow {
        let window = QuickShotWindow(screen: screen, bitmap: bitmap, fixed: fixed, model: model,
                                     annotation: annotation)
        window.canvas.onCancel = { [weak self] in self?.cancel() }
        window.canvas.onSelect = { [weak self, weak window] in
            guard let self else { return }
            windows.filter { $0 !== window }.forEach { $0.canvas.clearSelection() }
            updateSelectionHints()
        }
        window.canvas.onDragStateChange = { [weak self] in self?.updateSelectionHints() }
        window.canvas.onSelectDisplay = { [weak self, weak window] in
            guard let window else { return }
            self?.selectEntireDisplay(in: window)
        }
        window.canvas.marksAnywhere = { [weak self] in
            self?.windows.contains { $0.canvas.hasMarks } ?? false
        }
        window.canvas.onOutput = { [weak self, weak window] action, crop in
            guard let self, let window, onClose != nil else { return }
            perform(action, crop: crop, in: window)
        }
        windows.append(window)
        return window
    }

    private var isWaitingForSelection: Bool { windows.allSatisfy { $0.canvas.isWaitingForSelection } }

    private func updateSelectionHints() {
        let visible = isWaitingForSelection
        windows.forEach { $0.canvas.showHint(visible) }
    }

    private func selectEntireDisplay(in window: QuickShotWindow) {
        guard isWaitingForSelection, windows.contains(where: { $0 === window }) else { return }
        window.canvas.selectEntireDisplay()
        if window.isVisible { focus(window) }
        windows.filter { $0 !== window }.forEach { $0.orderOut(nil) }
        windows = [window]
    }

    private func present() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.addObserver(
            self, selector: #selector(cancelOnAppSwitch), name: NSApplication.didResignActiveNotification,
            object: NSApp
        )
        updateSelectionHints()
        windows.forEach { $0.orderFrontRegardless() }
        NSApp.activate(ignoringOtherApps: true)
        if let target = windowUnderPointer ?? windows.first { focus(target) }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleShortcut(event) == true ? nil : event
        }
    }

    private var windowUnderPointer: QuickShotWindow? {
        let pointer = NSEvent.mouseLocation
        return windows.first { $0.frame.contains(pointer) }
    }

    private func focus(_ window: QuickShotWindow) {
        window.makeKey()
        window.makeFirstResponder(window.canvas)
    }

    private func handleShortcut(_ event: NSEvent) -> Bool {
        guard let window = windows.first(where: \.isKeyWindow), let command = window.shortcut(for: event) else {
            return false
        }
        if command == .selectDisplay {
            if NSEvent.pressedMouseButtons & 1 == 0, let target = windowUnderPointer {
                selectEntireDisplay(in: target)
            }
        } else if command == .cancel {
            window.canvas.handle(command)
        } else if !window.canvas.isTrackingPointer {
            let target = windows.first { $0.canvas.hasSelection } ?? window
            target.canvas.handle(command)
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

    private var hasSwitchedApps: Bool {
        guard let frontmost = NSWorkspace.shared.frontmostApplication, let previousApp else { return false }
        return frontmost.processIdentifier != previousApp.processIdentifier
    }

    @objc private func frontmostAppChanged() {
        if hasSwitchedApps { cancelOnAppSwitch() }
    }

    @objc private func cancelOnAppSwitch() {
        close(restoreFocus: false)
    }

    private func close(restoreFocus: Bool) {
        guard let onClose else { return }
        let shouldRestore = restoreFocus && NSApp.isActive
        self.onClose = nil
        stopPicker()
        displayCaptures.filter(\.isRunning).forEach { $0.terminate() }
        displayCaptures.removeAll()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
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
