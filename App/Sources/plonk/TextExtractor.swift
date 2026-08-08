import AppKit
import Vision

// Reading the text off a capture, with Vision. Recognition is on-device and
// offline: no model is downloaded, nothing is uploaded, and the app's promise
// that only the update check dials out holds.
//
// PowerToys' Text Extractor hands the clipboard a string and stops there. The
// lines here also carry where each one sat, as a fraction of the image with
// the origin TOP-LEFT — the same space frames and annotations use — so a
// caller can point at what it read: draw a box round it, or work out which
// window a line belongs to.

enum TextExtractor {

    struct Line {
        let text: String
        /// Fraction of the image, origin top-left.
        let box: FracRect
        /// Vision's own 0...1 score for the reading it returned.
        let confidence: Double

        var asDict: [String: Any] {
            [
                "text": text,
                "box": ["x": box.x, "y": box.y, "w": box.w, "h": box.h],
                "confidence": Double(round(confidence * 100) / 100),
            ]
        }
    }

    enum Failure: LocalizedError {
        case notAnImage
        case unsupportedLanguage(String, supported: [String])
        case vision(String)

        var errorDescription: String? {
            switch self {
            case .notAnImage:
                return "the capture could not be read as an image"
            case .unsupportedLanguage(let tag, let supported):
                return "no recognition model for \"\(tag)\"; this Mac has \(supported.joined(separator: ", "))"
            case .vision(let message):
                return message
            }
        }
    }

    /// BCP-47 tags this Mac can recognize, e.g. "en-US", "uk-UA". Which are
    /// present depends on the macOS version, so it is asked rather than
    /// assumed, and the answer is what an unsupported request reports back.
    static let supportedLanguages: [String] = {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        return (try? request.supportedRecognitionLanguages()) ?? []
    }()

    /// Recognizes text off the main queue and calls back on it. Accurate
    /// recognition of a retina screen takes long enough to be felt, and route
    /// handlers run on the main queue.
    static func recognize(in image: NSImage, languages: [String] = [],
                          completion: @escaping (Result<[Line], Error>) -> Void) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(.failure(Failure.notAnImage))
            return
        }
        if let unsupported = languages.first(where: { !supportedLanguages.contains($0) }) {
            completion(.failure(Failure.unsupportedLanguage(unsupported, supported: supportedLanguages)))
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try read(cgImage, languages: languages) }
            DispatchQueue.main.async { completion(result) }
        }
    }

    private static func read(_ cgImage: CGImage, languages: [String]) throws -> [Line] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        if !languages.isEmpty { request.recognitionLanguages = languages }

        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        } catch {
            throw Failure.vision(error.localizedDescription)
        }
        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return Line(text: text,
                        box: topLeft(observation.boundingBox),
                        confidence: Double(candidate.confidence))
        }
    }

    /// Vision normalizes boxes with the origin at the BOTTOM-left; every
    /// fraction Plonk hands out has it at the top-left.
    static func topLeft(_ box: CGRect) -> FracRect {
        FracRect(clamp(box.minX), clamp(1 - box.maxY), clamp(box.width), clamp(box.height))
    }

    private static func clamp(_ value: CGFloat) -> Double {
        min(max(Double(value), 0), 1)
    }

    /// Reading order: top to bottom, then left to right within a row. Vision
    /// returns observations in its own order, which is close but not reliable
    /// enough to paste.
    ///
    /// Rows are grouped before anything is sorted inside them. Comparing "are
    /// these two within a band of each other" directly is not a consistent
    /// ordering — a column of slightly ragged lines can chain A≈B, B≈C but
    /// A≉C — and sorting on it scrambles exactly the text it is meant to
    /// straighten out.
    static func joined(_ lines: [Line]) -> String {
        let band = 0.01
        var rows: [[Line]] = []
        var anchor = -Double.infinity
        for line in lines.sorted(by: { $0.box.y < $1.box.y }) {
            if line.box.y - anchor > band {
                rows.append([])
                anchor = line.box.y
            }
            rows[rows.count - 1].append(line)
        }
        return rows
            .flatMap { $0.sorted { $0.box.x < $1.box.x } }
            .map(\.text)
            .joined(separator: "\n")
    }
}
