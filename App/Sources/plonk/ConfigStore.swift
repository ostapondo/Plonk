import Foundation

// The one way a setting is written. update() clamps, saves, and tells
// whoever is listening, which is how a change reaches the managers; see
// AppDelegate.applyConfig.

final class ConfigStore {
    private(set) var config = Config()
    /// Set when `load` had to set an unreadable config aside, so the UI can say so.
    private(set) var loadFailure: String?
    /// Fires after every update(), whoever triggered it — feeds live events.
    var didMutate: (() -> Void)?

    private let url: URL
    private let backupURL: URL

    /// Where the app keeps what it owns: the config, the API token.
    static var supportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Plonk", isDirectory: true)
    }

    init(directory: URL? = nil) {
        let dir = directory ?? Self.supportDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("config.json")
        backupURL = dir.appendingPathComponent("config.json.bad")
    }

    func load() {
        guard let data = try? Data(contentsOf: url) else { return }
        do {
            config = try Config.decode(data)
            // A file edited by hand is as much a caller as the slider is.
            config.clamp()
        } catch {
            // Keep the unreadable file instead of overwriting it on the next
            // save, so saved layouts can still be recovered by hand.
            NSLog("Plonk: config.json is unreadable (\(error)); moved to \(backupURL.path)")
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.moveItem(at: url, to: backupURL)
            loadFailure = String(localized: .warningSettingsReset(backupURL.path))
        }
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try encoder.encode(config).write(to: url, options: .atomic)
        } catch {
            NSLog("Plonk: could not write config: \(error)")
        }
    }

    func update(_ mutate: (inout Config) -> Void) {
        mutate(&config)
        config.clamp()
        save()
        didMutate?()
    }
}
