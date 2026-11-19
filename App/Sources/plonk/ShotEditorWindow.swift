import AppKit
import Carbon.HIToolbox

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

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, firstResponder === editor.canvas {
            switch Int(event.keyCode) {
            case kVK_Return, kVK_ANSI_KeypadEnter, kVK_Space:
                editor.copyImage()
                return
            case kVK_Escape:
                if !editor.canvas.cancelText() { close() }
                return
            default: break
            }
        }
        super.sendEvent(event)
    }
}
