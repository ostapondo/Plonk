import AppKit
import SwiftUI

// A transient panel in the top-right corner, where macOS puts its own
// notifications. Used instead of Notification Center: no extra permission, no
// entry left behind, and it can show what just happened rather than describe it.

final class HUD {
    static let shared = HUD()

    private var window: NSWindow?
    /// Separate from `window`: the readout is up while a drag is, and a notice
    /// arriving in the middle of one must not replace it.
    private var compactWindow: NSWindow?
    private let compactLabel = NSTextField(labelWithString: "")
    private var token = 0

    private init() {}

    func show(_ text: String, image: NSImage? = nil, duration: TimeInterval = 2.2) {
        token += 1
        let generation = token

        let panel = window ?? makeWindow()
        window = panel
        panel.contentView = NSHostingView(rootView: HUDView(text: text, image: image))
        panel.setContentSize(panel.contentView?.fittingSize ?? NSSize(width: 240, height: 120))
        HUD.placeInCorner(panel)
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self, token == generation else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                panel.animator().alphaValue = 0
            } completionHandler: { [weak self] in
                guard let self, token == generation else { return }
                panel.orderOut(nil)
            }
        }
    }

    /// A small readout that stays up until something hides it — the size of a
    /// window while it is being resized, where the checkmark and the fade of
    /// `show` would both be wrong.
    ///
    /// This runs on every event of a drag, so the view is built once and only
    /// its text changes after that; rebuilding a hosting view per frame was
    /// measurably worse than the resize it was describing.
    func showCompact(_ text: String) {
        // Deliberately does not touch `token`: that counter is the notice
        // panel's fade-out generation, and a drag readout must not cancel a
        // notice's dismissal and leave it on screen for good.
        let panel = compactWindow ?? makeCompactWindow()
        compactWindow = panel
        compactLabel.stringValue = text
        compactLabel.sizeToFit()
        panel.setContentSize(NSSize(width: compactLabel.frame.width + 28,
                                    height: compactLabel.frame.height + 18))
        compactLabel.frame = panel.contentView?.bounds.insetBy(dx: 14, dy: 9) ?? compactLabel.frame
        // Bottom centre, not the corner: a notice may well be up in the corner
        // at the same time, and two panels stacked on each other read as one
        // broken one.
        HUD.placeAtBottom(panel)
        panel.alphaValue = 1
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    private func makeCompactWindow() -> NSWindow {
        let panel = makeWindow()
        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 10
        effect.layer?.masksToBounds = true
        compactLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        compactLabel.alignment = .center
        compactLabel.autoresizingMask = [.width, .height]
        effect.addSubview(compactLabel)
        panel.contentView = effect
        return panel
    }

    /// Hides the readout only. The notice panel dismisses itself.
    func hide() {
        compactWindow?.orderOut(nil)
    }

    private func makeWindow() -> NSWindow {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .screenSaver
        panel.ignoresMouseEvents = true
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        return panel
    }

    static let margin: CGFloat = 14

    /// Bottom centre of whichever screen the cursor is on.
    static func placeAtBottom(_ panel: NSWindow) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.minY + margin * 3))
    }

    /// Top-right of whichever screen the cursor is on. `visibleFrame` already
    /// excludes the menu bar, so the margin is only breathing room.
    static func placeInCorner(_ panel: NSWindow) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: frame.maxX - size.width - margin,
                                     y: frame.maxY - size.height - margin))
    }
}

private struct HUDView: View {
    let text: String
    let image: NSImage?

    var body: some View {
        VStack(spacing: 12) {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 260, maxHeight: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.18)))
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.secondary)
            }
            Text(text).font(.callout.weight(.medium))
        }
        .padding(20)
        .frame(minWidth: 210)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
