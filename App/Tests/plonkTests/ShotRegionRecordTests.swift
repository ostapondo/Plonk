import CoreGraphics
import Testing
@testable import plonk

struct ShotRegionRecordTests {
    private let display = ShotRegionRecord.Display(
        uuid: "display-a", pixels: CGSize(width: 1600, height: 1000),
        points: CGSize(width: 800, height: 500), scale: 2
    )

    @Test func restoresTheExactDisplayLocalPixels() {
        let rect = CGRect(x: 900, y: 600, width: 700, height: 400)
        let record = ShotRegionRecord(display: display, rect: rect)

        #expect(record.rect(on: display) == rect)
        #expect(record.rect(on: nil) == nil)
    }

    @Test func rejectsAnotherDisplayOrChangedGeometry() {
        let record = ShotRegionRecord(display: display, rect: CGRect(x: 10, y: 20, width: 300, height: 400))
        let otherDisplays = [
            ShotRegionRecord.Display(uuid: "display-b", pixels: display.pixels, points: display.points, scale: 2),
            ShotRegionRecord.Display(uuid: display.uuid, pixels: CGSize(width: 1200, height: 800),
                                     points: display.points, scale: 2),
            ShotRegionRecord.Display(uuid: display.uuid, pixels: display.pixels,
                                     points: CGSize(width: 1000, height: 600), scale: 2),
            ShotRegionRecord.Display(uuid: display.uuid, pixels: display.pixels, points: display.points, scale: 1)
        ]

        for other in otherDisplays {
            #expect(record.rect(on: other) == nil)
        }
    }

    @Test(arguments: [
        CGRect(x: -1, y: 20, width: 300, height: 400),
        CGRect(x: 900, y: 600, width: 701, height: 400),
        CGRect(x: 900, y: 600, width: 700, height: 401),
        CGRect(x: 10, y: 20, width: 0, height: 30)
    ])
    func rejectsARegionThatDoesNotFit(_ rect: CGRect) {
        #expect(ShotRegionRecord(display: display, rect: rect).rect(on: display) == nil)
    }
}
