import Foundation

/// Runs command-line adapters away from AppDelegate. Output goes to a file so
/// a verbose tool cannot fill a pipe and deadlock before anybody reads it.
final class AgentAdapterRunner {
    struct Finished {
        let status: Int32
        let lastError: String
        let seconds: Int
    }

    enum Result {
        case finished(Finished)
        case couldNotStart(String)
    }

    private let lock = NSLock()
    private var running: [UUID: Process] = [:]

    func run(_ adapter: AgentAdapter, prompt: String, completion: @escaping (Result) -> Void) {
        let invocation = AgentAdapter.invocation(command: adapter.command, prompt: prompt)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", invocation.command]
        process.environment = ProcessInfo.processInfo.environment
            .merging(invocation.environment) { _, prompt in prompt }

        let id = UUID()
        let started = Date()
        let errorLog = FileManager.default.temporaryDirectory
            .appendingPathComponent("plonk-adapter-\(id.uuidString).log")
        FileManager.default.createFile(atPath: errorLog.path, contents: nil)
        let errors = try? FileHandle(forWritingTo: errorLog)
        process.standardError = errors ?? FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice

        process.terminationHandler = { [weak self] finished in
            try? errors?.close()
            let complaint = (try? String(contentsOf: errorLog, encoding: .utf8)) ?? ""
            try? FileManager.default.removeItem(at: errorLog)
            self?.remove(id)
            let result = Finished(
                status: finished.terminationStatus,
                lastError: complaint.split(separator: "\n").last.map(String.init) ?? "",
                seconds: Int(Date().timeIntervalSince(started).rounded())
            )
            DispatchQueue.main.async { completion(.finished(result)) }
        }

        lock.withLock { running[id] = process }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try process.run()
            } catch {
                try? errors?.close()
                try? FileManager.default.removeItem(at: errorLog)
                self?.remove(id)
                DispatchQueue.main.async { completion(.couldNotStart(error.localizedDescription)) }
            }
        }
    }

    private func remove(_ id: UUID) {
        _ = lock.withLock { running.removeValue(forKey: id) }
    }
}
