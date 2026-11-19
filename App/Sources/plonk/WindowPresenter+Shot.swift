import AppKit

extension WindowPresenter {
    func showShotEditor(image: NSImage, history: AnnotationHistory = AnnotationHistory()) {
        shotEditor?.close()
        let window = ShotEditorWindow(image: image, history: history, accent: model.config.appearance.accent,
                                      folder: shotFolder) { [weak self] copied, path in
            self?.shotEditor?.close()
            self?.onShotFinished?(copied, path)
        }
        window.delegate = self
        window.center()
        shotEditor = window
        bringForward(window)
        window.makeFirstResponder(window.editor.canvas)
    }
}
