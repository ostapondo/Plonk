import Foundation

// A saved layout that knows how to bring its apps back: every item carries the
// identity of the app it belongs to, so a workspace can be launched from a clean
// desktop rather than only rearranging what is open.
//
// Frames are fractions of a screen's visible area; see WindowManager.swift.

struct WorkspaceItem: Codable {
    var app: String
    var bundleID: String?
    /// Path to the .app, so the UI can draw an icon while the app is not running.
    var bundlePath: String?
    var title: String?
    /// Which window of that app, in the order the app reports them. Only set
    /// when one app owns several windows in the workspace.
    var windowIndex: Int?
    var screen: Int?
    /// Screen indices shift when displays are unplugged; the UUID is the stable key.
    var screenUUID: String?
    var x: Double
    var y: Double
    var w: Double
    var h: Double
    var minimized: Bool?
    /// Files, folders or URLs opened with the app when it has to be launched.
    var urls: [String]?
    var args: [String]?

    init(app: String, bundleID: String? = nil, bundlePath: String? = nil,
         title: String? = nil, windowIndex: Int? = nil,
         screen: Int? = nil, screenUUID: String? = nil,
         x: Double, y: Double, w: Double, h: Double,
         minimized: Bool? = nil, urls: [String]? = nil, args: [String]? = nil) {
        self.app = app
        self.bundleID = bundleID
        self.bundlePath = bundlePath
        self.title = title
        self.windowIndex = windowIndex
        self.screen = screen
        self.screenUUID = screenUUID
        self.x = x; self.y = y; self.w = w; self.h = h
        self.minimized = minimized
        self.urls = urls
        self.args = args
    }

    init?(dict: [String: Any]) {
        guard let app = dict["app"] as? String,
              let frac = FracRect.parse(dict["frame"]) else { return nil }
        let (x, y, w, h) = (frac.x, frac.y, frac.w, frac.h)
        self.app = app
        bundleID = dict["bundle_id"] as? String
        bundlePath = dict["bundle_path"] as? String
        title = dict["title"] as? String
        windowIndex = (dict["window_index"] as? NSNumber)?.intValue
        screen = (dict["screen"] as? NSNumber)?.intValue
        screenUUID = dict["screen_uuid"] as? String
        self.x = x; self.y = y; self.w = w; self.h = h
        minimized = dict["minimized"] as? Bool
        urls = (dict["urls"] as? [String])?.filter { !$0.isEmpty }
        args = (dict["args"] as? [String])?.filter { !$0.isEmpty }
    }

    /// Built from one entry of `WindowManager.listWindows()`. Minimized windows
    /// yield nil: their frame is wherever they were before going down, so there
    /// is no position worth saving.
    init?(window entry: [String: Any], screenUUID: String? = nil) {
        guard entry["minimized"] as? Bool != true,
              let app = entry["app"] as? String,
              let screen = entry["screen"] as? Int,
              let fraction = entry["fraction"] as? [String: Double],
              let x = fraction["x"], let y = fraction["y"],
              let w = fraction["w"], let h = fraction["h"] else { return nil }
        self.init(
            app: app,
            bundleID: entry["bundle_id"] as? String,
            bundlePath: entry["bundle_path"] as? String,
            windowIndex: entry["window_index"] as? Int,
            screen: screen,
            screenUUID: screenUUID,
            x: x, y: y, w: w, h: h
        )
    }

    init?(window snapshot: WindowSnapshot, screenUUID: String? = nil) {
        guard !snapshot.minimized, let fraction = snapshot.fraction else { return nil }
        self.init(
            app: snapshot.app,
            bundleID: snapshot.bundleID,
            bundlePath: snapshot.bundlePath,
            title: snapshot.title.isEmpty ? nil : snapshot.title,
            windowIndex: snapshot.windowIndex,
            screen: snapshot.screen,
            screenUUID: screenUUID,
            x: fraction.x, y: fraction.y, w: fraction.w, h: fraction.h
        )
    }

    var asDict: [String: Any] {
        var result: [String: Any] = [
            "app": app,
            "frame": ["x": x, "y": y, "w": w, "h": h],
        ]
        if let bundleID { result["bundle_id"] = bundleID }
        if let bundlePath { result["bundle_path"] = bundlePath }
        if let title { result["title"] = title }
        if let windowIndex { result["window_index"] = windowIndex }
        if let screen { result["screen"] = screen }
        if let screenUUID { result["screen_uuid"] = screenUUID }
        if let minimized { result["minimized"] = minimized }
        if let urls, !urls.isEmpty { result["urls"] = urls }
        if let args, !args.isEmpty { result["args"] = args }
        return result
    }

    /// Items of the same app are launched once, together.
    var launchKey: String { bundleID ?? app.lowercased() }
}

struct Workspace: Codable {
    var items: [WorkspaceItem] = []
    /// When on, an app that is already running is moved rather than left alone.
    var moveExisting = true

    init(items: [WorkspaceItem], moveExisting: Bool = true) {
        self.items = items
        self.moveExisting = moveExisting
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = try c.decodeIfPresent([WorkspaceItem].self, forKey: .items) ?? []
        moveExisting = try c.decodeIfPresent(Bool.self, forKey: .moveExisting) ?? true
    }

    var apps: [String] {
        var seen = Set<String>()
        return items.compactMap { seen.insert($0.launchKey).inserted ? $0.app : nil }
    }
}

/// One app to bring up, with every window of the workspace that belongs to it.
struct LaunchGroup {
    let key: String
    let app: String
    let bundleID: String?
    let bundlePath: String?
    let urls: [String]
    let args: [String]
    /// Positions in the workspace's item list, so statuses can be reported per item.
    let itemIndices: [Int]
}

enum WorkspacePlan {
    /// Groups items by app, in the order they were saved. An app is launched
    /// once, so the URLs and arguments of all its windows are merged.
    static func groups(for workspace: Workspace) -> [LaunchGroup] {
        var order: [String] = []
        var byKey: [String: [Int]] = [:]
        for (index, item) in workspace.items.enumerated() {
            if byKey[item.launchKey] == nil { order.append(item.launchKey) }
            byKey[item.launchKey, default: []].append(index)
        }
        return order.compactMap { key in
            guard let indices = byKey[key], let first = indices.first else { return nil }
            let items = indices.map { workspace.items[$0] }
            return LaunchGroup(
                key: key,
                app: workspace.items[first].app,
                bundleID: items.compactMap(\.bundleID).first,
                bundlePath: items.compactMap(\.bundlePath).first,
                urls: items.flatMap { $0.urls ?? [] },
                args: items.flatMap { $0.args ?? [] },
                itemIndices: indices
            )
        }
    }
}
