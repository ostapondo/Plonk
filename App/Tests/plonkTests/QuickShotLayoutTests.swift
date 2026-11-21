import CoreGraphics
import Testing
@testable import plonk

@MainActor
struct QuickShotLayoutTests {
    private let area = CGRect(x: 14, y: 24, width: 700, height: 500)
    private let dimensions = CGSize(width: 107, height: 29)
    private let toolbar = CGSize(width: 460, height: 42)

    @Test func controlsFollowTheSelection() {
        let selection = CGRect(x: 55, y: 85, width: 260, height: 110)
        let placement = QuickShotLayout.place(dimensions: dimensions, toolbar: toolbar,
                                              selection: selection, area: area)
        #expect(placement.dimensions.minX == selection.minX)
        #expect(placement.dimensions.maxY == selection.minY - 10)
        #expect(placement.toolbar.minX == selection.minX)
        #expect(placement.toolbar.minY == selection.maxY + 16)
    }

    @Test func toolbarMovesAboveTheSelectionAtTheBottomOfTheScreen() {
        let selection = CGRect(x: 480, y: 410, width: 240, height: 120)
        let placement = QuickShotLayout.place(dimensions: dimensions, toolbar: toolbar,
                                              selection: selection, area: area)
        #expect(placement.toolbar.maxY < placement.dimensions.minY)
        #expect(area.contains(placement.toolbar))
        #expect(area.contains(placement.dimensions))
    }

    @Test func bothControlsStayVisibleAndSeparateOnAVeryShortSelectionInACorner() {
        let selection = CGRect(x: 693, y: 0, width: 40, height: 23)
        let placement = QuickShotLayout.place(dimensions: dimensions, toolbar: toolbar,
                                              selection: selection, area: area)
        #expect(area.contains(placement.dimensions))
        #expect(area.contains(placement.toolbar))
        #expect(!placement.dimensions.intersects(placement.toolbar))
    }

    @Test func toolbarRemainsReachableWhenSelectionFillsTheDisplay() {
        let placement = QuickShotLayout.place(dimensions: dimensions, toolbar: toolbar,
                                              selection: area.insetBy(dx: -20, dy: -25), area: area)
        #expect(area.contains(placement.dimensions))
        #expect(area.contains(placement.toolbar))
        #expect(!placement.dimensions.intersects(placement.toolbar))
    }

    @Test func narrowToolbarWrapsAllItemsInsideItsFrame() {
        let layout = QuickShotLayout.toolbar(dividers: [false, false, true, false, false, false], availableWidth: 98)
        #expect(layout.frames.count == 6)
        #expect(layout.size.width <= 98)
        #expect(Set(layout.frames.map(\.minY)).count > 1)
        let bounds = CGRect(origin: .zero, size: layout.size)
        #expect(layout.frames.allSatisfy { bounds.contains($0) })
    }

    @Test(arguments: [false, true])
    func stylePanelAndHelpStayVisibleAtEitherScreenEdge(_ trailing: Bool) {
        let bar = CGRect(x: trailing ? area.maxX - toolbar.width : area.minX,
                         y: area.minY + 70, width: toolbar.width, height: toolbar.height)
        let anchor = CGRect(x: trailing ? bar.maxX - 34 : bar.minX,
                            y: bar.minY, width: 34, height: bar.height)
        let placement = stylePanel(anchor: anchor, toolbar: bar)
        #expect(area.contains(placement.panel))
        #expect(area.contains(placement.help))
        #expect(placement.panel.minY > bar.maxY)
        #expect((anchor.minX...anchor.maxX).contains(placement.anchorX))
    }

    @Test func stylePanelFlipsAboveTheToolbarNearTheBottom() {
        let bar = CGRect(x: area.minX + 100, y: area.maxY - toolbar.height - 8,
                         width: toolbar.width, height: toolbar.height)
        let anchor = CGRect(x: bar.midX - 17, y: bar.minY, width: 34, height: bar.height)
        let placement = stylePanel(anchor: anchor, toolbar: bar)
        #expect(placement.above)
        #expect(placement.panel.maxY < bar.minY)
        #expect(placement.help.maxY < placement.panel.minY)
    }

    private func stylePanel(anchor: CGRect, toolbar: CGRect) -> QuickShotLayout.StylePlacement {
        QuickShotLayout.stylePanel(size: QuickShotStyleControls.size,
                                  help: CGSize(width: QuickShotStyleControls.helpWidth,
                                               height: QuickShotStyleControls.helpHeight),
                                  anchor: anchor, toolbar: toolbar, avoiding: nil, area: area)
    }
}
