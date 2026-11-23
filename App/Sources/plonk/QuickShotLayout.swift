import CoreGraphics

enum QuickShotLayout {
    struct StylePlacement: Equatable {
        let panel: CGRect
        let help: CGRect
        let anchorX: CGFloat
        let above: Bool
    }

    static func stylePanel(size: CGSize, help: CGSize, anchor: CGRect, toolbar: CGRect,
                           avoiding obstacle: CGRect?, area: CGRect) -> StylePlacement {
        let area = area.insetBy(dx: 5, dy: 5)
        let gap: CGFloat = 12
        func fittingX(_ x: CGFloat, width: CGFloat) -> CGFloat {
            x.clamped(to: area.minX...max(area.minX, area.maxX - width))
        }
        let x = (anchor.midX - size.width / 2)
            .clamped(to: toolbar.minX...max(toolbar.minX, toolbar.maxX - size.width))
        let below = CGRect(x: fittingX(x, width: size.width), y: toolbar.maxY + gap,
                           width: size.width, height: size.height)
        let above = below.offsetBy(dx: 0, dy: toolbar.minY - gap - size.height - below.minY)
        let fitsAbove = above.minY >= area.minY && obstacle?.intersects(above) != true
        let needsAbove = below.maxY > area.maxY || obstacle?.intersects(below) == true
        let useAbove = needsAbove && (fitsAbove || (below.maxY > area.maxY && above.minY >= area.minY))
        let panel = useAbove ? above : below
        let helpWidth = min(help.width, area.width)
        let helpBelow = panel.maxY + 3
        let helpAbove = panel.minY - help.height - 3
        let preferredY = useAbove ? helpAbove : helpBelow
        let alternateY = useAbove ? helpBelow : helpAbove
        let helpY = (preferredY >= area.minY && preferredY + help.height <= area.maxY ? preferredY : alternateY)
            .clamped(to: area.minY...max(area.minY, area.maxY - help.height))
        return StylePlacement(panel: panel,
                              help: CGRect(x: fittingX(panel.midX - helpWidth / 2, width: helpWidth),
                                           y: helpY, width: helpWidth, height: help.height),
                              anchorX: anchor.midX.clamped(to: (panel.minX + 16)...(panel.maxX - 16)),
                              above: useAbove)
    }

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
        let labelAbove = selection.minY - 10 - dimensions.height
        var label = frame(for: dimensions, y: labelAbove)
        let above = label.minY - 8 - toolbar.height
        let toolbarY = below + toolbar.height > area.maxY && above >= area.minY ? above : below
        let bar = frame(for: toolbar, y: toolbarY)
        let afterBar = bar.maxY + 8
        let fitsAfterBar = afterBar + dimensions.height <= area.maxY
        if labelAbove < area.minY {
            // Clamped down it would sit on the top edge and swallow its handles. The badge
            // is interactive, so it goes after the toolbar, or inside past the corner handles.
            label = fitsAfterBar ? frame(for: dimensions, y: afterBar) : CGRect(
                x: (selection.minX + ShotSelection.handleLength)
                    .clamped(to: area.minX...max(area.minX, area.maxX - dimensions.width)),
                y: max(selection.minY, area.minY) + ShotSelection.handleLength,
                width: dimensions.width, height: dimensions.height)
        } else if label.intersects(bar) {
            let beforeBar = bar.minY - 8 - dimensions.height
            label = frame(for: dimensions, y: fitsAfterBar ? afterBar : beforeBar)
        }
        return (label, bar)
    }
}
