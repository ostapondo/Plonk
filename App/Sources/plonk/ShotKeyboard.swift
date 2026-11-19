import AppKit

final class ShotKeyboard: NSObject {
    private let hotkeys: HotkeyManager
    private var monitor: Any?
    private var tap: EventTap?
    private var suspended = false
    private var attemptedTap = false
    private var systemShortcuts: Set<ShotSystemShortcut> = []
    private var preparationID = 0
    private var preparing = false
    var onResume: (() -> Void)?

    init(hotkeys: HotkeyManager) {
        self.hotkeys = hotkeys
        super.init()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(refresh), name: NSApplication.didBecomeActiveNotification, object: NSApp)
        center.addObserver(self, selector: #selector(refresh), name: NSApplication.didResignActiveNotification, object: NSApp)
        center.addObserver(self, selector: #selector(refresh), name: NSWindow.didBecomeKeyNotification, object: nil)
        center.addObserver(self, selector: #selector(keyWindowChanged), name: NSWindow.didResignKeyNotification, object: nil)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event) == true ? nil : event
        }
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }

    func beginPreparing() {
        preparationID += 1
        preparing = true
        refresh()
    }

    func finishedPreparing() {
        let id = preparationID
        DispatchQueue.main.async { [weak self] in
            guard let self, preparationID == id else { return }
            preparing = false
            refresh()
        }
    }

    private var hasShotFocus: Bool {
        guard NSApp.isActive else { return false }
        var owner = NSApp.keyWindow
        while let window = owner {
            if window is QuickShotWindow || window is ShotEditorWindow { return true }
            owner = window.sheetParent ?? window.parent
        }
        return false
    }

    @objc private func keyWindowChanged() {
        // The resign notification comes before the next key window, including
        // during handoff from the picker to the editor or a save sheet.
        DispatchQueue.main.async { [weak self] in self?.refresh() }
    }

    @objc private func refresh() {
        let focused = hasShotFocus
        let shouldSuspend = focused || preparing
        if shouldSuspend != suspended {
            suspended = shouldSuspend
            hotkeys.setSuspended(shouldSuspend)
            if !shouldSuspend { onResume?() }
        }
        if focused {
            installTapIfNeeded()
        } else {
            tap = nil
            attemptedTap = false
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard hasShotFocus, let key = NSApp.keyWindow, key.attachedSheet == nil, key.sheetParent == nil,
              event.window == nil || event.window === key else { return false }
        if let quick = key as? QuickShotWindow { return quick.handleShortcut(event) }
        if let editor = key as? ShotEditorWindow { return editor.handleShortcut(event) }
        return false
    }

    private func installTapIfNeeded() {
        guard !attemptedTap else { return }
        attemptedTap = true
        guard CGPreflightPostEventAccess() else { return }
        systemShortcuts = ShotSystemShortcut.enabled()
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue) | (CGEventMask(1) << CGEventType.keyUp.rawValue)
        let pid = ProcessInfo.processInfo.processIdentifier
        tap = EventTap(mask: mask, options: .defaultTap, name: "screenshot keyboard") { [weak self] _, event in
            guard let self, hasShotFocus, !systemShortcuts.contains(ShotSystemShortcut(event: event)) else {
                return Unmanaged.passUnretained(event)
            }
            // Deliver to our AppKit responder chain without forwarding to
            // the session's global shortcuts, preserving text input and IME.
            event.postToPid(pid)
            return nil
        }
    }
}
