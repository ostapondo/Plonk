import CoreGraphics

enum QuickShotLayout {
    static let controlInset: CGFloat = 12
    static let selectionToolbarGap: CGFloat = 12

    struct StylePlacement: Equatable {
        let panel: CGRect
        let help: CGRect
        let anchorX: CGFloat
        let above: Bool
        /// Set when the panel sits level with the toolbar, so no pointer is drawn.
        var beside = false
    }

    /// The panel goes under the toolbar, over it, then level with it on either side, taking
    /// the first spot that stays on screen and off every obstacle: the selection is where
    /// marks start, so a panel over it would swallow the clicks.
    static func stylePanel(size: CGSize, help: CGSize, anchor: CGRect, toolbar: CGRect,
                           avoiding obstacles: [CGRect], area: CGRect) -> StylePlacement {
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
        let besideY = toolbar.midY - size.height / 2
        let right = CGRect(x: toolbar.maxX + gap, y: besideY, width: size.width, height: size.height)
        let left = right.offsetBy(dx: toolbar.minX - gap - size.width - right.minX, dy: 0)
        func onScreen(_ rect: CGRect) -> Bool {
            rect.minX >= area.minX && rect.maxX <= area.maxX && rect.minY >= area.minY && rect.maxY <= area.maxY
        }
        func clear(_ rect: CGRect) -> Bool { onScreen(rect) && !obstacles.contains { $0.intersects(rect) } }
        func overlap(_ rect: CGRect) -> CGFloat {
            obstacles.reduce(0) { total, obstacle in
                let shared = obstacle.intersection(rect)
                return total + (shared.isNull ? 0 : shared.width * shared.height)
            }
        }
        let candidates = [below, above, right, left]
        // With a selection nearly the height of the screen every spot touches it; then the
        // panel takes the one that covers least of it.
        let panel = candidates.first(where: clear)
            ?? candidates.filter(onScreen).min { overlap($0) < overlap($1) }
            ?? (below.maxY > area.maxY && above.minY >= area.minY ? above : below)
        let useAbove = panel == above
        let beside = panel == right || panel == left
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
                              above: useAbove, beside: beside)
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

    /// `reserve` is kept free under the toolbar for the style panel, so picking a tool never
    /// puts the panel over the image.
    static func fixed(image: CGSize, toolbar: CGSize, reserve: CGFloat = 0,
                      area: CGRect) -> (image: CGRect, toolbar: CGRect) {
        let area = area.insetBy(dx: controlInset, dy: controlInset)
        let gap: CGFloat = 12
        let panelSpace = reserve > 0 ? gap + reserve : 0
        let bar = bottomToolbar(toolbar, in: area).offsetBy(dx: 0, dy: -panelSpace)
        let previewHeight = max(1, bar.minY - gap - area.minY)
        let scale = min(1, area.width / image.width, previewHeight / image.height)
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        let top = area.minY + (previewHeight - size.height) / 2
        return (CGRect(x: area.midX - size.width / 2, y: top, width: size.width, height: size.height), bar)
    }

    static func place(dimensions: CGSize, toolbar: CGSize, selection: CGRect, area: CGRect)
        -> (dimensions: CGRect, toolbar: CGRect) {
        let area = area.insetBy(dx: controlInset, dy: controlInset)
        let bar = regionToolbar(toolbar, outside: selection, in: area)
        let xLimit = area.minX...max(area.minX, area.maxX - dimensions.width)
        let x = selection.minX.clamped(to: xLimit)
        let below = max(area.minY, selection.maxY + 10)
        let candidates = [selection.minY - 10 - dimensions.height,
                          below, max(below, bar.maxY + 8), bar.minY - 8 - dimensions.height]
        for y in candidates {
            let label = CGRect(origin: CGPoint(x: x, y: y), size: dimensions)
            if area.contains(label), !label.intersects(selection), !label.intersects(bar) {
                return (label, bar)
            }
        }

        // An interactive badge inside the selection must leave its top handles reachable.
        let handle = ShotSelection.handleLength
        let label = CGRect(x: (selection.minX + handle).clamped(to: xLimit),
                           y: max(selection.minY, area.minY) + handle,
                           width: dimensions.width, height: dimensions.height)
        return (label, bar)
    }

    private static func regionToolbar(_ size: CGSize, outside selection: CGRect, in area: CGRect) -> CGRect {
        let gap = selectionToolbarGap
        let lowestY = area.maxY - size.height
        let below = selection.maxY + gap
        if below >= area.minY, below <= lowestY {
            let x = (selection.midX - size.width / 2).clamped(to: area.minX...max(area.minX, area.maxX - size.width))
            return CGRect(origin: CGPoint(x: x, y: below), size: size)
        }

        let left = selection.minX - area.minX
        let right = area.maxX - selection.maxX
        guard max(left, right) >= size.width + gap, lowestY >= area.minY else {
            return bottomToolbar(size, in: area)
        }
        let x = left >= right ? selection.minX - gap - size.width : selection.maxX + gap
        let y = (selection.maxY - size.height).clamped(to: area.minY...lowestY)
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    private static func bottomToolbar(_ size: CGSize, in area: CGRect) -> CGRect {
        CGRect(origin: CGPoint(x: area.midX - size.width / 2, y: area.maxY - size.height), size: size)
    }
}
