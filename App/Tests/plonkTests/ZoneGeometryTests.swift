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
}
