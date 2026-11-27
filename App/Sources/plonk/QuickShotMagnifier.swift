import AppKit

final class QuickShotMagnifier: NSView {
    private final class CopyHint: NSTextField {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    private static let size = CGSize(width: 128, height: 128)
    private static let hexStyle: [NSAttributedString.Key: Any] = [
        .font: NSFont(name: "Inter-Regular", size: 10) ?? NSFont.systemFont(ofSize: 10),
        .foregroundColor: NSColor.white,
    ]

    private let sampler: ShotPixelSampler
    private let copyHint = CopyHint(labelWithString: String(localized: .shotCopyColorHint))
    private var pixel: CGPoint?
    private var sampledHex: String?
    private var colorLabel: NSAttributedString?
    private var neighborhood: ShotPixelSampler.Neighborhood?
    private var zoom: ShotMagnifierZoom = .standard
    var hex: String? { isHidden ? nil : sampledHex }

    init(image: CGImage) {
        sampler = ShotPixelSampler(image: image)
        super.init(frame: CGRect(origin: .zero, size: Self.size))
        copyHint.font = .systemFont(ofSize: 11)
        copyHint.textColor = .white
        copyHint.alignment = .center
        copyHint.wantsLayer = true
        copyHint.layer?.cornerRadius = 4
        copyHint.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.82).cgColor
        hide()
    }

    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func install(in canvas: NSView, safeArea: CGRect) {
        let hintSize = copyHint.intrinsicContentSize
        copyHint.frame = CGRect(x: safeArea.minX + 5, y: safeArea.maxY - hintSize.height - 5,
                                width: hintSize.width + 12, height: hintSize.height)
        canvas.addSubview(copyHint)
        canvas.addSubview(self)
    }

    func hide() {
        isHidden = true
        copyHint.isHidden = true
    }

    func update(at point: CGPoint, in area: CGRect, avoiding selection: CGRect?,
                zoom: ShotMagnifierZoom, showsCopyHint: Bool) {
        guard let nextPixel = sampler.pixel(at: point, in: area) else { return hide() }
        if pixel != nextPixel {
            guard let hex = sampler.hex(at: nextPixel) else { return hide() }
            sampledHex = hex
            let digits = hex.dropFirst()
            let grouped = "#\(digits.prefix(2)) \(digits.dropFirst(2).prefix(2)) \(digits.suffix(2))"
            colorLabel = NSAttributedString(string: grouped, attributes: Self.hexStyle)
        }
        if pixel != nextPixel || self.zoom != zoom {
            pixel = nextPixel
            showNeighborhood(around: nextPixel, zoom: zoom)
        }

        let placement = QuickShotLayout.magnifier(size: Self.size, near: point, area: area, avoiding: selection)
        setFrameOrigin(placement.origin)
        isHidden = false
        copyHint.isHidden = !showsCopyHint
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
        let viewport = bounds.insetBy(dx: 1, dy: 1)
        drawPixels(neighborhood, in: viewport, context: context)

        let blue = QuickShotBackdrop.accent
        context.setStrokeColor(blue.cgColor)
        context.stroke(bounds.insetBy(dx: 0.5, dy: 0.5), width: 1)
        drawCrosshair(in: viewport, color: blue, context: context)

        let badge = CGRect(x: bounds.minX, y: bounds.maxY - 14, width: 50, height: 14)
        context.setFillColor(CGColor(srgbRed: 34 / 255, green: 34 / 255, blue: 34 / 255, alpha: 1))
        context.fill(badge)
        context.stroke(badge.insetBy(dx: 0.5, dy: 0.5), width: 1)
        let labelSize = colorLabel.size()
        colorLabel.draw(at: CGPoint(x: badge.midX - labelSize.width / 2, y: badge.midY - labelSize.height / 2))
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
        let center = CGRect(x: viewport.midX - 2, y: viewport.midY - 2, width: 4, height: 4)
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
