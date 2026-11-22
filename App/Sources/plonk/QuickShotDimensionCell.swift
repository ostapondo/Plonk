import AppKit

final class QuickShotDimensionCell: NSTextFieldCell {
    // AppKit's single-line cell leaves the digits above the center of the badge.
    static let verticalTextInset: CGFloat = 3

    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        super.drawingRect(forBounds: rect).offsetBy(dx: 0, dy: Self.verticalTextInset)
    }

    override func setUpFieldEditorAttributes(_ textObj: NSText) -> NSText {
        let editor = super.setUpFieldEditorAttributes(textObj)
        if let textView = editor as? NSTextView {
            textView.textContainer?.lineFragmentPadding = 2
            textView.textContainerInset = CGSize(width: 0, height: Self.verticalTextInset)
            textView.insertionPointColor = .white
            textView.selectedTextAttributes = [
                .backgroundColor: QuickShotBackdrop.accent,
                .foregroundColor: NSColor.white,
            ]
        }
        return editor
    }
}
