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
    /// rather than whatever number happened to be in there. The import writes
    /// it and `clamp` holds it, which is the one path every writer takes;
    /// ConfigStore.update runs the second half for the real caller.
    @Test func theGapIsHeldInsideTheSameBoundsAsTheSlider() {
        var config = Config()
        RectangleImport.apply(RectangleImport.Found(gapPoints: -4), to: &config)
        config.clamp()
        #expect(config.zoneGap == 0)
        RectangleImport.apply(RectangleImport.Found(gapPoints: 4000), to: &config)
        config.clamp()
        #expect(config.zoneGap == Config.gapLimit)
    }

    /// Importing the same setup twice should land in the same place. A second
    /// run reporting another displacement would mean the report describes the
    /// config's history rather than this import.
    @Test func applyingTheSameReadTwiceChangesNothingTheSecondTime() {
        var config = Config()
        let found = RectangleImport.Found(
            bindings: [.leftHalf: Hotkey(keyCode: UInt32(kVK_ANSI_T), control: true, option: true)],
            gapPoints: 8
        )
        let first = RectangleImport.apply(found, to: &config)
        let snapshot = config.hotkeys
        let second = RectangleImport.apply(found, to: &config)
        #expect(first == [.captureText])
        #expect(second.isEmpty)
        #expect(config.hotkeys == snapshot)
        #expect(config.zoneGap == 8)
    }

    /// An action Rectangle itself has unbound is not something this app failed
    /// to map, so it does not belong in the list of what was left behind.
    @Test func anUnboundFixedGridActionIsNotReportedEither() throws {
        let data = export(shortcuts: #"""
        {"firstThird":{"keyCode":-1,"modifierFlags":0},
         "lastThird":{"keyCode":5,"modifierFlags":786432}}
        """#)
        let found = try #require(RectangleImport.read(exportedJSON: data))
        #expect(found.unmapped == ["lastThird"])
    }

    /// Rectangle's own default restore is ⌃⌥⌫, and delete had no name in
    /// Hotkey's table, so the one binding the docs promise by name could not be
    /// represented at all and was dropped without a word.
    @Test func rectanglesDefaultRestoreImports() throws {
        let data = export(shortcuts: #"{"restore":{"keyCode":51,"modifierFlags":786432}}"#)
        let found = try #require(RectangleImport.read(exportedJSON: data))
        #expect(found.bindings[.unsnap] == Hotkey(
            keyCode: UInt32(kVK_Delete), control: true, option: true
        ))
        #expect(found.unmapped.isEmpty)
    }

    /// A key with no name here cannot be drawn or re-recorded, so it is not
    /// imported — but it was bound in Rectangle, so it is reported rather than
    /// dropped in silence.
    @Test func aBindingOnAKeyWithNoNameIsReported() throws {
        let data = export(shortcuts: #"{"leftHalf":{"keyCode":90,"modifierFlags":786432}}"#)
        let found = try #require(RectangleImport.read(exportedJSON: data))
        #expect(found.bindings.isEmpty)
        #expect(found.unmapped == ["leftHalf"])
        #expect(!found.isEmpty)
    }

    /// A setup that binds nothing here is still a setup. Reporting it as
    /// absent is what sent the caller looking for a Rectangle they still have.
    @Test func aGridOnlySetupIsNotAnAbsence() throws {
        let data = export(shortcuts: #"{"firstThird":{"keyCode":2,"modifierFlags":786432}}"#)
        let found = try #require(RectangleImport.read(exportedJSON: data))
        #expect(found.bindings.isEmpty)
        #expect(!found.isEmpty)
    }

    /// Two imported actions on one combination: the first is cleared by the
    /// second and never gets a key back, so it has to be reported. Testing
    /// membership of the import instead of the result hid exactly this.
    @Test func anImportedActionLeftWithNoKeyIsStillReported() {
        var config = Config()
        let shared = Hotkey(keyCode: UInt32(kVK_ANSI_X), control: true, option: true)
        let displaced = RectangleImport.apply(
            RectangleImport.Found(bindings: [.leftHalf: shared, .rightHalf: shared]),
            to: &config
        )
        #expect(displaced == [.leftHalf])
        #expect(config.resolvedHotkeys[.leftHalf] == nil)
        #expect(config.resolvedHotkeys[.rightHalf] == shared)
    }

    /// Every displaced action, not just the first: each one is a key that has
    /// stopped working, and from-rectangle.md promises none go quietly.
    @Test func everyDisplacedActionIsReported() {
        var config = Config()
        let displaced = RectangleImport.apply(RectangleImport.Found(bindings: [
            .leftHalf: Hotkey(keyCode: UInt32(kVK_ANSI_T), control: true, option: true),
            .rightHalf: Hotkey(keyCode: UInt32(kVK_ANSI_R), control: true, option: true),
        ]), to: &config)
        #expect(Set(displaced) == [.captureText, .ruler])
    }

    // MARK: - Telling one kind of leftover from another

    /// Matched on the end of the name, so fractions Rectangle adds later are
    /// recognised without this list being chased.
    @Test func everyShapeOfFractionIsRecognised() {
        for name in ["firstThird", "first-third", "lastTwoThirds", "secondFourth",
                     "topLeftNinth", "bottomRightEighth", "topLeftTwelfth",
                     "bottomCenterSixteenth", "topVerticalThird", "centerHalf"] {
            #expect(RectangleImport.isFixedGrid(name), "\(name) should read as a fraction")
        }
    }

    /// Four of the five halves end in "Half" and all four are imported, so the
    /// suffix rule must not swallow them.
    @Test func theHalvesAreNotMistakenForFractions() {
        for name in ["leftHalf", "rightHalf", "topHalf", "bottomHalf",
                     "maximize", "center", "restore", "nextDisplay"] {
            #expect(!RectangleImport.isFixedGrid(name), "\(name) should not read as a fraction")
        }
    }
}
