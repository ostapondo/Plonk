import Foundation
import ScreenCaptureKit

extension SCShareableContent {
    func filterExcludingPlonk(on display: SCDisplay) -> SCContentFilter {
        SCContentFilter(display: display, excludingApplications: applications.filter {
            $0.processID == ProcessInfo.processInfo.processIdentifier
        }, exceptingWindows: [])
    }
}
