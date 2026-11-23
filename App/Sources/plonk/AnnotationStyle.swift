import Foundation

struct AnnotationStyle: Codable, Equatable {
    var width = 4
    var color: AnnotationColor = .red

    static func draggedWidth(from start: Int, horizontal: CGFloat, vertical: CGFloat,
                             in range: ClosedRange<Int>) -> Int {
        let steps = ((horizontal + vertical) / 4).rounded(.towardZero)
        return Int((CGFloat(start) + steps).clamped(to: CGFloat(range.lowerBound)...CGFloat(range.upperBound)))
    }

    static let maxWidthDigits = 4

    /// What the field should hold after a keystroke, or nil to refuse it. Full-width digits
    /// from a CJK input method count as digits, and leading zeros do not count towards the
    /// limit, so pasting `00012` gives 12. A number that would need a fifth digit is refused
    /// whole rather than cut down to a different one.
    static func normalizeWidthDraft(_ draft: String) -> String? {
        let input = asciiDigits(draft.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !input.isEmpty, containsOnlyDigits(input) else { return input }
        let significant = String(input.drop { $0 == "0" })
        let number = significant.isEmpty ? "0" : significant
        return number.utf8.count > maxWidthDigits ? nil : number
    }

    static func parseWidth(_ draft: String) -> Int? {
        let input = asciiDigits(draft.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !input.isEmpty, containsOnlyDigits(input) else { return nil }
        return Int(input)
    }

    private static func asciiDigits(_ input: String) -> String {
        String(String.UnicodeScalarView(input.unicodeScalars.map { scalar in
            (0xFF10...0xFF19).contains(scalar.value) ? Unicode.Scalar(scalar.value - 0xFF10 + 48) ?? scalar : scalar
        }))
    }

    private static func containsOnlyDigits(_ input: String) -> Bool {
        input.utf8.allSatisfy { (48...57).contains($0) }
    }
}

extension AnnotationStyle {
    enum CodingKeys: String, CodingKey { case width, color }

    init(from decoder: Decoder) throws {
        self = Self.lenient(try decoder.container(keyedBy: CodingKeys.self), over: Self())
    }

    /// Each field that does not read as what it should keeps `fallback`'s value, so a colour a
    /// newer release added or a hand edit costs that one value rather than the config. A
    /// fractional width is rounded, and `Config.clamp` holds it inside the tool's range.
    static func lenient(_ container: KeyedDecodingContainer<CodingKeys>, over fallback: Self) -> Self {
        var style = fallback
        if let width = try? container.decode(Double.self, forKey: .width), width.isFinite {
            style.width = Int(width.rounded().clamped(to: -1_000_000...1_000_000))
        }
        if let name = try? container.decode(String.self, forKey: .color),
           let color = AnnotationColor(rawValue: name.lowercased()) {
            style.color = color
        }
        return style
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
