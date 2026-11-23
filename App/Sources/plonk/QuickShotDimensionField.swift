import AppKit

final class QuickShotDimensionField: NSTextField {
    var textBaselineFromTop: CGFloat {
        firstBaselineOffsetFromTop + QuickShotDimensionCell.verticalTextInset
    }

    init(title: LocalizedStringResource) {
        super.init(frame: .zero)
        let dimensionCell = QuickShotDimensionCell(textCell: "")
        dimensionCell.usesSingleLineMode = true
        cell = dimensionCell
        isEditable = true
        isSelectable = true
        isBordered = false
        drawsBackground = false
        focusRingType = .none
        font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        textColor = .white
        alignment = .center
        let label = String(localized: title)
        setAccessibilityLabel(label)
        toolTip = label
    }

    required init?(coder: NSCoder) { nil }

    func fittedWidth(maximumLength: Int) -> CGFloat {
        let length = max(1, currentEditor().map { min(maximumLength, $0.string.count) } ?? stringValue.count)
        let attributes: [NSAttributedString.Key: Any] = [.font: font ?? NSFont.systemFont(ofSize: 14)]
        let digitWidth = ("0" as NSString).size(withAttributes: attributes).width
        return (digitWidth * CGFloat(length)).rounded(.up) + 8
    }
}
