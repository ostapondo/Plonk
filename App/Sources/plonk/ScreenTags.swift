import AppKit

// "Which one is screen 2?" — the same numbers System Settings shows under
// Displays, but put up on the screens themselves at the moment the choice is
// being made, and gone a second and a half later.
//
// One borderless window per display, ignoring the mouse and above everything,
// so a preview that lands on the other monitor is not a mystery: the number
// under the pointer and the number in the picker are the same number.

final class ScreenTags {
    private var windows: [NSWindow] = []
    private var hideWork: DispatchWorkItem?

    /// Long enough to look up from the settings window and find the number,
    /// short enough that it is never in the way of the thing being set up.
    private static let duration: TimeInterval = 1.8
    private static let card = NSSize(width: 240, height: 180)

    /// `selected` is drawn in the tint and the rest in grey, so the answer to
    /// "which monitor am I setting up" is one glance rather than two.
    func show(selected: Int, tint: NSColor) {
        hideWork?.cancel()
        rebuild(selected: selected, tint: tint)
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.duration, execute: work)
    }

    func hide() {
        hideWork?.cancel()
        hideWork = nil
        let leaving = windows
        windows = []
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            leaving.forEach { $0.animator().alphaValue = 0 }
        } completionHandler: {
            leaving.forEach { $0.orderOut(nil) }
        }
    }

    private func rebuild(selected: Int, tint: NSColor) {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.enumerated().map { index, screen in
            let frame = NSRect(x: screen.frame.midX - Self.card.width / 2,
                               y: screen.frame.midY - Self.card.height / 2,
                               width: Self.card.width, height: Self.card.height)
            let window = NSWindow(contentRect: frame, styleMask: .borderless,
                                  backing: .buffered, defer: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.ignoresMouseEvents = true
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
            window.contentView = Self.card(number: index + 1, screen: screen,
                                           tint: index == selected ? tint : .secondaryLabelColor)
            window.alphaValue = 0
            window.orderFrontRegardless()
            return window
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            windows.forEach { $0.animator().alphaValue = 1 }
        }
    }

    /// The number, and under it the size the pickers name the same screen by,
    /// so the two can be matched up without counting monitors.
    private static func card(number: Int, screen: NSScreen, tint: NSColor) -> NSView {
        let view = NSView(frame: NSRect(origin: .zero, size: card))
        view.wantsLayer = true
        view.layer?.cornerRadius = 26
        view.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.72).cgColor
        view.layer?.borderWidth = 3
        view.layer?.borderColor = tint.withAlphaComponent(0.9).cgColor

        let digit = NSTextField(labelWithString: "\(number)")
        digit.font = .systemFont(ofSize: 108, weight: .bold)
        digit.textColor = tint
        digit.alignment = .center
        digit.frame = NSRect(x: 0, y: 46, width: card.width, height: 122)

        let size = NSTextField(labelWithString:
            "\(Int(screen.frame.width)) × \(Int(screen.frame.height))")
        size.font = .systemFont(ofSize: 15, weight: .medium)
        size.textColor = .white.withAlphaComponent(0.75)
        size.alignment = .center
        size.frame = NSRect(x: 0, y: 22, width: card.width, height: 20)

        view.addSubview(digit)
        view.addSubview(size)
        return view
    }
}
