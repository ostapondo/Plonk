import AppKit
import Carbon.HIToolbox
import SwiftUI

// Owns every window the app can put on screen. AppDelegate asks for them by
// name and never touches NSWindow itself.

final class WindowPresenter: NSObject {
    private let model: AppModel

    private var main: NSWindow?
    private var zonePicker: NSWindow?
    private var fullscreenEditor: NSWindow?
    private var shotEditor: NSWindow?
    private var workspaceLaunch: NSPanel?

    var shotFolder: () -> String = { "~/Desktop" }
    var onCancelWorkspaceLaunch: (() -> Void)?
    var onShotFinished: ((_ copied: Bool, _ path: String?) -> Void)?
    var onZonePickerClosed: (() -> Void)?
    var onFullscreenEditorClosed: (() -> Void)?

    init(model: AppModel) {
        self.model = model
    }

    /// Windows that would otherwise show up in a screenshot of our own desktop.
    var visible: [NSWindow] {
        [main, zonePicker, shotEditor].compactMap { $0 }.filter(\.isVisible)
    }

    var isFullscreenEditorVisible: Bool {
        fullscreenEditor?.isVisible == true
    }

    func showMainWindow() {
        if main == nil {
            let window = panel(title: "Plonk",
                               size: NSSize(width: 860, height: 620),
                               content: MainWindowView(model: model))
            main = window
        }
        present(main)
    }

    func showZonePicker() {
        if zonePicker == nil {
            let window = panel(title: "Zones",
                               size: NSSize(width: 780, height: 580),
                               content: ZonePickerView(model: model))
            window.delegate = self
            zonePicker = window
        }
        present(zonePicker)
    }

    func showFullscreenEditor(set name: String, seed: [ZoneRect]?, screenIndex: Int) {
        closeFullscreenEditor()
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        let screen = screens[min(max(screenIndex, 0), screens.count - 1)]

        // Zones are fractions of the visible area (menu bar and Dock excluded),
        // so the editor covers exactly that area.
        let window = EditorWindow(contentRect: screen.visibleFrame, styleMask: .borderless,
                                  backing: .buffered, defer: false)
        window.onEscape = { [weak self] in self?.closeFullscreenEditor() }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentViewController = NSHostingController(
            rootView: FullscreenZoneEditorView(model: model, setName: name, seed: seed,
                                               screenIndex: screenIndex) { [weak self] in
                self?.closeFullscreenEditor()
            }
        )
        window.setFrame(screen.visibleFrame, display: true)
        fullscreenEditor = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func closeFullscreenEditor() {
        fullscreenEditor?.orderOut(nil)
        fullscreenEditor = nil
        onFullscreenEditorClosed?()
    }

    /// Floats above the apps it is launching without stealing focus from them,
    /// which is why it is a non-activating panel rather than a window.
    func showWorkspaceLaunch() {
        if workspaceLaunch == nil {
            let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.level = .floating
            panel.hasShadow = true
            panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = NSHostingView(rootView: WorkspaceLaunchPanel(
                model: model,
                onCancel: { [weak self] in self?.onCancelWorkspaceLaunch?() },
                onClose: { [weak self] in self?.closeWorkspaceLaunch() }
            ))
            workspaceLaunch = panel
        }
        guard let panel = workspaceLaunch else { return }
        panel.setContentSize(panel.contentView?.fittingSize ?? NSSize(width: 340, height: 200))
        // Re-anchored every time: setContentSize keeps the bottom-left corner,
        // so a growing panel would creep up under the menu bar.
        HUD.placeInCorner(panel)
        panel.orderFrontRegardless()
    }

    func closeWorkspaceLaunch() {
        workspaceLaunch?.orderOut(nil)
    }

    func showShotEditor(image: NSImage) {
        shotEditor?.close()
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "Screenshot"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: ShotEditorView(image: image, defaultFolder: shotFolder()) { [weak self] copied, path in
                self?.closeShotEditor()
                self?.onShotFinished?(copied, path)
            }
        )
        window.setContentSize(NSSize(width: min(max(image.size.width, 700), 1400),
                                     height: min(max(image.size.height + 110, 520), 900)))
        window.center()
        shotEditor = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func closeShotEditor() {
        shotEditor?.close()
        shotEditor = nil
    }

    private func panel<Content: View>(title: String, size: NSSize, content: Content) -> NSWindow {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = title
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: content)
        // Size before centering: the hosting view starts at zero and would
        // otherwise centre as a point and grow off-centre.
        window.setContentSize(size)
        return window
    }

    private func present(_ window: NSWindow?) {
        guard let window else { return }
        if !window.isVisible { window.center() }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

extension WindowPresenter: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === zonePicker else { return }
        onZonePickerClosed?()
    }
}

// Borderless windows refuse key status by default; the fullscreen editor needs
// it for Esc and buttons.
final class EditorWindow: NSWindow {
    var onEscape: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == kVK_Escape {
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }
}
