import AppKit

final class ShotMarkupTools: NSObject {
    let stack = NSStackView()
    private let accent: NSColor
    private let kinds: [Annotation.Kind]
    private let includeSelection: Bool
    private var choiceButtons: [NSButton] = []
    private let undoButton = NSButton()
    private let redoButton = NSButton()
    private weak var canvas: ShotMarkupCanvas?

    init(canvas: ShotMarkupCanvas, kinds: [Annotation.Kind], includeSelection: Bool, accent: NSColor) {
        self.accent = accent
        self.kinds = kinds
        self.includeSelection = includeSelection
        self.canvas = canvas
        super.init()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 3
        if includeSelection { addTool(symbol: "cursorarrow", title: .shotSelectionMove, index: -1) }
        for (index, kind) in kinds.enumerated() {
            addTool(symbol: kind.symbol, title: kind.title, index: index)
        }
        if let last = choiceButtons.last { stack.setCustomSpacing(10, after: last) }
        QuickShotControls.configure(undoButton, symbol: "arrow.uturn.backward",
                                    title: .shotEditorUndo, target: self, action: #selector(undo))
        QuickShotControls.configure(redoButton, symbol: "arrow.uturn.forward",
                                    title: .shotEditorRedo, target: self, action: #selector(redo))
        stack.addArrangedSubview(undoButton)
        stack.addArrangedSubview(redoButton)
        canvas.onHistoryChanged = { [weak self] in self?.refreshHistory($0) }
        refreshHistory(canvas.history)
        refreshChoice()
    }

    func select(_ kind: Annotation.Kind?) {
        guard let canvas, canvas.commitText() else { return }
        canvas.tool = kind
        canvas.window?.makeFirstResponder(canvas)
        canvas.window?.invalidateCursorRects(for: canvas)
        refreshChoice()
    }

    private func addTool(symbol: String, title: LocalizedStringResource, index: Int) {
        let button = NSButton()
        QuickShotControls.configure(button, symbol: symbol, title: title, target: self, action: #selector(choose))
        button.setButtonType(.toggle)
        button.tag = index
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        choiceButtons.append(button)
        stack.addArrangedSubview(button)
    }

    private func refreshChoice() {
        for button in choiceButtons {
            let kind = button.tag == -1 ? nil : kinds[button.tag]
            let active = canvas?.tool == kind
            button.state = active ? .on : .off
            button.layer?.backgroundColor = active ? accent.withAlphaComponent(0.18).cgColor : nil
        }
    }

    private func refreshHistory(_ history: AnnotationHistory) {
        undoButton.isEnabled = !history.annotations.isEmpty
        redoButton.isEnabled = !history.redoStack.isEmpty
    }

    @objc private func choose(_ button: NSButton) {
        let kind = button.tag == -1 ? nil : kinds[button.tag]
        select(includeSelection && kind == canvas?.tool ? nil : kind)
    }
    @objc private func undo() {
        guard let canvas, canvas.commitText() else { return }
        canvas.undoMark()
    }
    @objc private func redo() {
        guard let canvas, canvas.commitText() else { return }
        canvas.redoMark()
    }
}
