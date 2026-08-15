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
    /// True only while a start is in flight: the permission callbacks are
    /// asynchronous, so the key can come back up before there is anything to
    /// stop, and a key repeat can ask twice. It is cleared on every path out
    /// of `start`, so a start that fails cannot leave voice wedged.
    private var starting = false

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
        guard !listening, !starting else { return }
        starting = true
        requestPermissions { [weak self] granted in
            guard let self else { return }
            guard granted else {
                starting = false
                onError?(String(localized: .voiceErrorPermissions))
                return
            }
            // Released while the permission prompt was up: nothing to record.
            guard starting else { return }
            start()
        }
    }

    func finishCapture() {
        starting = false
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
        // Whatever happens below, a start is no longer in flight.
        defer { starting = false }
        guard let recognizer = Self.recognizer() else {
            onError?(String(localized: .voiceErrorNoLanguage))
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
            onError?(String(localized: .voiceErrorNoMicrophone))
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
            onError?(String(localized: .voiceErrorMicrophoneFailed(error.localizedDescription)))
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
        starting = false
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            onError?(String(localized: .voiceErrorHeardNothing))
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
