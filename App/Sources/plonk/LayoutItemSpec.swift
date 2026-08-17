import Foundation

// One window in a /layout request: an app, optionally a particular window
// of it, and the fraction of a screen it should cover.

struct LayoutItemSpec: Codable {
    var app: String
    var title: String?
    var screen: Int?
    var x: Double
    var y: Double
    var w: Double
    var h: Double

    init?(dict: [String: Any]) {
        guard let app = dict["app"] as? String,
              let frac = FracRect.parse(dict["frame"]) else { return nil }
        self.app = app
        self.title = dict["title"] as? String
        self.screen = (dict["screen"] as? NSNumber)?.intValue
        self.x = frac.x; self.y = frac.y; self.w = frac.w; self.h = frac.h
    }

    init(app: String, title: String? = nil, screen: Int? = nil, x: Double, y: Double, w: Double, h: Double) {
        self.app = app; self.title = title; self.screen = screen
        self.x = x; self.y = y; self.w = w; self.h = h
    }
}
