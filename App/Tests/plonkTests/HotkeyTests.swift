import Testing
import AppKit
@testable import plonk

struct HotkeyTests {

    @Test func specRoundTripsThroughParsing() throws {
        for action in HotkeyAction.allCases {
            let spec = action.defaultHotkey.spec
            let parsed = try #require(Hotkey(spec: spec), Comment(rawValue: action.rawValue))
            #expect(parsed == action.defaultHotkey, Comment(rawValue: spec))
        }
    }

    @Test func specIsReadableAndOrderIndependent() throws {
        let hotkey = try #require(Hotkey(spec: "option+control+left"))
        #expect(hotkey.control && hotkey.option)
        #expect(!hotkey.shift && !hotkey.command)
        #expect(hotkey.spec == "control+option+left")
        #expect(hotkey.display == "⌃⌥←")
    }

    @Test func specWithoutAKeyIsRejected() {
        #expect(Hotkey(spec: "control+option") == nil)
        #expect(Hotkey(spec: "control+option+nonsense") == nil)
        #expect(Hotkey(spec: "") == nil)
    }

    @Test func everyActionHasADistinctDefault() {
        let defaults = HotkeyAction.allCases.map(\.defaultHotkey)
        for (index, hotkey) in defaults.enumerated() {
            #expect(!defaults[(index + 1)...].contains(hotkey), Comment(rawValue: hotkey.display))
        }
    }

    @Test func unsetActionsFallBackToTheirDefault() {
        var config = Config()
        config.hotkeys["leftHalf"] = "command+shift+1"
        let resolved = config.resolvedHotkeys
        #expect(resolved[.leftHalf] == Hotkey(spec: "command+shift+1"))
        #expect(resolved[.rightHalf] == HotkeyAction.rightHalf.defaultHotkey)
    }

    @Test func anEmptySpecMeansUnbound() {
        var config = Config()
        config.hotkeys["center"] = ""
        #expect(config.resolvedHotkeys[.center] == nil)
        #expect(config.resolvedHotkeys[.maximize] != nil)
    }
}
