import AppKit

// Capture goes through /usr/sbin/screencapture: it gives the native crosshair
// and window picker for free, and handles the Screen Recording permission the
// same way the system shortcuts do.

enum CaptureMode: String {
    case region
    case window
    case screen

    var arguments: [String] {
        switch self {
        case .region: return ["-i", "-o"]
        case .window: return ["-i", "-w", "-o"]
        case .screen: return []
        }
    }
}

enum ScreenshotManager {

    enum Destination {
        case folder(String)
        case path(String)

        var url: URL {
            switch self {
            case .folder(let folder):
                let dir = URL(fileURLWithPath: (folder as NSString).expandingTildeInPath, isDirectory: true)
                return dir.appendingPathComponent(fileName(for: Date()))
            case .path(let path):
                var expanded = (path as NSString).expandingTildeInPath
                if !expanded.lowercased().hasSuffix(".png") { expanded += ".png" }
                return URL(fileURLWithPath: expanded)
            }
        }
    }

    /// The interactive modes wait for the user, so this never blocks the caller.
    /// `completion` runs on the main queue with nil when the user cancels.
    static func capture(_ mode: CaptureMode, completion: @escaping (NSImage?) -> Void) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("plonk-capture-\(UUID().uuidString).png")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-x"] + mode.arguments + [url.path]
        task.terminationHandler = { finished in
            var image: NSImage?
            if finished.terminationStatus == 0 {
                image = NSImage(contentsOf: url)
            }
            try? FileManager.default.removeItem(at: url)
            DispatchQueue.main.async { completion(image) }
        }
        do {
            try task.run()
        } catch {
            NSLog("Plonk: screencapture failed to launch: \(error)")
            DispatchQueue.main.async { completion(nil) }
        }
    }

    /// Timestamped file name, e.g. "Plonk 2026-08-07 at 14.05.12.png".
    static func fileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "Plonk \(formatter.string(from: date)).png"
    }

    static func pngData(from image: NSImage) -> Data? {
        if let rep = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first,
           let data = rep.representation(using: .png, properties: [:]) {
            return data
        }
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    @discardableResult
    static func copyToClipboard(_ image: NSImage) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let data = pngData(from: image) {
            pasteboard.setData(data, forType: .png)
            return true
        }
        return pasteboard.writeObjects([image])
    }

    /// Writes the image, creating missing directories. Returns the path.
    static func save(_ image: NSImage, to destination: Destination) -> String? {
        let url = destination.url
        guard let data = pngData(from: image) else { return nil }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        do {
            try data.write(to: url, options: .atomic)
            return url.path
        } catch {
            NSLog("Plonk: failed to write screenshot: \(error)")
            return nil
        }
    }

    /// Pixels per point, so exports keep the capture's native resolution.
    static func nativeScale(of image: NSImage) -> CGFloat {
        let widest = image.representations.map(\.pixelsWide).max() ?? 0
        guard widest > 0, image.size.width > 0 else { return 1 }
        return CGFloat(widest) / image.size.width
    }

    /// A copy no larger than `maxDimension` on its longest side, or nil when
    /// the image already fits. Used to keep agent payloads small.
    static func downscaled(_ image: NSImage, maxDimension: CGFloat) -> NSImage? {
        let scale = nativeScale(of: image)
        let pixelWidth = image.size.width * scale
        let pixelHeight = image.size.height * scale
        let longest = max(pixelWidth, pixelHeight)
        guard longest > maxDimension, longest > 0 else { return nil }

        let ratio = maxDimension / longest
        let size = NSSize(width: max((pixelWidth * ratio).rounded(), 1),
                          height: max((pixelHeight * ratio).rounded(), 1))
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        rep.size = size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()

        let result = NSImage(size: size)
        result.addRepresentation(rep)
        return result
    }

    /// The previous preview, dropped when the next one is written. Only the
    /// agent reads these, and it has moved on by then.
    private static var lastPreview: URL?

    /// Writes a copy sized for an agent to look at, into the temporary
    /// directory. Returns nil when the original is already small enough.
    static func writePreview(_ image: NSImage, maxDimension: CGFloat) -> String? {
        guard let small = downscaled(image, maxDimension: maxDimension) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("plonk-preview-\(UUID().uuidString).png")
        guard let path = save(small, to: .path(url.path)) else { return nil }
        if let previous = lastPreview { try? FileManager.default.removeItem(at: previous) }
        lastPreview = URL(fileURLWithPath: path)
        return path
    }
}
