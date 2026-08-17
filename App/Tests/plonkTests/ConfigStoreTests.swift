import Testing
import Foundation
@testable import plonk

// The store: the one way a setting is written, and what it promises whoever
// listens: clamped, saved, then told.
struct ConfigStoreTests {

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("plonk-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func savesAndReloads() {
        let dir = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = ConfigStore(directory: dir)
        store.update {
            $0.workspaces["work"] = Workspace(items: [
                WorkspaceItem(app: "Safari", x: 0, y: 0, w: 0.5, h: 1),
            ])
        }

        let reopened = ConfigStore(directory: dir)
        reopened.load()
        #expect(reopened.config.workspaces["work"]?.items.count == 1)
    }

    @Test func corruptFileIsSetAsideInsteadOfSilentlyOverwritten() throws {
        let dir = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("config.json")
        try Data("{ not json".utf8).write(to: file)

        let store = ConfigStore(directory: dir)
        store.load()

        #expect(store.config.workspaces.isEmpty)
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("config.json.bad").path))
        // Losing every saved workspace has to reach the user, not just the log.
        #expect(store.loadFailure?.contains("config.json.bad") == true)
    }

    /// The bounds live in Config.clamp and the store is what runs it, so a
    /// caller that writes a raw number (a Rectangle import, a route) never
    /// gets it saved as written.
    @Test func updateClampsBeforeSavingAndTelling() {
        let dir = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ConfigStore(directory: dir)
        var seen: Double?
        store.didMutate = { seen = store.config.zoneGap }

        store.update { $0.zoneGap = 4000 }
        #expect(store.config.zoneGap == Config.gapLimit)
        // Whoever listens sees the clamped, saved value, not the raw write.
        #expect(seen == Config.gapLimit)

        let reopened = ConfigStore(directory: dir)
        reopened.load()
        #expect(reopened.config.zoneGap == Config.gapLimit)
    }

    /// A listener that writes back (keep-awake persisting a session) does so
    /// against the store's newest state, and each write is announced once.
    @Test func aWriteMadeFromDidMutateSeesTheFirstWrite() {
        let dir = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ConfigStore(directory: dir)
        var announced = 0
        store.didMutate = {
            announced += 1
            guard store.config.zoneGap == 12, !store.config.sawFirstSnap else { return }
            store.update { $0.sawFirstSnap = true }
        }
        store.update { $0.zoneGap = 12 }
        #expect(store.config.zoneGap == 12)
        #expect(store.config.sawFirstSnap)
        #expect(announced == 2)
    }

    @Test func aReadableConfigReportsNoFailure() {
        let dir = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ConfigStore(directory: dir)
        store.update { $0.shotFolder = "~/Pictures" }

        let reopened = ConfigStore(directory: dir)
        reopened.load()
        #expect(reopened.loadFailure == nil)
    }
}
