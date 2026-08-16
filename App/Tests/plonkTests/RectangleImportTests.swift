import Testing
import Foundation
import Carbon.HIToolbox
@testable import plonk

/// Reading someone else's config file. The numbers here are Rectangle's own:
/// virtual key codes, and NSEvent modifier flags where control is 1 << 18 and
/// option is 1 << 19, so ⌃⌥ is 786432.
struct RectangleImportTests {
    private let controlOption: UInt = (1 << 18) | (1 << 19)

    private func export(shortcuts: String, defaults: String = "{}") -> Data {
        Data("""
        {"bundleId":"com.knollsoft.Rectangle","version":"84",
         "shortcuts":\(shortcuts),"defaults":\(defaults)}
        """.utf8)
    }

    // MARK: - The shape of the file

    @Test func theExportedFileBecomesBindings() throws {
        let data = export(shortcuts: """
        {"leftHalf":{"keyCode":123,"modifierFlags":786432},
         "maximize":{"keyCode":36,"modifierFlags":786432}}
        """)
        let found = try #require(RectangleImport.read(exportedJSON: data))
        #expect(found.bindings[.leftHalf] == Hotkey(keyCode: UInt32(kVK_LeftArrow), control: true, option: true))
        #expect(found.bindings[.maximize] == Hotkey(keyCode: UInt32(kVK_Return), control: true, option: true))
    }

    @Test func somethingThatIsNotARectangleExportIsRefused() {
        #expect(RectangleImport.read(exportedJSON: Data("{}".utf8)) == nil)
        #expect(RectangleImport.read(exportedJSON: Data("not json".utf8)) == nil)
    }

    /// The live preferences of an installed copy hold the same two numbers, one
    /// level up, mixed in with a whole defaults domain of unrelated things.
    @Test func theLivePreferencesReadTheSameWay() {
        let domain: [String: Any] = [
            "leftHalf": ["keyCode": 123, "modifierFlags": 786432],
            "AppleLanguages": ["en"],
            "launchOnLogin": true,
            "gapSize": 8,
        ]
        let found = RectangleImport.read(defaults: domain)
        #expect(found.bindings[.leftHalf] != nil)
        #expect(found.gapPoints == 8)
    }

    @Test func theExportedGapArrivesWrappedInItsType() throws {
        let data = export(shortcuts: "{}", defaults: #"{"gapSize":{"float":12}}"#)
        let found = try #require(RectangleImport.read(exportedJSON: data))
        #expect(found.gapPoints == 12)
    }

    // MARK: - What is left behind, and why

    /// The whole point of the mapping table: a fixed-grid action is reported by
    /// name rather than guessed onto a numbered zone that means something else
    /// on every screen not using Thirds.
    @Test func theFixedGridActionsAreNamedNotGuessed() throws {
        let data = export(shortcuts: """
        {"firstThird":{"keyCode":2,"modifierFlags":786432},
         "topLeftNinth":{"keyCode":13,"modifierFlags":786432}}
        """)
        let found = try #require(RectangleImport.read(exportedJSON: data))
        #expect(found.bindings.isEmpty)
        #expect(found.unmapped == ["firstThird", "topLeftNinth"])
    }

    @Test func anActionRectangleUnboundIsNotImported() throws {
        let data = export(shortcuts: #"{"leftHalf":{"keyCode":-1,"modifierFlags":0}}"#)
        let found = try #require(RectangleImport.read(exportedJSON: data))
        #expect(found.isEmpty)
        #expect(found.unmapped.isEmpty)
    }

    /// A combination with nothing held down cannot be a global hotkey, so it is
    /// left behind instead of being saved as one that can never fire.
    @Test func aBindingWithNoModifierIsLeftBehind() throws {
        let data = export(shortcuts: #"{"leftHalf":{"keyCode":123,"modifierFlags":0}}"#)
        let found = try #require(RectangleImport.read(exportedJSON: data))
        #expect(found.bindings.isEmpty)
    }

    @Test func aKeyWithNoNameHereIsLeftBehind() {
        // kVK_F20 is a real key code that Plonk's table stops short of.
        #expect(RectangleImport.hotkey(keyCode: kVK_F20, modifierFlags: controlOption) == nil)
    }

    /// Arrow keys arrive carrying the function and numeric-pad bits as well,
    /// and caps lock rides along on whatever was held. None of those belong in
    /// a stored binding.
    @Test func onlyTheFourRealModifiersSurvive() throws {
        let noise: UInt = controlOption | (1 << 16) | (1 << 21) | (1 << 23)
        let hotkey = try #require(RectangleImport.hotkey(keyCode: kVK_LeftArrow, modifierFlags: noise))
        #expect(hotkey == Hotkey(keyCode: UInt32(kVK_LeftArrow), control: true, option: true))
        #expect(hotkey.spec == "control+option+left")
    }

    // MARK: - Applying it

    @Test func applyingWritesSpecsTheConfigCanReadBack() {
        var config = Config()
        let found = RectangleImport.Found(bindings: [.leftHalf: Hotkey(
            keyCode: UInt32(kVK_ANSI_H), control: true, command: true
        )])
        RectangleImport.apply(found, to: &config)
        #expect(config.hotkeys["leftHalf"] == "control+command+h")
        #expect(config.resolvedHotkeys[.leftHalf]?.keyCode == UInt32(kVK_ANSI_H))
    }

    /// ⌃⌥T is Plonk's own "copy the text out of a region". Someone who put
    /// Rectangle's left half there gets it, and is told what it cost.
    @Test func anImportedKeyFreesWhateverPlonkHadOnIt() {
        var config = Config()
        let found = RectangleImport.Found(bindings: [.leftHalf: Hotkey(
            keyCode: UInt32(kVK_ANSI_T), control: true, option: true
        )])
        let displaced = RectangleImport.apply(found, to: &config)
        #expect(displaced == [.captureText])
        #expect(config.hotkeys["captureText"] == "")
        #expect(config.resolvedHotkeys[.captureText] == nil)
    }

    /// Two window actions trading keys is not a displacement: both end up
    /// bound, so neither should be reported as having lost anything.
    @Test func actionsThatSwapKeysAreNotReportedAsDisplaced() {
        var config = Config()
        let found = RectangleImport.Found(bindings: [
            .center: Hotkey(keyCode: UInt32(kVK_Return), control: true, option: true),
            .maximize: Hotkey(keyCode: UInt32(kVK_ANSI_C), control: true, option: true),
        ])
        let displaced = RectangleImport.apply(found, to: &config)
        #expect(displaced.isEmpty)
        #expect(config.resolvedHotkeys[.center]?.keyCode == UInt32(kVK_Return))
        #expect(config.resolvedHotkeys[.maximize]?.keyCode == UInt32(kVK_ANSI_C))
    }

    /// The defaults the two apps already share. Importing a stock Rectangle
    /// should be a no-op on the ten keys anyone actually presses, which is the
    /// claim docs/from-rectangle.md makes.
    @Test func importingAStockRectangleChangesNothingAndDisplacesNothing() throws {
        let stock: [String: Int] = [
            "leftHalf": kVK_LeftArrow, "rightHalf": kVK_RightArrow,
            "topHalf": kVK_UpArrow, "bottomHalf": kVK_DownArrow,
            "topLeft": kVK_ANSI_U, "topRight": kVK_ANSI_I,
            "bottomLeft": kVK_ANSI_J, "bottomRight": kVK_ANSI_K,
            "maximize": kVK_Return, "center": kVK_ANSI_C,
        ]
        let entries = stock.map { name, key in
            "\"\(name)\":{\"keyCode\":\(key),\"modifierFlags\":786432}"
        }.joined(separator: ",")
        let found = try #require(RectangleImport.read(exportedJSON: export(shortcuts: "{\(entries)}")))

        var config = Config()
        let before = config.resolvedHotkeys
        let displaced = RectangleImport.apply(found, to: &config)
        #expect(displaced.isEmpty)
        #expect(config.resolvedHotkeys == before)
    }

    /// The gap arrives from a file, so it gets the same bounds the slider has
    /// rather than whatever number happened to be in there.
    @Test func theGapIsHeldInsideTheSameBoundsAsTheSlider() {
        var config = Config()
        RectangleImport.apply(RectangleImport.Found(gapPoints: -4), to: &config)
        #expect(config.zoneGap == 0)
        RectangleImport.apply(RectangleImport.Found(gapPoints: 4000), to: &config)
        #expect(config.zoneGap == Config.gapLimit)
    }
}
