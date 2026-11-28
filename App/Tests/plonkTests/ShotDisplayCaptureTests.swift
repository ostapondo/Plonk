import AppKit
import ScreenCaptureKit
import Testing
@testable import plonk

struct ShotDisplayCaptureTests {
    @Test func onlyNativeWindowPickerNeedsPlonkWindowsHidden() {
        #expect(!CaptureMode.region.quickShotNeedsHiddenWindows)
        #expect(CaptureMode.window.quickShotNeedsHiddenWindows)
        #expect(!CaptureMode.screen.quickShotNeedsHiddenWindows)
    }

    @Test(arguments: [1, 2])
    func requestsBackingPixelsWithoutThePointer(_ scale: Int) {
        let configuration = ShotDisplayCapture.configuration(
            displaySize: CGSize(width: 1440, height: 900), scale: CGFloat(scale)
        )

        #expect(configuration.width == 1440 * scale)
        #expect(configuration.height == 900 * scale)
        #expect(!configuration.showsCursor)
    }

    @Test func onlyGeneratedFramesCanSupplyTheInitialImage() {
        #expect(FirstScreenFrame.hasImage(.started))
        #expect(FirstScreenFrame.hasImage(.complete))
        #expect(!FirstScreenFrame.hasImage(.idle))
        #expect(!FirstScreenFrame.hasImage(.blank))
        #expect(!FirstScreenFrame.hasImage(.suspended))
        #expect(!FirstScreenFrame.hasImage(.stopped))
        #expect(!FirstScreenFrame.hasImage(nil))
    }
}
