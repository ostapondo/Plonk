import Foundation
import Testing
@testable import plonk

struct WindowSnapshotTests {
    @Test func typedSnapshotKeepsWorkspaceIdentityAndSerializesDoubles() throws {
        let snapshot = WindowSnapshot(
            app: "Code", pid: 42, title: "plonk", minimized: false,
            screen: 1, windowIndex: 2,
            frame: CGRect(x: 10, y: 20, width: 800, height: 600),
            fraction: FracRect(0.1, 0.2, 0.5, 0.6),
            bundleID: "com.microsoft.VSCode", bundlePath: "/Applications/Code.app"
        )
        let item = try #require(WorkspaceItem(window: snapshot, screenUUID: "display"))
        #expect(item.title == "plonk")
        #expect(item.windowIndex == 2)
        #expect(item.screenUUID == "display")
        let frame = try #require(snapshot.asDict["frame"] as? [String: Double])
        #expect(frame["w"] == 800)
    }

    @Test func minimizedSnapshotIsNotAWorkspaceItem() {
        let snapshot = WindowSnapshot(
            app: "Code", pid: 42, title: "", minimized: true,
            screen: 0, windowIndex: 0, frame: .zero,
            fraction: nil, bundleID: nil, bundlePath: nil
        )
        #expect(WorkspaceItem(window: snapshot) == nil)
    }
}
