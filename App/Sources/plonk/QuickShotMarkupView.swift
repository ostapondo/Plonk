import SwiftUI

final class QuickShotMarkupView: NSHostingView<AnnotationLayer> {
    init(frame: CGRect) {
        super.init(rootView: AnnotationLayer(annotations: []))
        self.frame = frame
        sizingOptions = []
    }

    required init(rootView: AnnotationLayer) { super.init(rootView: rootView) }
    @objc required dynamic init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func show(_ history: AnnotationHistory, clippedTo frame: CGRect?) {
        isHidden = frame == nil
        rootView = AnnotationLayer(annotations: history.annotations, live: history.live, clip: frame)
    }
}
