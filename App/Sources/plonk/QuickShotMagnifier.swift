import AppKit

final class QuickShotMagnifier: NSView {
    private static let contentWidth: CGFloat = 120
    private static let borderWidth: CGFloat = 2
    private static let size: CGSize = {
        let side = contentWidth + 2 * borderWidth
        return CGSize(width: side, height: side)
    }()
    private static let centerMark = CGRect(x: size.width / 2 - 2, y: size.height / 2 - 2, width: 4, height: 4)
    private static let badgeBorder: CGFloat = 2
    private static let badgeHeight: CGFloat = 14
    private static let badgeTextInset = badgeBorder + 6
    private static let hexStyle: [NSAttributedString.Key: Any] = [
        .font: NSFont(name: "Inter-Regular", size: 10) ?? NSFont.systemFont(ofSize: 10),
        .foregroundColor: NSColor.white,
    ]

    private let sampler: ShotPixelSampler
    private var pixel: CGPoint?
    private var pointerInPixel = CGPoint.zero
    private var sampledHex: String?
    private var colorLabel: (text: NSAttributedString, size: CGSize)?
    private var neighborhood: ShotPixelSampler.Neighborhood?
    private var zoom: ShotMagnifierZoom = .standard
    private var drawingOffset = CGPoint.zero
    var hex: String? { isHidden ? nil : sampledHex }
    var showsHex = true {
        didSet { if oldValue != showsHex { needsDisplay = true } }
    }

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
        guard let position = sampler.position(at: point, in: area) else { return hide() }
        let nextPixel = CGPoint(x: floor(position.x), y: floor(position.y))
        let offsetInPixel = CGPoint(x: position.x - nextPixel.x, y: position.y - nextPixel.y)
        if pointerInPixel != offsetInPixel {
            pointerInPixel = offsetInPixel
            needsDisplay = true
        }
        if pixel != nextPixel {
            sampledHex = sampler.hex(at: nextPixel)
            colorLabel = sampledHex.map { hex in
                let digits = hex.dropFirst()
                let grouped = "#\(digits.prefix(2)) \(digits.dropFirst(2).prefix(2)) \(digits.suffix(2))"
                let label = NSAttributedString(string: grouped, attributes: Self.hexStyle)
                return (label, label.size())
            }
        }
        if pixel != nextPixel || self.zoom != zoom {
            pixel = nextPixel
            showNeighborhood(around: nextPixel, zoom: zoom)
        }

        var details = Self.centerMark
        if showsHex, let colorLabel {
            details = details.union(Self.badgeFrame(textWidth: colorLabel.size.width))
        }
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
        guard let context = NSGraphicsContext.current?.cgContext, let neighborhood else { return }
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

        guard showsHex, let colorLabel else { return }
        let labelSize = colorLabel.size
        let badgeBorder = Self.badgeBorder
        let badge = Self.badgeFrame(textWidth: labelSize.width).offsetBy(dx: drawingOffset.x, dy: drawingOffset.y)
        context.setFillColor(CGColor(srgbRed: 34 / 255, green: 34 / 255, blue: 34 / 255, alpha: 1))
        context.fill(badge)
        context.stroke(badge.insetBy(dx: badgeBorder / 2, dy: badgeBorder / 2), width: badgeBorder)
        colorLabel.text.draw(at: CGPoint(x: badge.minX + Self.badgeTextInset, y: badge.midY - labelSize.height / 2))
    }

    private static func badgeFrame(textWidth: CGFloat) -> CGRect {
        let width = ceil(textWidth) + 2 * badgeTextInset
        let inset = borderWidth / 2
        return CGRect(x: size.width - inset - width, y: size.height - inset - badgeHeight,
                      width: width, height: badgeHeight)
    }

    private func drawPixels(_ neighborhood: ShotPixelSampler.Neighborhood, in viewport: CGRect, context: CGContext) {
        let cell = viewport.width / CGFloat(zoom.pixelsPerRow)
        let radius = CGFloat(zoom.cells / 2)
        let image = neighborhood.image
        let patch = CGRect(x: viewport.midX - (radius + pointerInPixel.x - neighborhood.offset.x) * cell,
                           y: viewport.midY - (radius + pointerInPixel.y - neighborhood.offset.y) * cell,
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
        let center = Self.centerMark.offsetBy(dx: drawingOffset.x, dy: drawingOffset.y)
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
