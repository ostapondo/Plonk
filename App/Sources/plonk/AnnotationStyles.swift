struct AnnotationStyles: Codable, Equatable {
    var rectangle = AnnotationStyle()
    var ellipse = AnnotationStyle()
    var arrow = AnnotationStyle()
    var highlight = AnnotationStyle(width: 20, color: .yellow)
    var pen = AnnotationStyle()

    static func path(for kind: Annotation.Kind) -> WritableKeyPath<Self, AnnotationStyle> {
        switch kind {
        case .rectangle: return \.rectangle
        case .ellipse: return \.ellipse
        case .arrow: return \.arrow
        case .highlight: return \.highlight
        case .pen: return \.pen
        }
    }
}
