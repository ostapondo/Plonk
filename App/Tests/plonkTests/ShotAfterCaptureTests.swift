import Foundation
import Testing
@testable import plonk

struct ShotAfterCaptureTests {
    @Test func oldConfigDefaultsToQuickActions() throws {
        let config = try Config.decode(Data("{}".utf8))
        #expect(config.shotAfterCapture == .quickActions)
    }

    @Test func unknownActionPreservesOtherSettings() throws {
        let config = try Config.decode(Data(#"{"shotAfterCapture":"future","shotFolder":"/tmp/captures"}"#.utf8))
        #expect(config.shotAfterCapture == .quickActions)
        #expect(config.shotFolder == "/tmp/captures")
    }

    @Test func editorPreferenceRoundTrips() throws {
        var config = Config()
        config.shotAfterCapture = .editor
        let decoded = try Config.decode(JSONEncoder().encode(config))
        #expect(decoded.shotAfterCapture == .editor)
    }

    @Test func quickActionsOnlyApplyToManualRegionCapture() {
        #expect(ShotAfterCapture.quickActions.usesOverlay(for: .region))
        #expect(!ShotAfterCapture.quickActions.usesOverlay(for: .window))
        #expect(!ShotAfterCapture.quickActions.usesOverlay(for: .screen))
        #expect(!ShotAfterCapture.editor.usesOverlay(for: .region))
    }
}
