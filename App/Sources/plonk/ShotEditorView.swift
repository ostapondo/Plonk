import AppKit
import SwiftUI

final class ShotEditorView: NSView {
    let canvas: ShotEditorCanvas
    private let defaultFolder: () -> String
    private let onFinish: (Bool, String?) -> Void
    private let accent: NSColor
    private lazy var tools = ShotMarkupTools(canvas: canvas, kinds: Annotation.Kind.allCases,
                                            includeSelection: false, accent: accent)
    private let status = NSTextField(labelWithString: "")
    private var colors: [NSButton] = []

    init(image: NSImage, history: AnnotationHistory, accent: NSColor, defaultFolder: @escaping () -> String,
         onFinish: @escaping (Bool, String?) -> Void) {
        canvas = ShotEditorCanvas(image: image, history: history)
        self.defaultFolder = defaultFolder
        self.onFinish = onFinish
        self.accent = accent
        super.init(frame: .zero)
        let stack = NSStackView(views: [toolbar(), separator(), canvas, separator(), footer()])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            canvas.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
        ])
    }

    required init?(coder: NSCoder) { nil }

    private func toolbar() -> NSStackView {
        let palette = NSStackView()
        palette.spacing = 3
        for (index, color) in Annotation.palette.enumerated() {
            let button = NSButton()
            QuickShotControls.configure(button, symbol: "circle.fill", title: .shotEditorColor(index + 1),
                                        target: self, action: #selector(selectColor))
            button.contentTintColor = NSColor(color)
            button.tag = index
            button.wantsLayer = true
            button.layer?.cornerRadius = 6
            colors.append(button)
            palette.addArrangedSubview(button)
        }
        refreshPalette()
        let thickness = NSSlider(value: 4, minValue: 1, maxValue: 16, target: self, action: #selector(setWidth))
        thickness.setAccessibilityLabel(String(localized: .shotEditorWidth))
        thickness.toolTip = String(localized: .shotEditorWidth)
        thickness.widthAnchor.constraint(equalToConstant: 90).isActive = true
        let stack = NSStackView(views: [tools.stack, palette, thickness, NSView()])
        stack.alignment = .centerY
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 9, left: 12, bottom: 9, right: 12)
        return stack
    }

    private func separator() -> NSBox {
        let line = NSBox()
        line.boxType = .separator
        return line
    }

    private func footer() -> NSStackView {
        status.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        status.textColor = .secondaryLabelColor
        let saveAs = NSButton(title: String(localized: .shotEditorSaveAs), target: self, action: #selector(chooseSavePath))
        let save = NSButton(title: String(localized: .shotEditorSaveToFolder), target: self, action: #selector(saveClicked))
        let copy = NSButton(title: String(localized: .shotEditorCopy), target: self, action: #selector(copyImage))
        let stack = NSStackView(views: [status, NSView(), saveAs, save, copy])
        stack.alignment = .centerY
        stack.edgeInsets = NSEdgeInsets(top: 9, left: 12, bottom: 9, right: 12)
        return stack
    }

    private func refreshPalette() {
        for button in colors {
            button.layer?.backgroundColor = button.tag == canvas.colorIndex
                ? accent.withAlphaComponent(0.18).cgColor : nil
        }
    }

    @objc private func selectColor(_ button: NSButton) {
        guard canvas.commitText() else { return }
        canvas.colorIndex = button.tag
        refreshPalette()
    }

    @objc private func setWidth(_ slider: NSSlider) {
        canvas.strokePoints = slider.doubleValue
    }

    private func render() -> NSImage? {
        guard canvas.commitText() else { return nil }
        let annotations = canvas.history.annotations
        guard !annotations.isEmpty else { return canvas.image }
        guard let image = canvas.image.annotated(with: annotations) else {
            status.stringValue = String(localized: .shotEditorRenderFailed)
            return nil
        }
        return image
    }

    @objc func copyImage() {
        guard let image = render() else { return }
        guard ScreenshotManager.copyToClipboard(image) else {
            status.stringValue = String(localized: .shotCopyFailed)
            return
        }
        onFinish(true, nil)
    }

    func save(to destination: ScreenshotManager.Destination, forceCopy: Bool = false) {
        guard let image = render() else { return }
        guard let path = ScreenshotManager.save(image, to: destination) else {
            status.stringValue = String(localized: .shotEditorWriteFailed)
            return
        }
        let copied = forceCopy && ScreenshotManager.copyToClipboard(image)
        if forceCopy && !copied { HUD.shared.show(.shotCopyFailed) }
        onFinish(copied, path)
    }

    @objc private func saveClicked() { saveToFolder(forceCopy: false) }

    func saveToFolder(forceCopy: Bool) {
        save(to: .folder(defaultFolder()), forceCopy: forceCopy)
    }

    @objc private func chooseSavePath() {
        guard canvas.commitText(), let window else { return }
        window.beginShotSavePanel(in: defaultFolder()) { [weak self] url in
            if let url { self?.save(to: .path(url.path)) }
        }
    }
}
