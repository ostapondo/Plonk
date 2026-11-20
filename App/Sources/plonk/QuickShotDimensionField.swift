import AppKit

final class QuickShotDimensionField: NSTextField {
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
}
