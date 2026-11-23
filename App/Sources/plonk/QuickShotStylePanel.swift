import SwiftUI

final class QuickShotStylePanel: NSView {
    private var host: NSHostingView<Content>?
    private var placement: QuickShotLayout.StylePlacement?

    override var isFlipped: Bool { true }

    func show(_ kind: Annotation.Kind, annotation: ShotAnnotationState, anchor: CGRect, toolbar: CGRect,
              avoiding obstacles: [CGRect], area: CGRect) {
        let position = QuickShotLayout.stylePanel(
            size: QuickShotStyleControls.size,
            help: CGSize(width: QuickShotStyleControls.helpWidth, height: QuickShotStyleControls.helpHeight),
            anchor: anchor, toolbar: toolbar, avoiding: obstacles, area: area
        )
        guard position != placement || host?.rootView.kind != kind else { return }
        placement = position
        frame = position.panel.union(position.help).insetBy(dx: -8, dy: -8)
        let content = Content(kind: kind, annotation: annotation, position: position, frame: frame)
        if let host {
            host.rootView = content
            host.frame = bounds
        } else {
            let host = NSHostingView(rootView: content)
            host.sizingOptions = []
            host.frame = bounds
            addSubview(host)
            self.host = host
        }
        window?.invalidateCursorRects(for: self)
    }

    func dismiss() {
        guard let host else { return }
        host.removeFromSuperview()
        self.host = nil
        placement = nil
        window?.invalidateCursorRects(for: self)
    }

    func contains(_ point: CGPoint) -> Bool {
        placement?.panel.contains(point) == true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // The arrow, hover help and shadow can extend beyond the controls.
        guard contains(point) else { return nil }
        return super.hitTest(point) ?? self
    }

    override func mouseDown(with event: NSEvent) {}

    override func resetCursorRects() {
        if let placement {
            addCursorRect(placement.panel.offsetBy(dx: -frame.minX, dy: -frame.minY), cursor: .arrow)
        }
    }

    private struct Content: View {
        let kind: Annotation.Kind
        @ObservedObject var annotation: ShotAnnotationState
        let position: QuickShotLayout.StylePlacement
        let frame: CGRect

        var body: some View {
            Controls(kind: kind, style: $annotation.styles[dynamicMember: AnnotationStyles.path(for: kind)],
                     position: position, origin: frame.origin)
                .id(kind)
                .frame(width: frame.width, height: frame.height)
        }
    }

    private struct Controls: View {
        let kind: Annotation.Kind
        @Binding var style: AnnotationStyle
        let position: QuickShotLayout.StylePlacement
        let origin: CGPoint
        @State private var widthHovered = false

        var body: some View {
            ZStack {
                QuickShotStyleControls(kind: kind, style: $style, widthHovered: $widthHovered)
                    .position(x: position.panel.midX - origin.x, y: position.panel.midY - origin.y)
                if !position.beside { pointer }
                if widthHovered {
                    QuickShotStyleControls.widthHelp
                        .frame(maxWidth: position.help.width)
                        .position(x: position.help.midX - origin.x, y: position.help.midY - origin.y)
                }
            }
        }

        private var pointer: some View {
            let x = position.anchorX - origin.x
            let y = (position.above ? position.panel.maxY : position.panel.minY) - origin.y
            let tip = y + (position.above ? 5 : -5)
            return Path { path in
                path.move(to: CGPoint(x: x - 5, y: y))
                path.addLine(to: CGPoint(x: x, y: tip))
                path.addLine(to: CGPoint(x: x + 5, y: y))
            }
            .fill(QuickShotStyleControls.surface)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
