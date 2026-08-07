import AVFoundation
import Speech

// Push-to-talk: hold the key, speak, let go. Recognition runs on this Mac
// (requiresOnDeviceRecognition) — audio never leaves it; only the finished
// transcript goes to the active agent, over the local loopback API.

final class VoiceManager {
    /// Partial transcript while the key is held, for the HUD.
    var onPartial: ((String) -> Void)?
    /// The finished transcript, after the key is released. Fires once.
    var onTranscript: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var lastText = ""
    private var finishing = false
    /// True from the key going down until the session actually starts. The
    /// permission callbacks are asynchronous, so the key can come back up
    /// before there is anything to stop — without this the microphone would
    /// stay live with no key held.
    private var wanted = false

    private var listening: Bool { task != nil }

    /// The user's locale when its model is on this Mac, English otherwise.
    private static func recognizer() -> SFSpeechRecognizer? {
        for locale in [Locale.current, Locale(identifier: "en-US")] {
            if let recognizer = SFSpeechRecognizer(locale: locale),
               recognizer.supportsOnDeviceRecognition {
                return recognizer
            }
        }
        return nil
    }

    func beginCapture() {
        guard !listening, !wanted else { return }
        wanted = true
        requestPermissions { [weak self] granted in
            guard let self else { return }
            guard granted else {
                wanted = false
                onError?("Voice needs Microphone and Speech Recognition access: System Settings → Privacy & Security")
                return
            }
            // Released while the permission prompt was up: nothing to record.
            guard wanted else { return }
            start()
        }
    }

    func finishCapture() {
        wanted = false
        guard listening, !finishing else { return }
        finishing = true
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        request?.endAudio()
        // The final result callback delivers the transcript; if recognition
        // never produces one (silence), fall back after a beat.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, self.finishing else { return }
            self.deliver(self.lastText)
        }
    }

    private func start() {
        guard let recognizer = Self.recognizer() else {
            onError?("On-device speech recognition is not available for this language")
            return
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        self.request = request
        lastText = ""
        finishing = false

        let node = engine.inputNode
        let format = node.outputFormat(forBus: 0)
        // A Mac with no input device reports 0 Hz, and installTap answers that
        // with an Objective-C exception Swift cannot catch.
        guard format.sampleRate > 0, format.channelCount > 0 else {
            self.request = nil
            onError?("No microphone is available")
            return
        }
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            node.removeTap(onBus: 0)
            self.request = nil
            onError?("Could not open the microphone: \(error.localizedDescription)")
            return
        }
        onPartial?("")

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let result {
                    self.lastText = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.deliver(self.lastText)
                        return
                    }
                    self.onPartial?(self.lastText)
                }
                if error != nil, self.finishing {
                    self.deliver(self.lastText)
                }
            }
        }
    }

    /// Ends the session and hands the transcript over exactly once.
    private func deliver(_ text: String) {
        guard listening else { return }
        task?.cancel()
        task = nil
        request = nil
        finishing = false
        wanted = false
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            onError?("Heard nothing")
            return
        }
        onTranscript?(trimmed)
    }

    private func requestPermissions(_ done: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { speech in
            guard speech == .authorized else {
                DispatchQueue.main.async { done(false) }
                return
            }
            AVCaptureDevice.requestAccess(for: .audio) { mic in
                DispatchQueue.main.async { done(mic) }
            }
        }
    }
}
