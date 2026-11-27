import AppKit

final class QuickShotMagnifier: NSView {
    private static let contentWidth: CGFloat = 120
    private static let borderWidth: CGFloat = 2
    private static let size: CGSize = {
        let side = contentWidth + 2 * borderWidth
        return CGSize(width: side, height: side)
    }()
    private static let sampledCell = CGRect(x: size.width / 2 - 2, y: size.height / 2 - 2, width: 4, height: 4)
    private static let badgeBorder: CGFloat = 2
    private static let hexStyle: [NSAttributedString.Key: Any] = [
        .font: NSFont(name: "Inter-Regular", size: 10) ?? NSFont.systemFont(ofSize: 10),
        .foregroundColor: NSColor.white,
    ]

    private let sampler: ShotPixelSampler
    private var pixel: CGPoint?
    private var sampledHex: String?
    private var colorLabel: (text: NSAttributedString, size: CGSize)?
    private var neighborhood: ShotPixelSampler.Neighborhood?
    private var zoom: ShotMagnifierZoom = .standard
    private var drawingOffset = CGPoint.zero
    var hex: String? { isHidden ? nil : sampledHex }

    init(image: CGImage) {
        sampler = ShotPixelSampler(image: image)
        super.init(frame: CGRect(origin: .zero, size: Self.size))
        hide()
    }

    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func hide() {
        isHidden = true
    }

    func update(at point: CGPoint, in area: CGRect, avoiding obstacle: CGRect?, zoom: ShotMagnifierZoom) {
        guard let nextPixel = sampler.pixel(at: point, in: area) else { return hide() }
        if pixel != nextPixel {
            guard let hex = sampler.hex(at: nextPixel) else { return hide() }
            sampledHex = hex
            let digits = hex.dropFirst()
            let grouped = "#\(digits.prefix(2)) \(digits.dropFirst(2).prefix(2)) \(digits.suffix(2))"
            let label = NSAttributedString(string: grouped, attributes: Self.hexStyle)
            colorLabel = (label, label.size())
        }
        if pixel != nextPixel || self.zoom != zoom {
            pixel = nextPixel
            showNeighborhood(around: nextPixel, zoom: zoom)
        }

        guard let colorLabel else { return hide() }
        let details = Self.sampledCell.union(Self.badgeFrame(for: colorLabel.size))
        guard let placement = QuickShotLayout.magnifier(size: Self.size, details: details, near: point,
                                                         area: area, avoiding: obstacle) else { return hide() }
        if frame.size != placement.frame.size || drawingOffset != placement.drawingOffset {
            drawingOffset = placement.drawingOffset
            needsDisplay = true
        }
        frame = placement.frame
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
        guard let context = NSGraphicsContext.current?.cgContext, let neighborhood, let colorLabel else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: bounds)
        let panel = CGRect(origin: drawingOffset, size: Self.size)
        let border = Self.borderWidth
        let viewport = panel.insetBy(dx: border, dy: border)
        drawPixels(neighborhood, in: viewport, context: context)

        let blue = QuickShotBackdrop.accent
        context.setStrokeColor(blue.cgColor)
        drawCrosshair(in: viewport, color: blue, context: context)
        let outline = panel.insetBy(dx: border / 2, dy: border / 2)
        context.stroke(outline, width: border)

        let labelSize = colorLabel.size
        let badgeBorder = Self.badgeBorder
        let badge = Self.badgeFrame(for: labelSize).offsetBy(dx: drawingOffset.x, dy: drawingOffset.y)
        context.setFillColor(CGColor(srgbRed: 34 / 255, green: 34 / 255, blue: 34 / 255, alpha: 1))
        context.fill(badge)
        context.stroke(badge.insetBy(dx: badgeBorder / 2, dy: badgeBorder / 2), width: badgeBorder)
        colorLabel.text.draw(at: CGPoint(x: badge.midX - labelSize.width / 2, y: badge.midY - labelSize.height / 2))
    }

    private static func badgeFrame(for labelSize: CGSize) -> CGRect {
        let horizontalInset = badgeBorder + 1
        let width = max(52, ceil(labelSize.width) + 2 * horizontalInset)
        let height: CGFloat = 14
        let inset = borderWidth / 2
        return CGRect(x: inset, y: size.height - inset - height, width: width, height: height)
    }

    private func drawPixels(_ neighborhood: ShotPixelSampler.Neighborhood, in viewport: CGRect, context: CGContext) {
        let cell = viewport.width / CGFloat(zoom.pixelsPerRow)
        let gridSide = CGFloat(zoom.cells) * cell
        let image = neighborhood.image
        let patch = CGRect(x: viewport.midX - gridSide / 2 + neighborhood.offset.x * cell,
                           y: viewport.midY - gridSide / 2 + neighborhood.offset.y * cell,
                           width: CGFloat(image.width) * cell, height: CGFloat(image.height) * cell)
        context.saveGState()
        context.clip(to: viewport)
        context.setFillColor(NSColor(calibratedWhite: 0.2, alpha: 1).cgColor)
        context.fill(viewport)
        context.translateBy(x: patch.minX, y: patch.maxY)
        context.scaleBy(x: 1, y: -1)
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(origin: .zero, size: patch.size))
        context.restoreGState()
    }

    private func drawCrosshair(in viewport: CGRect, color: NSColor, context: CGContext) {
        let center = Self.sampledCell.offsetBy(dx: drawingOffset.x, dy: drawingOffset.y)
        context.setFillColor(color.withAlphaComponent(0.12).cgColor)
        context.fill([
            CGRect(x: viewport.minX, y: center.minY, width: center.minX - viewport.minX, height: center.height),
            CGRect(x: center.maxX, y: center.minY, width: viewport.maxX - center.maxX, height: center.height),
            CGRect(x: center.minX, y: viewport.minY, width: center.width, height: center.minY - viewport.minY),
            CGRect(x: center.minX, y: center.maxY, width: center.width, height: viewport.maxY - center.maxY),
        ])
        context.stroke(center.insetBy(dx: 0.25, dy: 0.25), width: 0.5)
    }
}
