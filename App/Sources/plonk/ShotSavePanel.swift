import AppKit
import UniformTypeIdentifiers

extension NSWindow {
    func beginShotSavePanel(in folder: String, completion: @escaping (URL?) -> Void) {
        guard attachedSheet == nil else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = ScreenshotManager.fileName(for: Date())
        panel.directoryURL = URL(fileURLWithPath: (folder as NSString).expandingTildeInPath, isDirectory: true)
        panel.beginSheetModal(for: self) { result in
            completion(result == .OK ? panel.url : nil)
        }
    }
}
