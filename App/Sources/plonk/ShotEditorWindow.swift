import AppKit

final class ShotEditorWindow: NSWindow {
    let editor: ShotEditorView

    init(image: NSImage, history: AnnotationHistory, accent: NSColor, folder: @escaping () -> String,
         onFinish: @escaping (Bool, String?) -> Void) {
        editor = ShotEditorView(image: image, history: history, accent: accent, defaultFolder: folder, onFinish: onFinish)
        super.init(contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable, .resizable],
                   backing: .buffered, defer: false)
        title = String(localized: .windowScreenshot)
        isReleasedWhenClosed = false
        contentView = editor
        contentMinSize = CGSize(width: 640, height: 400)
        setContentSize(NSSize(width: image.size.width.clamped(to: 700...1400),
                              height: (image.size.height + 110).clamped(to: 520...900)))
        initialFirstResponder = editor.canvas
        autorecalculatesKeyViewLoop = true
    }

    func handleShortcut(_ event: NSEvent) -> Bool {
        guard let command = ShotKeyCommand(event: event, window: self, canvas: editor.canvas) else { return false }
        switch command {
        case .action(.copy): editor.copyImage()
        case .action(.save(let forceCopy)): editor.saveToFolder(forceCopy: forceCopy)
        case .action: return false
        case .cancel:
            if !editor.canvas.cancelText() { close() }
        case .select(let kind): editor.selectTool(kind)
        case .undo: editor.canvas.undoMark()
        case .redo: editor.canvas.redoMark()
        case .tab(let backward):
            if backward { selectPreviousKeyView(editor.canvas) } else { selectNextKeyView(editor.canvas) }
        }
        return true
    }
}
