import AppKit

// /ruler/measure — the ruler with no hands on it.
//
// Apart from Router for the reason ShotRoutes is: the interactive mode waits on
// a person, so the answer arrives long after the request handler has returned.
//
// Points arrive as fractions of a screen's visible area, origin top-left, the
// same space every frame in this API uses, so a measurement can be fed straight
// back into apply_layout. What comes back carries the absolute points and the
// display's own pixels as well, because those are what a measurement is for.

final class RulerRoutes {
    private let windows: WindowManager
    private let store: ConfigStore
    private let ruler: ScreenRuler

    init(windows: WindowManager, store: ConfigStore, ruler: ScreenRuler = .shared) {
        self.windows = windows
        self.store = store
        self.ruler = ruler
    }

    func measureRoute(_ body: [String: Any], respond: @escaping (HTTPResponse) -> Void) {
        if (body["interactive"] as? Bool) == true {
            ruler.begin { [weak self] result in
                respond(self?.reply(result) ?? .failed("shutting down"))
            }
            return
        }

        let index = (body["screen"] as? NSNumber)?.intValue ?? 0
        guard let screen = windows.screens().first(where: { $0.index == index }) else {
            respond(.notFound("no screen \(index); get_state lists them"))
            return
        }

        if let from = Self.point(body["from"], in: screen.visible),
           let to = Self.point(body["to"], in: screen.visible) {
            respond(reply(ruler.measureLine(from: from, to: to)))
            return
        }
        guard let point = Self.point(body["point"], in: screen.visible) else {
            respond(.badRequest("body must be {\"point\": {\"x\", \"y\"}} as fractions 0..1 of the "
                                + "screen's visible area, or {\"from\", \"to\"} for a distance, or "
                                + "{\"interactive\": true} to hand the user the ruler"))
            return
        }
        ruler.measure(at: point) { [weak self] result in
            respond(self?.reply(result) ?? .failed("shutting down"))
        }
    }

    private func reply(_ result: Result<RulerMeasurement, ScreenRuler.Failure>) -> HTTPResponse {
        switch result {
        case .success(let measurement):
            var payload = measurement.asDict(visible: ruler.visibleArea(ofScreen: measurement.screen))
            payload["ok"] = true
            payload["tolerance"] = store.config.rulerTolerance
            return .ok(payload)
        case .failure(let failure):
            // Nothing here is the caller's mistake: the permission is missing,
            // the user walked away, or the screen would not photograph.
            return HTTPResponse(status: 409, json: ["error": failure.localizedDescription])
        }
    }

    /// `{"x": 0.5, "y": 0.4}` against a screen's visible area, in AX points.
    /// Nil for anything that is not a pair of finite fractions inside it.
    static func point(_ value: Any?, in visible: CGRect) -> CGPoint? {
        guard let dict = value as? [String: Any],
              let x = (dict["x"] as? NSNumber)?.doubleValue,
              let y = (dict["y"] as? NSNumber)?.doubleValue,
              x.isFinite, y.isFinite,
              x >= 0, y >= 0, x <= 1.0001, y <= 1.0001 else { return nil }
        return CGPoint(x: visible.minX + visible.width * CGFloat(x),
                       y: visible.minY + visible.height * CGFloat(y))
    }
}
