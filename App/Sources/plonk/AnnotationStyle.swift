import Foundation

struct AnnotationStyle: Codable, Equatable {
    var width = 4
    var color: AnnotationColor = .red

    static func draggedWidth(from start: Int, horizontal: CGFloat, vertical: CGFloat,
                             in range: ClosedRange<Int>) -> Int {
        let steps = ((horizontal + vertical) / 4).rounded(.towardZero)
        return Int((CGFloat(start) + steps).clamped(to: CGFloat(range.lowerBound)...CGFloat(range.upperBound)))
    }

    static func parseWidth(_ draft: String) -> Int? {
        let input = draft.trimmingCharacters(in: .whitespaces)
        guard !input.isEmpty, input.utf8.allSatisfy({ (48...57).contains($0) }) else { return nil }
        return Int(input)
    }
}

extension Annotation.Kind {
    static let styleOrder: [Self] = [.rectangle, .ellipse, .arrow, .highlight, .pen]

    var widthRange: ClosedRange<Int> { (self == .highlight ? 5 : 1)...9999 }
    var widthPath: WritableKeyPath<Config, Int> { stylePath.appending(path: \.width) }
    var colorPath: WritableKeyPath<Config, AnnotationColor> { stylePath.appending(path: \.color) }

    var stylePath: WritableKeyPath<Config, AnnotationStyle> {
        switch self {
        case .rectangle: return \.shotAnnotationStyles.rectangle
        case .ellipse: return \.shotAnnotationStyles.ellipse
        case .arrow: return \.shotAnnotationStyles.arrow
        case .highlight: return \.shotAnnotationStyles.highlight
        case .pen: return \.shotAnnotationStyles.pen
        }
    }
}
