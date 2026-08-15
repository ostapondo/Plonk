import Foundation

// The screenshot editor, the shortcut guide, the command palette, and the
// windows and menus around them. English values live in
// Resources/en.lproj/Localizable.strings.

extension LocalizedStringResource {
    static let shotEditorWidth = Self.key("shotEditor.width")
    static let shotEditorUndo = Self.key("shotEditor.undo")
    static let shotEditorRedo = Self.key("shotEditor.redo")
    static let shotEditorSaveAs = Self.key("shotEditor.saveAs")
    static let shotEditorSaveToFolder = Self.key("shotEditor.saveToFolder")
    static let shotEditorCopy = Self.key("shotEditor.copy")
    static let shotEditorRenderFailed = Self.key("shotEditor.renderFailed")
    static let shotEditorWriteFailed = Self.key("shotEditor.writeFailed")

    static let toolPen = Self.key("tool.pen")
    static let toolArrow = Self.key("tool.arrow")
    static let toolRectangle = Self.key("tool.rectangle")
    static let toolEllipse = Self.key("tool.ellipse")
    static let toolHighlight = Self.key("tool.highlight")

    static let guideFilter = Self.key("guide.filter")
    static let guideThisApp = Self.key("guide.thisApp")
    static let guideNoShortcuts = Self.key("guide.noShortcuts")
    static let guideReadFromMenus = Self.key("guide.readFromMenus")

    static func guideWindowTitle(_ app: String) -> LocalizedStringResource {
        Self.key("guide.windowTitle \(app)")
    }

    static let palettePrompt = Self.key("palette.prompt")
    static let paletteGroupAgent = Self.key("palette.groupAgent")
    static let paletteGroupWorkspaces = Self.key("palette.groupWorkspaces")
    static let paletteGroupZoneSets = Self.key("palette.groupZoneSets")
    static let paletteGroupGadgets = Self.key("palette.groupGadgets")
    static let paletteGroupSettings = Self.key("palette.groupSettings")
    static let paletteTheAgent = Self.key("palette.theAgent")
    static let paletteAskTheAgent = Self.key("palette.askTheAgent")
    static let palettePickZoneSet = Self.key("palette.pickZoneSet")
    static let paletteEditZoneSets = Self.key("palette.editZoneSets")
    static let paletteStopAwake = Self.key("palette.stopAwake")
    static let paletteKeepAwake = Self.key("palette.keepAwake")
    static let paletteCheckUpdates = Self.key("palette.checkUpdates")

    static func paletteNoMatch(_ query: String) -> LocalizedStringResource {
        Self.key("palette.noMatch \(query)")
    }

    static func paletteAsk(_ who: String, _ prompt: String) -> LocalizedStringResource {
        Self.key("palette.ask \(who) \(prompt)")
    }

    static func paletteLaunchWorkspace(_ name: String) -> LocalizedStringResource {
        Self.key("palette.launchWorkspace \(name)")
    }

    static func paletteUseZoneSet(_ name: String) -> LocalizedStringResource {
        Self.key("palette.useZoneSet \(name)")
    }

    static func paletteOpenPage(_ page: String) -> LocalizedStringResource {
        Self.key("palette.openPage \(page)")
    }

    static let windowZones = Self.key("window.zones")
    static let windowScreenshot = Self.key("window.screenshot")
    static let windowCropLive = Self.key("window.cropLive")
    static let windowCropStill = Self.key("window.cropStill")

    static func windowCropTitle(_ kind: String) -> LocalizedStringResource {
        Self.key("window.cropTitle \(kind)")
    }

    static let editMenu = Self.key("edit.menu")
    static let editUndo = Self.key("edit.undo")
    static let editRedo = Self.key("edit.redo")
    static let editCut = Self.key("edit.cut")
    static let editCopy = Self.key("edit.copy")
    static let editPaste = Self.key("edit.paste")
    static let editSelectAll = Self.key("edit.selectAll")

    static let appGrant = Self.key("app.grant")
}
