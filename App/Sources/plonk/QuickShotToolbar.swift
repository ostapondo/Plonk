import AppKit

final class QuickShotToolbar: NSView {
    enum Action {
        case tool(Annotation.Kind?)
        case undo
        case redo
        case cancel
        case output(QuickShotOutput)
    }

    private var tools: [(QuickShotButton, Annotation.Kind?)] = []
    private let undo: QuickShotButton
    private let redo: QuickShotButton

    init(perform: @escaping (Action) -> Void) {
        undo = QuickShotButton(symbol: "arrow.uturn.backward", title: .shotEditorUndo) { perform(.undo) }
        redo = QuickShotButton(symbol: "arrow.uturn.forward", title: .shotEditorRedo) { perform(.redo) }
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(srgbRed: 41 / 255, green: 45 / 255, blue: 52 / 255, alpha: 1).cgColor
        layer?.cornerRadius = 21
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.13).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.4
        layer?.shadowRadius = 8
        layer?.shadowOffset = CGSize(width: 0, height: -5)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(String(localized: .shotAfterQuickActions))

        let choices: [(Annotation.Kind, String)] = [
            (.rectangle, "rectangle"), (.ellipse, "circle"), (.arrow, "arrow.up.right"),
            (.pen, "pencil.tip"), (.highlight, "highlighter"),
        ]
        let move = QuickShotButton(symbol: "arrow.up.and.down.and.arrow.left.and.right", title: .shotSelectionMove) {
            perform(.tool(nil))
        }
        tools = [(move, nil)] + choices.map { kind, symbol in
            (QuickShotButton(symbol: symbol, title: kind.title) { perform(.tool(kind)) }, kind)
        }
        tools.forEach { addSubview($0.0) }
        addDivider()
        addSubview(undo)
        addSubview(redo)
        addDivider()
        addSubview(QuickShotButton(symbol: "xmark", title: .commonCancel, cancel: true) { perform(.cancel) })
        let actions: [(String, LocalizedStringResource, QuickShotOutput)] = [
            ("macwindow", .shotAfterEditor, .editor),
            ("folder", .shotEditorSaveToFolder, .save),
            ("square.and.arrow.down", .shotEditorSaveAs, .saveAs),
            ("doc.on.doc", .shotEditorCopy, .copy),
        ]
        for (symbol, title, output) in actions {
            addSubview(QuickShotButton(symbol: symbol, title: title) { perform(.output(output)) })
        }
    }

    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }

    override func mouseDown(with event: NSEvent) {}

    private func addDivider() {
        let divider = NSView()
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.2).cgColor
        addSubview(divider)
    }

    func update(tool: Annotation.Kind?, history: AnnotationHistory) {
        for (button, kind) in tools { button.isSelectedTool = kind == tool }
        undo.isEnabled = history.canUndo
        redo.isEnabled = history.canRedo
    }

    func fittedSize(availableWidth: CGFloat) -> CGSize {
        let layout = QuickShotLayout.toolbar(dividers: subviews.map { !($0 is QuickShotButton) },
                                             availableWidth: availableWidth)
        for (view, slot) in zip(subviews, layout.frames) {
            view.frame = view is QuickShotButton ? slot
                : CGRect(x: slot.midX, y: slot.midY - 7.5, width: 1, height: 15)
        }
        return layout.size
    }
}
