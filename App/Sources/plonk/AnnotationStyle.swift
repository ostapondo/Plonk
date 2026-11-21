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
    static let quickShotOrder: [Self] = [.rectangle, .ellipse, .arrow, .pen, .highlight]

    var widthRange: ClosedRange<Int> { (self == .highlight ? 5 : 1)...9999 }
    var widthPath: WritableKeyPath<Config, Int> { stylePath.appending(path: \.width) }

    var stylePath: WritableKeyPath<Config, AnnotationStyle> {
        (\Config.shotAnnotationStyles).appending(path: AnnotationStyles.path(for: self))
    }
}
