import AppKit

extension ScreenshotManager {
    static func openInPreview(_ image: NSImage, completion: @escaping (Bool) -> Void) {
        let workspace = NSWorkspace.shared
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("plonk-preview-\(UUID().uuidString).png")
        guard let preview = workspace.urlForApplication(withBundleIdentifier: "com.apple.Preview"),
              save(image, to: .path(url.path)) != nil else {
            completion(false)
            return
        }
        workspace.open([url], withApplicationAt: preview, configuration: .init()) { _, error in
            DispatchQueue.main.async { completion(error == nil) }
            // Launch completion can precede Preview reading the document.
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + (error == nil ? 1800 : 0)) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
