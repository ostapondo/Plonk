import AppKit
import SwiftUI
import Testing
@testable import plonk

@MainActor
struct AnnotationPaletteTests {
    @Test(arguments: AnnotationPalette.Layout.allCases)
    func colorsKeepTheirOrderInEitherLayout(_ layout: AnnotationPalette.Layout) {
        let rows = layout.rows.map(Array.init)
        let first: [AnnotationColor] = [.red, .orange, .yellow, .green]
        let second: [AnnotationColor] = [.blue, .purple, .black, .white]
        #expect(rows == (layout == .singleRow ? [first + second] : [first, second]))
    }

    @Test(arguments: [AnnotationColor.red, .black, .white])
    func selectedSwatchUsesIdenticalDrawingInBothLayouts(_ color: AnnotationColor) throws {
        let single = try swatch(color, layout: .singleRow)
        let double = try swatch(color, layout: .doubleRow)
        #expect(single == double)
    }

    @Test(arguments: [AnnotationColor.red, .black, .white])
    func selectedSwatchHasAVisibleRing(_ color: AnnotationColor) throws {
        let selected = try swatch(color, selected: color, layout: .singleRow)
        let ordinary = try swatch(color, selected: color == .red ? .blue : .red, layout: .singleRow)
        #expect(selected != ordinary)
    }

    private func swatch(_ color: AnnotationColor, selected: AnnotationColor? = nil,
                        layout: AnnotationPalette.Layout) throws -> [NSColor] {
        let view = AnnotationPalette(selection: .constant(selected ?? color), layout: layout)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        let image = try #require(renderer.cgImage)
        let bitmap = NSBitmapImageRep(cgImage: image)
        #expect(bitmap.pixelsWide == Int(layout.size.width))
        #expect(bitmap.pixelsHigh == Int(layout.size.height))
        let row = color.index / layout.rawValue
        let column = color.index % layout.rawValue
        let origin = CGPoint(x: column * 22, y: row * 20)
        return try (0..<17).map { offset in
            try #require(bitmap.colorAt(x: Int(origin.x) + offset, y: Int(origin.y) + 8))
        }
    }
}
