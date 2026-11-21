import AppKit
import UniformTypeIdentifiers

enum ShotSavePanel {
    static func make(in folder: String) -> NSSavePanel {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = ScreenshotManager.fileName(for: Date())
        panel.directoryURL = URL(fileURLWithPath: (folder as NSString).expandingTildeInPath, isDirectory: true)
        return panel
    }
}
