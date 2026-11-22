import Testing
import Foundation
@testable import plonk

struct AppearanceSettingsTests {
    @Test func liquidGlassIsOnInAFileThatPredatesIt() throws {
        let config = try Config.decode(Data("""
        {"appearance": {"theme": "dark", "accentHex": "#8B93A6"}}
        """.utf8))
        #expect(config.appearance.liquidGlass)
        #expect(config.appearance.theme == "dark")
    }

    @Test func liquidGlassKeepsAStoredOff() throws {
        let config = try Config.decode(Data("""
        {"appearance": {"liquidGlass": false}}
        """.utf8))
        #expect(!config.appearance.liquidGlass)
    }
}
