struct AnnotationStyles: Codable, Equatable {
    var rectangle = AnnotationStyle()
    var ellipse = AnnotationStyle()
    var arrow = AnnotationStyle()
    var highlight = AnnotationStyle(width: 20, color: .yellow)
    var pen = AnnotationStyle()
}
