import Foundation
import Testing
@testable import plonk

struct ShotSelectionSizeTests {
    @Test func largePixelDimensionsUseUngroupedIntegers() {
        #expect(String(localized: .shotSelectionSize(1234, 4567)) == "1234 × 4567 px")
    }
}
