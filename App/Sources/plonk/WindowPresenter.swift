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
    private var palette: EditorWindow?
    private var zoneSetPalette: EditorWindow?

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
                               size: NSSize(width: 1000, height: 700),
                               unified: true,
                               content: MainWindowView(model: model))
            main = window
        }
        present(main)
    }

    var isCommandPaletteOpen: Bool { palette != nil }

    /// ⌘K. Rebuilt on every open rather than kept around, because the commands
    /// it lists change with the workspaces, the zone sets and the bindings.
    func showCommandPalette(commands: [PlonkCommand], agent: String?,
                            onAsk: @escaping (String) -> Void) {
        closeCommandPalette()
        let window = overlay(content: CommandPaletteView(commands: commands, agent: agent,
                                                        onAsk: onAsk) { [weak self] in
            self?.closeCommandPalette()
        }, onEscape: { [weak self] in self?.closeCommandPalette() })
        palette = window
        show(window, near: NSScreen.main)
    }

    /// Closed rather than ordered out: the hosting view has to be torn down so
    /// its key monitor is removed. An ordered-out window keeps its view alive,
    /// and a live monitor would swallow the arrow keys of every other app.
    func closeCommandPalette() {
        guard let window = palette else { return }
        palette = nil
        window.delegate = nil
        window.close()
    }

    /// The zone sets for one screen, opened on that screen: the list is about
    /// that monitor, so it has to be visible on it.
    func showZoneSetPalette(screenIndex: Int) {
        closeZoneSetPalette()
        let window = overlay(content: ZoneSetPaletteView(model: model, screenIndex: screenIndex) {
            [weak self] in self?.closeZoneSetPalette()
        }, onEscape: { [weak self] in self?.closeZoneSetPalette() })
        zoneSetPalette = window
        let screens = NSScreen.screens
        show(window, near: screens.indices.contains(screenIndex) ? screens[screenIndex] : .main)
    }

    func closeZoneSetPalette() {
        guard let window = zoneSetPalette else { return }
        zoneSetPalette = nil
        window.delegate = nil
        window.close()
    }

    /// A borderless panel over everything, sized to what SwiftUI asks for.
    /// Clicking anywhere else dismisses it, the way Spotlight does: without
    /// that it stays on top of whatever you switched to, and its key monitor
    /// keeps eating the arrow keys.
    private func overlay<Content: View>(content: Content,
                                        onEscape: @escaping () -> Void) -> EditorWindow {
        let window = EditorWindow(contentRect: .zero, styleMask: .borderless,
                                  backing: .buffered, defer: false)
        window.onEscape = onEscape
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.hasShadow = true
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: content)
        window.setContentSize(window.contentViewController?.view.fittingSize
                              ?? NSSize(width: 560, height: 420))
        return window
    }

    /// A third of the way down rather than centred: a list that grows
    /// downwards should not start in the middle of the screen.
    private func show(_ window: NSWindow, near screen: NSScreen?) {
        if let screen {
            let frame = window.frame
            window.setFrameOrigin(NSPoint(x: screen.frame.midX - frame.width / 2,
                                          y: screen.visibleFrame.maxY - frame.height - 140))
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
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

    /// `unified` runs the content up under the title bar, so the sidebar and
    /// the page's own bar reach the top edge and the window has one header
    /// instead of a system one sitting on top of ours. The traffic lights stay
    /// where macOS puts them; the sidebar leaves room for them.
    private func panel<Content: View>(title: String, size: NSSize, unified: Bool = false,
                                      content: Content) -> NSWindow {
        var style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        if unified { style.insert(.fullSizeContentView) }
        let window = NSWindow(
            contentRect: .zero,
            styleMask: style,
            backing: .buffered, defer: false
        )
        window.title = title
        if unified {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
        }
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

    func windowDidResignKey(_ notification: Notification) {
        let window = notification.object as? NSWindow
        if window === palette { closeCommandPalette() }
        if window === zoneSetPalette { closeZoneSetPalette() }
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
