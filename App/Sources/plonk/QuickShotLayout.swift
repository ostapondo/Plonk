import CoreGraphics

enum QuickShotLayout {
    struct MagnifierPlacement {
        let frame: CGRect
        let drawingOffset: CGPoint
    }

    static func magnifier(size: CGSize, near pointer: CGPoint, area: CGRect,
                          avoiding selection: CGRect?) -> MagnifierPlacement? {
        let gap: CGFloat = 10
        let left = pointer.x - gap - size.width
        let right = pointer.x + gap
        let above = pointer.y - gap - size.height
        let below = pointer.y + gap
        let origins = [(left, above), (right, above), (right, below), (left, below)]
        let candidates: [(full: CGRect, visible: CGRect)] = origins.compactMap { x, y in
            let full = CGRect(origin: CGPoint(x: x, y: y), size: size)
            let visible = full.intersection(area)
            return visible.isEmpty ? nil : (full, visible)
        }
        let safeArea = area.insetBy(dx: 5, dy: 5)
        let clear = candidates.filter { selection?.intersects($0.visible) != true }
        let fallback = clear.isEmpty ? candidates : clear
        guard let best = clear.first(where: { safeArea.contains($0.full) }) ?? fallback.max(by: {
            $0.visible.width * $0.visible.height < $1.visible.width * $1.visible.height
        }) else { return nil }
        // Keep the original drawing origin when the visible frame is cropped.
        return MagnifierPlacement(frame: best.visible,
                                  drawingOffset: CGPoint(x: best.full.minX - best.visible.minX,
                                                         y: best.full.minY - best.visible.minY))
    }

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
        let area = area.insetBy(dx: 10, dy: 10)
        let gap: CGFloat = 12
        let below = gap + toolbar.height + (reserve > 0 ? gap + reserve : 0)
        let scale = min(1, area.width / image.width, max(1, area.height - below) / image.height)
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        let top = area.midY - (size.height + below) / 2
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
