import AppKit
import SwiftUI

// A transient panel in the top-right corner, where macOS puts its own
// notifications. Used instead of Notification Center: no extra permission, no
// entry left behind, and it can show what just happened rather than describe it.

final class HUD {
    static let shared = HUD()

    private var window: NSWindow?
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
    func showCompact(_ text: String) {
        token += 1
        let panel = window ?? makeWindow()
        window = panel
        panel.contentView = NSHostingView(rootView: CompactHUDView(text: text))
        panel.setContentSize(panel.contentView?.fittingSize ?? NSSize(width: 120, height: 40))
        HUD.placeInCorner(panel)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
    }

    func hide() {
        token += 1
        window?.orderOut(nil)
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

private struct CompactHUDView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.callout, design: .monospaced).weight(.medium))
            .monospacedDigit()
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
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
