import CoreGraphics
import Testing
@testable import plonk

private func line(_ text: String, _ x: Double, _ y: Double) -> TextExtractor.Line {
    TextExtractor.Line(text: text, box: FracRect(x, y, 0.1, 0.02), confidence: 1)
}

struct TextExtractorTests {

    // MARK: - coordinate space

    /// Vision normalizes with the origin at the bottom-left; everything Plonk
    /// hands out has it at the top-left.
    @Test func flipsVisionBoxesToTopLeft() {
        let box = TextExtractor.topLeft(CGRect(x: 0.1, y: 0.7, width: 0.3, height: 0.2))
        #expect(abs(box.x - 0.1) < 0.0001)
        #expect(abs(box.y - 0.1) < 0.0001)
        #expect(abs(box.w - 0.3) < 0.0001)
        #expect(abs(box.h - 0.2) < 0.0001)
    }

    @Test func aBoxAtTheBottomLandsAtTheBottom() {
        let box = TextExtractor.topLeft(CGRect(x: 0, y: 0, width: 1, height: 0.1))
        #expect(abs(box.y - 0.9) < 0.0001)
    }

    /// Vision occasionally reports a box a hair outside the image; a fraction
    /// past 0...1 would be refused everywhere else in the API.
    @Test func staysWithinTheImage() {
        let box = TextExtractor.topLeft(CGRect(x: -0.05, y: -0.05, width: 1.2, height: 1.2))
        #expect(box.x >= 0 && box.y >= 0)
        #expect(box.w <= 1 && box.h <= 1)
    }

    // MARK: - reading order

    @Test func readsTopToBottom() {
        let lines = [line("third", 0, 0.9), line("first", 0, 0.1), line("second", 0, 0.5)]
        #expect(TextExtractor.joined(lines) == "first\nsecond\nthird")
    }

    @Test func readsLeftToRightWithinALine() {
        let lines = [line("world", 0.5, 0.300), line("hello", 0.1, 0.301)]
        #expect(TextExtractor.joined(lines) == "hello\nworld")
    }

    @Test func nothingReadIsAnEmptyString() {
        #expect(TextExtractor.joined([]).isEmpty)
    }

    /// Rows are grouped before anything inside them is sorted. Asking "are
    /// these two within a band of each other" pairwise is not a consistent
    /// ordering — it can hold for A,B and B,C but not A,C — and sorting on
    /// that scrambles the very text it is meant to straighten out.
    ///
    /// Here five ragged lines fall into three rows, each anchored on its own
    /// first line: A and B share one, C and D the next, E is alone.
    @Test func raggedLinesGroupIntoRowsBeforeSorting() {
        let lines = [
            line("A", 0.30, 0.100), line("B", 0.05, 0.107), line("C", 0.60, 0.114),
            line("D", 0.10, 0.121), line("E", 0.02, 0.128),
        ]
        #expect(TextExtractor.joined(lines) == "B\nA\nD\nC\nE")
    }

    @Test func everyLineComesBackExactlyOnce() {
        let lines = (0..<40).map { line("w\($0)", Double($0 % 7) / 7, Double($0) * 0.004) }
        #expect(TextExtractor.joined(lines).split(separator: "\n").count == 40)
    }

    @Test func farApartLinesNeverShareARow() {
        let lines = [line("bottom", 0.9, 0.8), line("top", 0.1, 0.1)]
        #expect(TextExtractor.joined(lines) == "top\nbottom")
    }
}
