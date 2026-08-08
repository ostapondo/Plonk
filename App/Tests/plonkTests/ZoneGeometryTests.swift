import Testing
import Foundation
@testable import plonk

private func assertZone(_ zone: ZoneRect, _ x: Double, _ y: Double, _ w: Double, _ h: Double,
                        sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(abs(zone.x - x) < 0.001, "x", sourceLocation: sourceLocation)
    #expect(abs(zone.y - y) < 0.001, "y", sourceLocation: sourceLocation)
    #expect(abs(zone.w - w) < 0.001, "w", sourceLocation: sourceLocation)
    #expect(abs(zone.h - h) < 0.001, "h", sourceLocation: sourceLocation)
}

struct ZoneGeometryTests {

    // MARK: - snap

    @Test func snapRoundsToGrid() {
        let snapped = ZoneGeometry.snap(ZoneRect(0.213, 0.478, 0.331, 0.512))
        assertZone(snapped, 0.2, 0.5, 0.35, 0.5)
    }

    @Test func snapEnforcesMinimumSize() {
        let snapped = ZoneGeometry.snap(ZoneRect(0.5, 0.5, 0.01, 0.01))
        #expect(snapped.w >= ZoneGeometry.minSide)
        #expect(snapped.h >= ZoneGeometry.minSide)
    }

    @Test func snapClampsInsideBounds() {
        let snapped = ZoneGeometry.snap(ZoneRect(0.97, 0.97, 0.2, 0.2))
        #expect(snapped.x + snapped.w <= 1.0001)
        #expect(snapped.y + snapped.h <= 1.0001)
    }

    // MARK: - overlaps

    @Test func touchingZonesDoNotOverlap() {
        let zones = [ZoneRect(0, 0, 0.5, 1), ZoneRect(0.5, 0, 0.5, 1)]
        #expect(!ZoneGeometry.overlaps(zones, at: [0, 1]))
    }

    @Test func intersectingZonesOverlap() {
        let zones = [ZoneRect(0, 0, 0.5, 1), ZoneRect(0.45, 0, 0.5, 1)]
        #expect(ZoneGeometry.overlaps(zones, at: [1]))
    }

    // MARK: - split

    @Test func verticalSplitSnapsAndPreservesArea() throws {
        let result = try #require(ZoneGeometry.split([ZoneRect(0, 0, 1, 1)], at: 0, fraction: 0.52, vertical: true))
        #expect(result.count == 2)
        assertZone(result[0], 0, 0, 0.5, 1)
        assertZone(result[1], 0.5, 0, 0.5, 1)
    }

    @Test func horizontalSplit() throws {
        let result = try #require(ZoneGeometry.split([ZoneRect(0, 0, 1, 1)], at: 0, fraction: 0.3, vertical: false))
        assertZone(result[0], 0, 0, 1, 0.3)
        assertZone(result[1], 0, 0.3, 1, 0.7)
    }

    @Test func splitTooCloseToEdgeIsRejected() {
        #expect(ZoneGeometry.split([ZoneRect(0, 0, 1, 1)], at: 0, fraction: 0.04, vertical: true) == nil)
        #expect(ZoneGeometry.split([ZoneRect(0, 0, 1, 1)], at: 0, fraction: 0.97, vertical: false) == nil)
    }

    @Test func splitInvalidIndexIsRejected() {
        #expect(ZoneGeometry.split([], at: 0, fraction: 0.5, vertical: true) == nil)
    }

    // MARK: - removeAndHeal

    @Test func singleNeighborAbsorbsDeletedZone() {
        let halves = [ZoneRect(0, 0, 0.5, 1), ZoneRect(0.5, 0, 0.5, 1)]
        let healed = ZoneGeometry.removeAndHeal(halves, at: 0)
        #expect(healed.count == 1)
        assertZone(healed[0], 0, 0, 1, 1)
    }

    @Test func rightNeighborExpandsLeft() {
        let quarters = [
            ZoneRect(0, 0, 0.5, 0.5), ZoneRect(0.5, 0, 0.5, 0.5),
            ZoneRect(0, 0.5, 0.5, 0.5), ZoneRect(0.5, 0.5, 0.5, 0.5),
        ]
        let healed = ZoneGeometry.removeAndHeal(quarters, at: 0)
        #expect(healed.count == 3)
        assertZone(healed[0], 0, 0, 1, 0.5)
    }

    @Test func columnOfNeighborsAbsorbsTogether() {
        let zones = [ZoneRect(0, 0, 0.5, 0.4), ZoneRect(0, 0.4, 0.5, 0.6), ZoneRect(0.5, 0, 0.5, 1)]
        let healed = ZoneGeometry.removeAndHeal(zones, at: 2)
        #expect(healed.count == 2)
        assertZone(healed[0], 0, 0, 1, 0.4)
        assertZone(healed[1], 0, 0.4, 1, 0.6)
    }

    @Test func noCleanFillLeavesGap() {
        let zones = [ZoneRect(0, 0, 0.3, 1), ZoneRect(0.3, 0, 0.3, 1), ZoneRect(0.6, 0, 0.4, 0.5)]
        let healed = ZoneGeometry.removeAndHeal(zones, at: 2)
        #expect(healed.count == 2)
        assertZone(healed[0], 0, 0, 0.3, 1)
        assertZone(healed[1], 0.3, 0, 0.3, 1)
    }

    @Test func healedResultNeverOverlaps() throws {
        var zones = [ZoneRect(0, 0, 1, 1)]
        zones = try #require(ZoneGeometry.split(zones, at: 0, fraction: 0.5, vertical: true))
        zones = try #require(ZoneGeometry.split(zones, at: 0, fraction: 0.5, vertical: false))
        zones = try #require(ZoneGeometry.split(zones, at: 1, fraction: 0.3, vertical: false))
        for index in zones.indices {
            let healed = ZoneGeometry.removeAndHeal(zones, at: index)
            #expect(!ZoneGeometry.overlaps(healed, at: Array(healed.indices)),
                    "healing index \(index) produced an overlap")
        }
    }
}

struct BuiltinZoneSetsTests {

    @Test func allSetsStayInBoundsAndDoNotOverlap() {
        for (name, zones) in BuiltinZoneSets.all {
            #expect(!zones.isEmpty, Comment(rawValue: name))
            for z in zones {
                #expect(z.x >= 0 && z.y >= 0, Comment(rawValue: name))
                #expect(z.x + z.w <= 1.0001 && z.y + z.h <= 1.0001, Comment(rawValue: name))
            }
            #expect(!ZoneGeometry.overlaps(zones, at: Array(zones.indices)), Comment(rawValue: name))
        }
    }

    @Test func defaultSetExists() {
        #expect(BuiltinZoneSets.all[BuiltinZoneSets.defaultName] != nil)
    }

    @Test func gridTilesTheWholeScreen() {
        let zones = BuiltinZoneSets.grid(columns: 3, rows: 2)
        #expect(zones.count == 6)
        let area = zones.reduce(0.0) { $0 + $1.w * $1.h }
        #expect(abs(area - 1.0) < 0.001)
        #expect(!ZoneGeometry.overlaps(zones, at: Array(zones.indices)))
    }

    @Test func gridClampsDegenerateInput() {
        #expect(BuiltinZoneSets.grid(columns: 0, rows: -1).count == 1)
    }

    // MARK: - spanning

    @Test func spanningTwoColumnsGivesTheirCombinedWidth() {
        let thirds = BuiltinZoneSets.all["Thirds"]!
        let span = ZoneGeometry.union(thirds[0], thirds[1])
        assertZone(ZoneRect(span.x, span.y, span.w, span.h), 0, 0, 2.0 / 3, 1)
    }

    @Test func spanningIsOrderIndependent() {
        let quarters = BuiltinZoneSets.all["Quarters"]!
        let forward = ZoneGeometry.union(quarters[0], quarters[3])
        let backward = ZoneGeometry.union(quarters[3], quarters[0])
        #expect(forward.x == backward.x && forward.y == backward.y)
        #expect(forward.w == backward.w && forward.h == backward.h)
    }

    /// Two diagonal quarters bound the whole screen, so the pair between them
    /// comes along — the rect is what gets dropped into either way.
    @Test func spanningDiagonallyTakesTheCornersWithIt() {
        let quarters = BuiltinZoneSets.all["Quarters"]!
        let span = ZoneGeometry.union(quarters[0], quarters[3])
        assertZone(ZoneRect(span.x, span.y, span.w, span.h), 0, 0, 1, 1)
        #expect(ZoneGeometry.covered(quarters, by: span) == [0, 1, 2, 3])
    }

    @Test func coveredReportsOnlyTheZonesInsideTheSpan() {
        let thirds = BuiltinZoneSets.all["Thirds"]!
        let span = ZoneGeometry.union(thirds[0], thirds[1])
        #expect(ZoneGeometry.covered(thirds, by: span) == [0, 1])
    }

    // MARK: - editing without a mouse

    @Test func anArrowMovesAZoneByOneGridStep() {
        let zones = [ZoneRect(0, 0, 0.5, 1)]
        let moved = ZoneGeometry.adjust(zones, at: 0, dx: ZoneGeometry.grid, dy: 0, resizing: false)
        #expect(moved != nil)
        assertZone(moved![0], 0.05, 0, 0.5, 1)
    }

    /// The right column of a pair of halves has nowhere to go: sliding it right
    /// would take it past the screen edge.
    @Test func aZoneWithNoRoomStaysPut() {
        let zones = [ZoneRect(0, 0, 0.5, 1), ZoneRect(0.5, 0, 0.5, 1)]
        #expect(ZoneGeometry.adjust(zones, at: 1, dx: ZoneGeometry.grid, dy: 0, resizing: false) == nil)
    }

    @Test func shiftArrowResizesInstead() {
        let zones = [ZoneRect(0, 0, 0.5, 1)]
        let grown = ZoneGeometry.adjust(zones, at: 0, dx: ZoneGeometry.grid, dy: 0, resizing: true)
        #expect(grown != nil)
        assertZone(grown![0], 0, 0, 0.55, 1)
    }

    @Test func anEditThatWouldOverlapIsRefused() {
        let zones = [ZoneRect(0, 0, 0.5, 1), ZoneRect(0.5, 0, 0.5, 1)]
        #expect(ZoneGeometry.adjust(zones, at: 0, dx: ZoneGeometry.grid, dy: 0, resizing: true) == nil)
    }

    @Test func aZoneCannotBePushedOffTheScreen() {
        let zones = [ZoneRect(0, 0, 0.5, 1)]
        #expect(ZoneGeometry.adjust(zones, at: 0, dx: -ZoneGeometry.grid, dy: 0, resizing: false) == nil)
    }

    @Test func aZoneCannotBeShrunkBelowTheMinimum() {
        let zones = [ZoneRect(0, 0, 0.1, 1)]
        #expect(ZoneGeometry.adjust(zones, at: 0, dx: -ZoneGeometry.grid, dy: 0, resizing: true) == nil)
    }

    @Test func anIndexOutsideTheSetAdjustsNothing() {
        #expect(ZoneGeometry.adjust([ZoneRect(0, 0, 1, 1)], at: 7, dx: 0.05, dy: 0, resizing: false) == nil)
    }

    // MARK: - hovering a shared edge

    private let thirds = BuiltinZoneSets.all["Thirds"]!

    @Test func nearTheLineBetweenTwoColumnsPicksTheOtherOne() {
        // Just inside the first third, a hair from the boundary at x = 1/3.
        let neighbour = ZoneGeometry.neighbour(thirds, of: 0, atX: 0.33, y: 0.5,
                                               toleranceX: 0.01, toleranceY: 0.01)
        #expect(neighbour == 1)
    }

    @Test func wellInsideAZonePicksNothing() {
        #expect(ZoneGeometry.neighbour(thirds, of: 0, atX: 0.1, y: 0.5,
                                       toleranceX: 0.01, toleranceY: 0.01) == nil)
    }

    @Test func zeroToleranceSwitchesItOff() {
        #expect(ZoneGeometry.neighbour(thirds, of: 0, atX: 0.333, y: 0.5,
                                       toleranceX: 0, toleranceY: 0) == nil)
    }

    /// Between three columns the middle one is hovered and both its neighbours
    /// are in range; the nearer edge has to win rather than the lower index.
    @Test func theNearerNeighbourWins() {
        let near = ZoneGeometry.neighbour(thirds, of: 1, atX: 0.66, y: 0.5,
                                          toleranceX: 0.05, toleranceY: 0.05)
        #expect(near == 2)
    }

    @Test func anIndexOutsideTheSetIsRefused() {
        #expect(ZoneGeometry.neighbour(thirds, of: 9, atX: 0.5, y: 0.5,
                                       toleranceX: 0.1, toleranceY: 0.1) == nil)
    }

    @Test func spanningAZoneWithItselfChangesNothing() {
        let thirds = BuiltinZoneSets.all["Thirds"]!
        let span = ZoneGeometry.union(thirds[1], thirds[1])
        assertZone(ZoneRect(span.x, span.y, span.w, span.h),
                   thirds[1].x, thirds[1].y, thirds[1].w, thirds[1].h)
    }
}
