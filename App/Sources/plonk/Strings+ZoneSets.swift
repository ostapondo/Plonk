import Foundation

// Zone sets: the picker, the canvas, the palette and the editor. English values
// live in Resources/en.lproj/Localizable.strings.

extension LocalizedStringResource {
    static let zoneSetTemplates = Self.key("zoneSet.templates")
    static let zoneSetCustom = Self.key("zoneSet.custom")
    static let zoneSetCreateNew = Self.key("zoneSet.createNew")
    static let zoneSetEmptyState = Self.key("zoneSet.emptyState")
    static let zoneSetEdgeSnappingCard = Self.key("zoneSet.edgeSnappingCard")
    static let zoneSetEdgeSnappingSubtitle = Self.key("zoneSet.edgeSnappingSubtitle")
    static let zoneSetNameField = Self.key("zoneSet.nameField")
    static let zoneSetShowOnScreen = Self.key("zoneSet.showOnScreen")
    static let zoneSetEmptyCard = Self.key("zoneSet.emptyCard")
    static let zoneSetRename = Self.key("zoneSet.rename")
    static let zoneSetEdgeSnapping = Self.key("zoneSet.edgeSnapping")
    static let zoneSetNewSet = Self.key("zoneSet.newSet")
    static let zoneSetEdgeHint = Self.key("zoneSet.edgeHint")
    static let zoneSetZoneHint = Self.key("zoneSet.zoneHint")
    static let zoneSetPreview = Self.key("zoneSet.preview")
    static let zoneSetPreviewHelp = Self.key("zoneSet.previewHelp")
    static let zoneSetDuplicate = Self.key("zoneSet.duplicate")
    static let zoneSetEdit = Self.key("zoneSet.edit")
    static let zoneSetManage = Self.key("zoneSet.manage")
    static let zoneSetManageHelp = Self.key("zoneSet.manageHelp")
    static let zoneSetTitle = Self.key("zoneSet.title")
    static let zoneSetOnThisScreenNow = Self.key("zoneSet.onThisScreenNow")
    static let zoneSetEditThis = Self.key("zoneSet.editThis")
    static let zoneSetEditCopy = Self.key("zoneSet.editCopy")
    static let zoneSetHintPick = Self.key("zoneSet.hintPick")
    static let zoneSetHintUse = Self.key("zoneSet.hintUse")
    static let zoneSetHintEdit = Self.key("zoneSet.hintEdit")
    static let zoneSetHintNew = Self.key("zoneSet.hintNew")
    static let zoneSetHintClose = Self.key("zoneSet.hintClose")

    static func zoneSetScreen(_ number: Int) -> LocalizedStringResource {
        Self.key("zoneSet.screen \(number)")
    }

    static func zoneSetScreenWithSize(_ number: Int, _ size: String) -> LocalizedStringResource {
        Self.key("zoneSet.screenWithSize \(number) \(size)")
    }

    /// The line under the set's name: the screen, its size, how many zones and
    /// how much air each window keeps.
    static func zoneSetSummary(_ number: Int, _ size: String, _ zones: String,
                               _ gap: Int) -> LocalizedStringResource {
        Self.key("zoneSet.summary \(number) \(size) \(zones) \(gap)")
    }

    static func zoneSetZoneCount(_ count: Int) -> LocalizedStringResource {
        Self.key("zoneSet.zoneCount \(count)")
    }

    static let zoneEditorName = Self.key("zoneEditor.name")
    static let zoneEditorSplit = Self.key("zoneEditor.split")
    static let zoneEditorResize = Self.key("zoneEditor.resize")
    static let zoneEditorDelete = Self.key("zoneEditor.delete")
    static let zoneEditorKeyboard = Self.key("zoneEditor.keyboard")
    static let zoneEditorSaveAndApply = Self.key("zoneEditor.saveAndApply")

    static func zoneEditorNameTaken(_ name: String) -> LocalizedStringResource {
        Self.key("zoneEditor.nameTaken \(name)")
    }
}
