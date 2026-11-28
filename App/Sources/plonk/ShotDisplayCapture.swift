import AppKit
import ScreenCaptureKit

enum ShotDisplayCapture {
    private enum Failure: Error {
        case displayUnavailable
    }

    @MainActor
    static func capture(_ screens: [NSScreen]) async throws -> [ShotBitmap] {
        let requests = try screens.map { screen in
            guard let id = ScreenIdentity.displayID(for: screen) else { throw Failure.displayUnavailable }
            return (id: id, size: screen.frame.size, scale: screen.backingScaleFactor)
        }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        try Task.checkCancellation()

        return try await withThrowingTaskGroup(of: (Int, ShotBitmap).self) { group in
            for (index, request) in requests.enumerated() {
                guard let display = content.displays.first(where: { $0.displayID == request.id }) else {
                    throw Failure.displayUnavailable
                }
                let filter = content.filterExcludingPlonk(on: display)
                let configuration = configuration(displaySize: request.size, scale: request.scale)
                group.addTask {
                    try Task.checkCancellation()
                    let image: CGImage
                    if #available(macOS 14, *) {
                        image = try await SCScreenshotManager.captureImage(contentFilter: filter,
                                                                           configuration: configuration)
                    } else {
                        image = try await FirstScreenFrame.capture(filter: filter, configuration: configuration)
                    }
                    return (index, ShotBitmap(image: image, displaySize: request.size))
                }
            }
            var bitmaps: [(Int, ShotBitmap)] = []
            for try await capture in group {
                bitmaps.append(capture)
            }
            return bitmaps.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    static func configuration(displaySize: CGSize, scale: CGFloat) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        configuration.width = Int((displaySize.width * scale).rounded())
        configuration.height = Int((displaySize.height * scale).rounded())
        configuration.showsCursor = false
        return configuration
    }
}
