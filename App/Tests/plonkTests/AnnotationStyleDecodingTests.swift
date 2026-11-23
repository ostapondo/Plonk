import Foundation
import Testing
@testable import plonk

/// A bad annotation style must cost that one value, never the rest of config.json.
struct AnnotationStyleDecodingTests {
    @Test func unknownColorFallsBackWithoutLosingTheConfig() throws {
        let config = try Config.decode(Data("""
        {"appearance":{"accentHex":"#8C31A6"},
         "shotAnnotationStyles":{"rectangle":{"color":"pink","width":6},"pen":{"color":"Red"}}}
        """.utf8))

        #expect(config.appearance.accentHex == "#8C31A6")
        #expect(config.shotAnnotationStyles.rectangle == AnnotationStyle(width: 6, color: .red))
        #expect(config.shotAnnotationStyles.pen.color == .red)
    }

    @Test func badValuesFallBackToThatToolsDefault() throws {
        let config = try Config.decode(Data("""
        {"shotAnnotationStyles":{"highlight":{"color":"pink","width":"wide"},"arrow":{"color":"Blue"}}}
        """.utf8))

        #expect(config.shotAnnotationStyles.highlight == AnnotationStyles().highlight)
        #expect(config.shotAnnotationStyles.arrow.color == .blue)
    }

    @Test(arguments: ["\"x\"", "[]", "5", "true"])
    func stylesThatAreNotAnObjectKeepTheDefaults(_ value: String) throws {
        let config = try Config.decode(Data("""
        {"appearance":{"accentHex":"#8C31A6"},"shotAnnotationStyles":\(value)}
        """.utf8))

        #expect(config.appearance.accentHex == "#8C31A6")
        #expect(config.shotAnnotationStyles == AnnotationStyles())
    }

    @Test func fractionalWidthIsRounded() throws {
        let config = try Config.decode(Data("""
        {"shotAnnotationStyles":{"arrow":{"width":4.5,"color":"blue"},"ellipse":{"width":7.4}}}
        """.utf8))

        #expect(config.shotAnnotationStyles.arrow == AnnotationStyle(width: 5, color: .blue))
        #expect(config.shotAnnotationStyles.ellipse.width == 7)
    }

    @Test func nonNumericWidthOrStyleKeepsTheDefault() throws {
        let config = try Config.decode(Data("""
        {"shotAnnotationStyles":{"arrow":{"width":"wide","color":"green"},"highlight":"yellow"}}
        """.utf8))

        #expect(config.shotAnnotationStyles.arrow == AnnotationStyle(width: 4, color: .green))
        #expect(config.shotAnnotationStyles.highlight == AnnotationStyles().highlight)
    }

    @Test func outOfRangeWidthIsClampedToTheTool() throws {
        var config = try Config.decode(Data("""
        {"shotAnnotationStyles":{"highlight":{"width":1.2},"pen":{"width":123456}}}
        """.utf8))
        config.clamp()

        #expect(config.shotAnnotationStyles.highlight.width == 5)
        #expect(config.shotAnnotationStyles.pen.width == 9999)
    }
}
