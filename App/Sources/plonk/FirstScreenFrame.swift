import CoreImage
import ScreenCaptureKit

final class FirstScreenFrame: NSObject, SCStreamOutput, SCStreamDelegate {
    private enum Failure: Error {
        case timedOut
    }

    private let frames: AsyncThrowingStream<CGImage, Error>
    private let continuation: AsyncThrowingStream<CGImage, Error>.Continuation
    private let context = CIContext()
    private var delivered = false

    override init() {
        (frames, continuation) = AsyncThrowingStream.makeStream(bufferingPolicy: .bufferingOldest(1))
        super.init()
    }

    static func capture(filter: SCContentFilter, configuration: SCStreamConfiguration) async throws -> CGImage {
        let output = FirstScreenFrame()
        let stream = SCStream(filter: filter, configuration: configuration, delegate: output)
        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: DispatchQueue(label: "dev.plonk.shot"))
        try Task.checkCancellation()
        try await stream.startCapture()

        let timeout = Task {
            try await Task.sleep(for: .seconds(3))
            output.continuation.finish(throwing: Failure.timedOut)
        }
        defer { timeout.cancel() }
        var iterator = output.frames.makeAsyncIterator()
        let image: CGImage?
        do {
            image = try await iterator.next()
        } catch {
            try? await stream.stopCapture()
            throw error
        }
        try? await stream.stopCapture()
        guard let image else { throw CancellationError() }
        return image
    }

    static func hasImage(_ status: SCFrameStatus?) -> Bool {
        status == .started || status == .complete
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard !delivered, type == .screen, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
                  as? [[SCStreamFrameInfo: Any]],
              let status = attachments.first?[.status] as? Int,
              Self.hasImage(SCFrameStatus(rawValue: status)),
              let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let frame = CIImage(cvImageBuffer: pixels)
        guard let image = context.createCGImage(frame, from: frame.extent) else { return }
        delivered = true
        continuation.yield(image)
        continuation.finish()
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        continuation.finish(throwing: error)
    }
}
