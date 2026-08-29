import Foundation

/// One window as core code sees it. The untyped dictionary belongs only at
/// the HTTP boundary; workspace snapshots consume this value directly.
struct WindowSnapshot {
    let app: String
    let pid: pid_t
    let title: String
    let minimized: Bool
    let screen: Int
    let windowIndex: Int
    let frame: CGRect
    let fraction: FracRect?
    let bundleID: String?
    let bundlePath: String?

    var asDict: [String: Any] {
        var result: [String: Any] = [
            "app": app,
            "pid": pid,
            "title": title,
            "minimized": minimized,
            "screen": screen,
            "window_index": windowIndex,
            "frame": ["x": Double(frame.minX), "y": Double(frame.minY),
                      "w": Double(frame.width), "h": Double(frame.height)],
        ]
        if let fraction {
            result["fraction"] = ["x": fraction.x, "y": fraction.y,
                                  "w": fraction.w, "h": fraction.h]
        }
        if let bundleID { result["bundle_id"] = bundleID }
        if let bundlePath { result["bundle_path"] = bundlePath }
        return result
    }
}
