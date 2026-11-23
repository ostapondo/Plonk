import Combine
import CoreGraphics

final class ShotAnnotationState: ObservableObject {
    @Published var tool: Annotation.Kind?
    @Published var styles: AnnotationStyles

    init(defaults: AnnotationStyles) {
        styles = defaults
    }

    func enterEditor() {
        if tool == nil { tool = .arrow }
    }

    @discardableResult
    func beginMark(in history: inout AnnotationHistory, at point: CGPoint, viewWidth: CGFloat) -> Bool {
        guard let tool else { return false }
        let style = styles[keyPath: AnnotationStyles.path(for: tool)]
        history.begin(tool, at: point, style: style, viewWidth: viewWidth)
        return true
    }
}
