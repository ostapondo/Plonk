import AppKit
import ScreenCaptureKit

// A live thumbnail of part of another window, floating above everything.
//
// Keep the build log, the chart or the call visible in a corner while you work
// on top of it. PowerToys calls this Crop And Lock and offers three modes; only
// two of them can exist on macOS. Reparenting — putting another app's window
// inside yours — has no public equivalent and no private one worth having, so
// what is here is the thumbnail (live, mirrors the original) and the still
// (frozen at the moment it was taken).
//
// The live mode streams the source window through ScreenCaptureKit, which is
// the same Screen Recording permission a screenshot already needs. Nothing is
// written to disk and nothing is recorded; frames go straight to a layer.

@available(macOS 13.0, *)
final class CropAndLock: NSObject {
    /// Panels are kept here so they outlive the call that made them and can be
    /// closed together when the app quits.
    private var panels: [CroppedPanel] = []

    /// Picks a region interactively, then floats a live thumbnail of it.
    /// `completion` reports what happened, for the HUD and the API.
    func createLive(completion: @escaping (Result<String, Error>) -> Void) {
        RegionPicker.pick { [weak self] region in
            guard let self else { return }
            guard let region else {
                completion(.failure(CropError.cancelled))
                return
            }
            Task { @MainActor in
                do {
                    let panel = try await CroppedPanel.live(region: region) { [weak self] panel in
                        self?.panels.removeAll { $0 === panel }
                    }
                    self.panels.append(panel)
                    completion(.success("live"))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    /// The same thing, frozen: a still of the region that stays on top. Cheap,
    /// and works on windows a stream will not follow.
    func createStill(completion: @escaping (Result<String, Error>) -> Void) {
        RegionPicker.pick { [weak self] region in
            guard let self, let region else {
                completion(.failure(CropError.cancelled))
                return
            }
            ScreenshotManager.captureRegion(region) { image in
                guard let image else {
                    completion(.failure(CropError.captureFailed))
                    return
                }
                let panel = CroppedPanel.still(image: image, region: region) { [weak self] panel in
                    self?.panels.removeAll { $0 === panel }
                }
                self.panels.append(panel)
                completion(.success("still"))
            }
        }
    }

    var count: Int { panels.count }

    /// Pinned crops float over the desk, so a capture has to hide them or it
    /// photographs its own output.
    var visibleWindows: [NSWindow] { panels }

    func closeAll() {
        panels.forEach { $0.close() }
        panels.removeAll()
    }

    enum CropError: LocalizedError {
        case cancelled
        case captureFailed
        case noDisplay

        var errorDescription: String? {
            switch self {
            case .cancelled: return "no region was chosen"
            case .captureFailed: return "the region could not be captured; Screen Recording may not be granted"
            case .noDisplay: return "the region is not on any display"
            }
        }
    }
}

// MARK: - The floating panel

@available(macOS 13.0, *)
final class CroppedPanel: NSPanel {
    private var stream: SCStream?
    private let output = StreamOutput()
    private var onClose: ((CroppedPanel) -> Void)?

    /// A live mirror of a screen region. Streaming a rect rather than a window
    /// is deliberate: the region may straddle two windows, and what the user
    /// drew a box round is what they meant.
    @MainActor
    static func live(region: CGRect, onClose: @escaping (CroppedPanel) -> Void) async throws -> CroppedPanel {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: {
            CGRect(x: 0, y: 0, width: $0.width, height: $0.height)
                .offsetBy(dx: $0.frame.minX, dy: $0.frame.minY).intersects(region)
        }) ?? content.displays.first else {
            throw CropAndLock.CropError.noDisplay
        }

        let panel = CroppedPanel(region: region, title: "Live")
        panel.onClose = onClose

        let configuration = SCStreamConfiguration()
        configuration.sourceRect = CGRect(x: region.minX - display.frame.minX,
                                          y: region.minY - display.frame.minY,
                                          width: region.width, height: region.height)
        configuration.width = Int(region.width * 2)
        configuration.height = Int(region.height * 2)
        configuration.showsCursor = false
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        // Plonk's own windows are excluded, or the thumbnail films itself.
        let filter = SCContentFilter(display: display,
                                     excludingApplications: content.applications.filter {
                                         $0.processID == ProcessInfo.processInfo.processIdentifier
                                     },
                                     exceptingWindows: [])

        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try stream.addStreamOutput(panel.output, type: .screen,
                                   sampleHandlerQueue: DispatchQueue(label: "dev.plonk.crop"))
        panel.output.onFrame = { [weak panel] image in
            panel?.imageLayer.contents = image
        }
        try await stream.startCapture()
        panel.stream = stream
        panel.orderFrontRegardless()
        return panel
    }

    static func still(image: NSImage, region: CGRect, onClose: @escaping (CroppedPanel) -> Void) -> CroppedPanel {
        let panel = CroppedPanel(region: region, title: "Still")
        panel.onClose = onClose
        panel.imageLayer.contents = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        panel.orderFrontRegardless()
        return panel
    }

    private let imageLayer = CALayer()

    private init(region: CGRect, title: String) {
        // Half size, so a thumbnail of a big region is still a thumbnail.
        let size = NSSize(width: max(region.width / 2, 160), height: max(region.height / 2, 100))
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        self.title = "Plonk — \(title)"
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let host = NSView(frame: NSRect(origin: .zero, size: size))
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.black.cgColor
        imageLayer.frame = host.bounds
        imageLayer.contentsGravity = .resizeAspect
        imageLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        host.layer?.addSublayer(imageLayer)
        contentView = host
        center()
        delegate = self
    }

    override func close() {
        if let stream {
            Task { try? await stream.stopCapture() }
            self.stream = nil
        }
        onClose?(self)
        onClose = nil
        super.close()
    }
}

@available(macOS 13.0, *)
extension CroppedPanel: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let stream {
            Task { try? await stream.stopCapture() }
            self.stream = nil
        }
        onClose?(self)
        onClose = nil
    }
}

/// Turns stream buffers into images on whatever queue the stream uses, and
/// hands them to the layer on the main one.
@available(macOS 13.0, *)
private final class StreamOutput: NSObject, SCStreamOutput {
    var onFrame: ((CGImage) -> Void)?
    /// Built once. A CIContext carries GPU state and is meant to be reused;
    /// making one per frame is thirty allocations a second for nothing.
    private let context = CIContext()

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvImageBuffer: pixels)
        guard let image = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        DispatchQueue.main.async { [weak self] in self?.onFrame?(image) }
    }
}
