import AppKit

final class QuickShotMagnifier: NSView {
    private static let inset: CGFloat = 6
    private let sampler: ShotPixelSampler
    private let colorLabel = NSTextField(labelWithString: "")
    private let copyHint = NSTextField(labelWithString: String(localized: .shotCopyColorHint))
    private var pixel: CGPoint?
    private var neighborhood: ShotPixelSampler.Neighborhood?
    private var zoom: ShotMagnifierZoom = .standard
    var hex: String? { isHidden ? nil : colorLabel.stringValue }

    init(image: CGImage) {
        sampler = ShotPixelSampler(image: image)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedWhite: 0.1, alpha: 1).cgColor
        layer?.cornerRadius = 8
        colorLabel.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        colorLabel.textColor = .white
        copyHint.font = .systemFont(ofSize: 11)
        copyHint.textColor = NSColor(calibratedWhite: 0.8, alpha: 1)
        [colorLabel, copyHint].forEach {
            $0.alignment = .center
            addSubview($0)
        }
        isHidden = true
    }

    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(at point: CGPoint, in area: CGRect, zoom: ShotMagnifierZoom, showsCopyHint: Bool) {
        guard let nextPixel = sampler.pixel(at: point, in: area) else {
            isHidden = true
            return
        }
        if pixel != nextPixel {
            guard let value = sampler.hex(at: nextPixel) else {
                isHidden = true
                return
            }
            colorLabel.stringValue = value
        }
        if pixel != nextPixel || self.zoom != zoom {
            pixel = nextPixel
            showNeighborhood(around: nextPixel, zoom: zoom)
        }

        let inset = Self.inset
        let width = ShotMagnifierZoom.gridWidth
        colorLabel.frame = CGRect(x: inset, y: inset + width + 4, width: width, height: 18)
        copyHint.frame = CGRect(x: inset, y: colorLabel.frame.maxY, width: width, height: 15)
        copyHint.isHidden = !showsCopyHint
        let bottom = showsCopyHint ? copyHint.frame.maxY : colorLabel.frame.maxY
        let size = CGSize(width: width + 2 * inset, height: bottom + inset)
        frame = QuickShotLayout.magnifier(size: size, near: point, area: area)
        isHidden = false
    }

    func setZoom(_ zoom: ShotMagnifierZoom) {
        guard let pixel, self.zoom != zoom else { return }
        showNeighborhood(around: pixel, zoom: zoom)
    }

    private func showNeighborhood(around pixel: CGPoint, zoom: ShotMagnifierZoom) {
        neighborhood = sampler.neighborhood(around: pixel, side: zoom.cells)
        self.zoom = zoom
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext, let neighborhood else { return }
        let cell = zoom.cellSize
        let side = CGFloat(zoom.cells) * cell
        let inset = Self.inset + floor((ShotMagnifierZoom.gridWidth - side) / 2)
        let grid = CGRect(x: inset, y: inset, width: side, height: side)
        context.setFillColor(NSColor(calibratedWhite: 0.2, alpha: 1).cgColor)
        context.fill(grid)

        let image = neighborhood.image
        let patch = CGRect(x: grid.minX + neighborhood.offset.x * cell,
                           y: grid.minY + neighborhood.offset.y * cell,
                           width: CGFloat(image.width) * cell, height: CGFloat(image.height) * cell)
        context.saveGState()
        context.translateBy(x: patch.minX, y: patch.maxY)
        context.scaleBy(x: 1, y: -1)
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(origin: .zero, size: patch.size))
        context.restoreGState()

        let lines = CGMutablePath()
        for index in 0...zoom.cells {
            let offset = CGFloat(index) * cell
            let x = grid.minX + offset
            let y = grid.minY + offset
            lines.move(to: CGPoint(x: x, y: grid.minY))
            lines.addLine(to: CGPoint(x: x, y: grid.maxY))
            lines.move(to: CGPoint(x: grid.minX, y: y))
            lines.addLine(to: CGPoint(x: grid.maxX, y: y))
        }
        context.addPath(lines)
        context.setStrokeColor(NSColor(calibratedWhite: 0.45, alpha: 0.5).cgColor)
        context.setLineWidth(1)
        context.strokePath()
        drawCrosshair(in: grid, cell: cell, context: context)
    }

    private func drawCrosshair(in grid: CGRect, cell: CGFloat, context: CGContext) {
        let center = CGRect(x: grid.midX - cell / 2, y: grid.midY - cell / 2, width: cell, height: cell)
        let crosshair = CGMutablePath()
        crosshair.addRect(center)
        crosshair.move(to: CGPoint(x: grid.minX, y: grid.midY))
        crosshair.addLine(to: CGPoint(x: center.minX, y: grid.midY))
        crosshair.move(to: CGPoint(x: center.maxX, y: grid.midY))
        crosshair.addLine(to: CGPoint(x: grid.maxX, y: grid.midY))
        crosshair.move(to: CGPoint(x: grid.midX, y: grid.minY))
        crosshair.addLine(to: CGPoint(x: grid.midX, y: center.minY))
        crosshair.move(to: CGPoint(x: grid.midX, y: center.maxY))
        crosshair.addLine(to: CGPoint(x: grid.midX, y: grid.maxY))
        context.addPath(crosshair)
        context.setStrokeColor(NSColor.black.cgColor)
        context.setLineWidth(3)
        context.strokePath()
        context.addPath(crosshair)
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1)
        context.strokePath()
    }
}
