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

    @Test func badgeStaysOffTheTopEdgeOfASelectionAtTheTopOfTheScreen() {
        let selection = CGRect(x: 55, y: 30, width: 260, height: 110)
        let placement = QuickShotLayout.place(dimensions: dimensions, toolbar: toolbar,
                                              selection: selection, area: area)
        #expect(!placement.dimensions.intersects(selection))
        #expect(!placement.dimensions.intersects(placement.toolbar))
        #expect(area.contains(placement.dimensions))
    }

    @Test func badgeClearsTheCornerHandlesWhenNothingOutsideHasRoom() {
        let selection = area.insetBy(dx: -20, dy: -25)
        let placement = QuickShotLayout.place(dimensions: dimensions, toolbar: toolbar,
                                              selection: selection, area: area)
        let topBand = CGRect(x: selection.minX, y: area.minY, width: selection.width,
                             height: ShotSelection.handleLength)
        #expect(!placement.dimensions.intersects(topBand))
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

    @Test func stylePanelStaysOffTheSelectionWhenNeitherAboveNorBelowFits() {
        let selection = CGRect(x: area.minX + 40, y: area.minY + 200, width: 300, height: 200)
        let bar = CGRect(x: selection.minX, y: selection.maxY + 16, width: 300, height: toolbar.height)
        let anchor = CGRect(x: bar.minX, y: bar.minY, width: 34, height: bar.height)
        let placement = stylePanel(anchor: anchor, toolbar: bar, avoiding: [selection])
        #expect(!placement.panel.intersects(selection))
        #expect(area.contains(placement.panel))
        #expect(placement.beside)
        #expect(placement.panel.minX > bar.maxX)
    }

    @Test func stylePanelGoesAboveAToolbarThatSitsOverTheSelection() {
        let selection = CGRect(x: area.minX + 40, y: area.minY + 150, width: 300, height: 300)
        let bar = CGRect(x: selection.minX, y: selection.minY - 16 - toolbar.height,
                         width: toolbar.width, height: toolbar.height)
        let anchor = CGRect(x: bar.minX, y: bar.minY, width: 34, height: bar.height)
        let placement = stylePanel(anchor: anchor, toolbar: bar, avoiding: [selection])
        #expect(placement.above)
        #expect(!placement.panel.intersects(selection))
    }

    @Test func stylePanelPicksTheLeastCoveringSpotWhenNothingIsClear() {
        // A toolbar wider than the screen leaves no room beside it, nothing fits under it,
        // and the selection reaches to just over it: every spot on screen touches the selection.
        let bar = CGRect(x: area.minX, y: area.maxY - 60, width: area.width, height: toolbar.height)
        let selection = CGRect(x: area.minX, y: area.minY + 40, width: area.width, height: bar.minY - 20 - area.minY - 40)
        let anchor = CGRect(x: bar.minX, y: bar.minY, width: 34, height: bar.height)
        let placement = stylePanel(anchor: anchor, toolbar: bar, avoiding: [selection])
        #expect(area.contains(placement.panel))
        #expect(placement.above)
        #expect(selection.intersection(placement.panel).height < placement.panel.height)
    }

    @Test func fixedLayoutLeavesRoomForTheStylePanelUnderTheImage() {
        let area = CGRect(x: 0, y: 0, width: 800, height: 900)
        let reserve = QuickShotStyleControls.size.height
        let layout = QuickShotLayout.fixed(image: CGSize(width: 400, height: 1200), toolbar: toolbar,
                                           reserve: reserve, area: area)
        let anchor = CGRect(x: layout.toolbar.minX, y: layout.toolbar.minY, width: 34, height: toolbar.height)
        let placement = stylePanel(anchor: anchor, toolbar: layout.toolbar, avoiding: [layout.image], in: area)
        #expect(!placement.panel.intersects(layout.image))
        #expect(placement.panel.minY > layout.toolbar.maxY)
        #expect(area.contains(placement.panel))
    }

    private func stylePanel(anchor: CGRect, toolbar: CGRect, avoiding obstacles: [CGRect] = [],
                            in area: CGRect? = nil) -> QuickShotLayout.StylePlacement {
        QuickShotLayout.stylePanel(size: QuickShotStyleControls.size,
                                  help: CGSize(width: QuickShotStyleControls.helpWidth,
                                               height: QuickShotStyleControls.helpHeight),
                                  anchor: anchor, toolbar: toolbar, avoiding: obstacles, area: area ?? self.area)
    }
}
