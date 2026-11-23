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

extension AnnotationStyles {
    private enum CodingKeys: String, CodingKey { case rectangle, ellipse, arrow, highlight, pen }

    /// A value that does not read falls back to that tool's own default, so a bad highlight
    /// colour leaves it yellow; an entry that is not a style at all keeps the default whole.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        func style(_ key: CodingKeys, _ fallback: AnnotationStyle) -> AnnotationStyle {
            guard let fields = try? container.nestedContainer(keyedBy: AnnotationStyle.CodingKeys.self,
                                                              forKey: key) else { return fallback }
            return AnnotationStyle.lenient(fields, over: fallback)
        }
        rectangle = style(.rectangle, rectangle)
        ellipse = style(.ellipse, ellipse)
        arrow = style(.arrow, arrow)
        highlight = style(.highlight, highlight)
        pen = style(.pen, pen)
    }
}
