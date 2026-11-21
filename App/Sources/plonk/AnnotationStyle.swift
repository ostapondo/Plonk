import Foundation

struct AnnotationStyle: Codable, Equatable {
    var width = 4
    var color: AnnotationColor = .red

    static func draggedWidth(from start: Int, horizontal: CGFloat, vertical: CGFloat,
                             in range: ClosedRange<Int>) -> Int {
        let steps = ((horizontal + vertical) / 4).rounded(.towardZero)
        return Int((CGFloat(start) + steps).clamped(to: CGFloat(range.lowerBound)...CGFloat(range.upperBound)))
    }

    static func normalizeWidthDraft(_ draft: String) -> String {
        let input = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard input.utf8.count > 4, containsOnlyDigits(input) else { return input }
        return String(input.prefix(4))
    }

    static func parseWidth(_ draft: String) -> Int? {
        let input = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard containsOnlyDigits(input) else { return nil }
        return Int(input)
    }

    private static func containsOnlyDigits(_ input: String) -> Bool {
        input.utf8.allSatisfy { (48...57).contains($0) }
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
