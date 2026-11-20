import AppKit
import Testing
@testable import plonk

@MainActor
@Suite(.serialized)
struct QuickShotDimensionsTests {
    @Test func firstClickSelectsTheEntireUngroupedPixelValue() throws {
        let (window, dimensions) = makeControls()
        defer { window.makeFirstResponder(nil) }
        let editor = try editWidth(in: window, dimensions: dimensions)

        #expect(editor.string == "1234")
        #expect(editor.selectedRange() == NSRange(location: 0, length: 4))
    }

    @Test func fourDigitsFitInsideTheFieldEditor() throws {
        let (window, dimensions) = makeControls()
        defer { window.makeFirstResponder(nil) }
        let editor = try editWidth(in: window, dimensions: dimensions)
        let container = try #require(editor.textContainer)
        let font = try #require(editor.font)
        let digits = (editor.string as NSString).size(withAttributes: [.font: font]).width
        #expect(digits + 2 * container.lineFragmentPadding + 1 <= editor.visibleRect.width)
    }

    @Test func returnCommitsAndFocusesCanvas() throws {
        let (window, dimensions) = makeControls()
        let editor = try editWidth(in: window, dimensions: dimensions)
        var committed: Int?
        dimensions.onResize = { value, _ in committed = value }

        editor.insertText("800", replacementRange: editor.selectedRange())
        editor.doCommand(by: #selector(NSResponder.insertNewline(_:)))

        #expect(committed == 800)
        #expect(window.firstResponder === dimensions.canvas)
    }

    @Test func escapeDiscardsPendingInput() throws {
        let (window, dimensions) = makeControls()
        let editor = try editWidth(in: window, dimensions: dimensions)
        dimensions.onResize = { _, _ in Issue.record("Escape committed a dimension") }

        editor.insertText("800", replacementRange: editor.selectedRange())
        editor.doCommand(by: #selector(NSResponder.cancelOperation(_:)))

        #expect(window.firstResponder === dimensions.canvas)
        #expect(try editWidth(in: window, dimensions: dimensions).string == "1234")
        window.makeFirstResponder(nil)
    }

    @Test(arguments: ["", "0", "-1", "1.5", "9999999999999999999999", "abc"])
    func invalidReturnKeepsTheFieldEditor(_ input: String) throws {
        let (window, dimensions) = makeControls()
        let editor = try editWidth(in: window, dimensions: dimensions)
        dimensions.onResize = { _, _ in Issue.record("Invalid input committed a dimension") }

        editor.insertText(input, replacementRange: editor.selectedRange())
        editor.doCommand(by: #selector(NSResponder.insertNewline(_:)))

        #expect(window.firstResponder === editor)
        #expect(editor.string == input)
        window.makeFirstResponder(nil)
        HUD.shared.dismiss()
    }

    @Test(arguments: [false, true])
    func tabCommitsAndFocusesTheOtherDimension(reverse: Bool) throws {
        let (window, dimensions) = makeControls()
        let first = reverse ? CGPoint(x: 95, y: 14) : CGPoint(x: 27, y: 14)
        #expect(dimensions.selectField(at: dimensions.convert(first, to: nil)))
        let editor = try #require(window.firstResponder as? NSTextView)
        var committedWidth: Bool?
        dimensions.onResize = { _, width in committedWidth = width }

        editor.insertText("800", replacementRange: editor.selectedRange())
        editor.doCommand(by: reverse ? #selector(NSResponder.insertBacktab(_:)) : #selector(NSResponder.insertTab(_:)))

        #expect(committedWidth == !reverse)
        let next = try #require(window.firstResponder as? NSTextView)
        #expect(next.string == (reverse ? "1234" : "567"))
        window.makeFirstResponder(nil)
    }

    @Test(arguments: ["800", "invalid"])
    func blurCommitsOnlyAValidValue(_ input: String) throws {
        let (window, dimensions) = makeControls()
        let editor = try editWidth(in: window, dimensions: dimensions)
        var committed: Int?
        dimensions.onResize = { value, _ in
            committed = value
            dimensions.update(size: CGSize(width: value, height: 567), locked: false)
        }
        editor.insertText(input, replacementRange: editor.selectedRange())

        window.makeFirstResponder(dimensions.canvas)

        #expect(committed == Int(input))
        #expect(try editWidth(in: window, dimensions: dimensions).string == (committed == nil ? "1234" : input))
        window.makeFirstResponder(nil)
    }

    @Test func leavingAnUnchangedFieldDoesNotResizeALockedSelection() throws {
        let (window, dimensions) = makeControls()
        dimensions.update(size: CGSize(width: 1234, height: 567), locked: true)
        _ = try editWidth(in: window, dimensions: dimensions)
        dimensions.onResize = { _, _ in Issue.record("Focusing a field changed the crop") }

        window.makeFirstResponder(dimensions.canvas)
    }

    private func makeControls() -> (NSWindow, QuickShotDimensions) {
        _ = NSApplication.shared
        let dimensions = QuickShotDimensions()
        let content = NSView(frame: dimensions.frame)
        let window = NSWindow(contentRect: content.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = content
        content.addSubview(dimensions)
        dimensions.canvas = content
        dimensions.update(size: CGSize(width: 1234, height: 567), locked: false)
        return (window, dimensions)
    }

    private func editWidth(in window: NSWindow, dimensions: QuickShotDimensions) throws -> NSTextView {
        #expect(dimensions.selectField(at: dimensions.convert(CGPoint(x: 27, y: 14), to: nil)))
        return try #require(window.firstResponder as? NSTextView)
    }
}
