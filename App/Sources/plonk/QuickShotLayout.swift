import CoreGraphics

enum QuickShotLayout {
    static func toolbar(dividers: [Bool], availableWidth: CGFloat) -> (size: CGSize, frames: [CGRect]) {
        let inset: CGFloat = 7
        let padding: CGFloat = 5
        let buttonWidth: CGFloat = availableWidth <= 620 ? 30 : 34
        let buttonHeight: CGFloat = 32
        let gap: CGFloat = 3
        let limit = max(availableWidth - inset, buttonWidth + inset)
        var x = inset
        var y = padding
        var right = inset
        let frames = dividers.map { divider in
            let width: CGFloat = divider ? 9 : buttonWidth
            if x > inset, x + width > limit {
                x = inset
                y += buttonHeight + gap
            }
            let frame = CGRect(x: x, y: y, width: width, height: buttonHeight)
            right = max(right, frame.maxX)
            x = frame.maxX + gap
            return frame
        }
        return (CGSize(width: right + inset, height: y + buttonHeight + padding), frames)
    }

    static func fixed(image: CGSize, toolbar: CGSize, area: CGRect) -> (image: CGRect, toolbar: CGRect) {
        let area = area.insetBy(dx: 10, dy: 10)
        let gap: CGFloat = 12
        let scale = min(1, area.width / image.width, max(1, area.height - toolbar.height - gap) / image.height)
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        let top = area.midY - (size.height + gap + toolbar.height) / 2
        return (CGRect(x: area.midX - size.width / 2, y: top, width: size.width, height: size.height),
                CGRect(x: area.midX - toolbar.width / 2, y: top + size.height + gap,
                       width: toolbar.width, height: toolbar.height))
    }

    static func place(dimensions: CGSize, toolbar: CGSize, selection: CGRect, area: CGRect)
        -> (dimensions: CGRect, toolbar: CGRect) {
        let area = area.insetBy(dx: 5, dy: 5)
        func frame(for size: CGSize, y: CGFloat) -> CGRect {
            CGRect(x: selection.minX.clamped(to: area.minX...max(area.minX, area.maxX - size.width)),
                   y: y.clamped(to: area.minY...max(area.minY, area.maxY - size.height)),
                   width: size.width, height: size.height)
        }
        let below = selection.maxY + 16
        var label = frame(for: dimensions, y: selection.minY - 10 - dimensions.height)
        let above = label.minY - 8 - toolbar.height
        let toolbarY = below + toolbar.height > area.maxY && above >= area.minY ? above : below
        let bar = frame(for: toolbar, y: toolbarY)
        if label.intersects(bar) {
            let afterBar = bar.maxY + 8
            let beforeBar = bar.minY - 8 - dimensions.height
            label = frame(for: dimensions, y: afterBar + dimensions.height <= area.maxY ? afterBar : beforeBar)
        }
        return (label, bar)
    }
}
