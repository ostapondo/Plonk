import AppKit

// A ruler for the screen: what is that, how big is it, how far apart are those.
//
// macOS has no ruler. ⌘⇧4 shows the size of a drag while it is happening, which
// answers the second question and only while a crosshair is up. What it cannot
// do is find the edges of a thing for you, and that is most of the work: nobody
// wants to aim a drag at the exact corner of a button.
//
// So the screen is photographed once at the start and every measurement is
// taken against that still. Hovering finds the box under the pointer with
// EdgeDetector, dragging measures a straight line, a click copies whatever is
// showing, Escape ends it. Measuring against a frozen frame rather than the
// live screen is deliberate: it costs one capture instead of thirty a second,
// and a picture that stops moving is the one being measured.

final class ScreenRuler {
    static let shared = ScreenRuler()

    enum Failure: LocalizedError {
        case notPermitted
        case captureFailed
        case noScreen
        case cancelled

        var errorDescription: String? {
            switch self {
            case .notPermitted:
                return "Plonk does not have Screen Recording, so it cannot see the pixels it would "
                    + "measure. Grant it in System Settings › Privacy & Security › Screen Recording."
            case .captureFailed: return "the screen could not be photographed"
            case .noScreen: return "that point is not on any screen"
            case .cancelled: return "nothing was measured"
            }
        }

        /// Somebody pressing Escape is not news; the other three are.
        var isWorthSaying: Bool {
            if case .cancelled = self { return false }
            return true
        }
    }

    /// Set by AppDelegate and read at the moment the ruler opens, the way the
    /// zone overlay reads its own, so a colour or a tolerance changed in
    /// settings is live without anything having to push it in here.
    var appearance: (() -> (tint: NSColor, tolerance: Int))?
    private var tolerance = EdgeDetector.defaultTolerance
    private var tint: NSColor = .controlAccentColor
    /// Set by AppDelegate, so the HUD says what was copied.
    var announce: ((String) -> Void)?
    /// Set by AppDelegate: Plonk's own windows have to be out of the way before
    /// a capture, or the ruler measures its own overlay. The closure it is
    /// handed puts them back.
    var hideOwnWindows: (() -> () -> Void)?

    private var sheets: [RulerSheet] = []
    private var overlay: RulerOverlay?
    private var monitor: Any?
    /// Where a drag began, in CG points. Nil while hovering.
    private var anchor: CGPoint?
    private var current: RulerMeasurement?
    private var onFinish: ((Result<RulerMeasurement, Failure>) -> Void)?

    var isMeasuring: Bool { overlay != nil }

    // MARK: - Interactive

    /// Hands the user the ruler. `completion` reports the last measurement they
    /// took, or why there is none — an agent asking for an interactive measure
    /// waits on exactly that.
    func begin(completion: ((Result<RulerMeasurement, Failure>) -> Void)? = nil) {
        guard !isMeasuring else {
            completion?(.failure(.cancelled))
            return
        }
        // Preflight only reports; without the grant every capture comes back as
        // the desktop picture, which would measure confidently and wrongly.
        guard CGPreflightScreenCaptureAccess() else {
            completion?(.failure(.notPermitted))
            return
        }
        refreshAppearance()
        onFinish = completion
        capture { [weak self] sheets in
            guard let self else { return }
            guard !sheets.isEmpty else {
                finish(.failure(.captureFailed))
                return
            }
            self.sheets = sheets
            show()
        }
    }

    private func show() {
        let overlay = RulerOverlay(tint: tint)
        self.overlay = overlay
        overlay.show()
        // The overlay swallows what it is given, so nothing here reaches the
        // app underneath; Escape has to arrive as well, which needs the app in
        // front and one of its windows key.
        NSApp.activate(ignoringOtherApps: true)
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .leftMouseDragged, .leftMouseUp,
                       .rightMouseDown, .keyDown]
        ) { [weak self] event in
            self?.handle(event)
            return nil
        }
        announce?("Hover to measure, drag for a distance, click to copy, Escape to finish")
        update(at: NSEvent.mouseLocation)
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .keyDown:
            // 53 is Escape, 36 Return. Nothing else does anything: a stray
            // keystroke must not leave the overlay up with no way out.
            if event.keyCode == 53 { finish(current.map { .success($0) } ?? .failure(.cancelled)) }
            if event.keyCode == 36 { copyCurrent() }
        case .rightMouseDown:
            finish(current.map { .success($0) } ?? .failure(.cancelled))
        case .leftMouseDown:
            anchor = RulerSheet.toCG(NSEvent.mouseLocation)
        case .leftMouseDragged:
            update(at: NSEvent.mouseLocation)
        case .leftMouseUp:
            // A press that never moved is a click, and a click copies. Anything
            // longer is a line, which stays on screen to be read.
            let point = RulerSheet.toCG(NSEvent.mouseLocation)
            let dragged = anchor.map { hypot(point.x - $0.x, point.y - $0.y) > 3 } ?? false
            anchor = nil
            if !dragged {
                update(at: NSEvent.mouseLocation)
                copyCurrent()
            }
        default:
            update(at: NSEvent.mouseLocation)
        }
    }

    /// Whatever is under the pointer now: a line while one is being dragged,
    /// otherwise the box the pixels say is there.
    private func update(at pointer: NSPoint) {
        let point = RulerSheet.toCG(pointer)
        if let anchor {
            current = line(from: anchor, to: point)
        } else {
            current = bounds(at: point)
        }
        overlay?.update(measurement: current, pointer: pointer, anchor: anchor.map(RulerSheet.toScreen))
    }

    private func copyCurrent() {
        guard let current else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(current.clipboardText, forType: .string)
        announce?("Copied \(current.clipboardText)")
    }

    private func finish(_ result: Result<RulerMeasurement, Failure>) {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        overlay?.hide()
        overlay = nil
        sheets = []
        anchor = nil
        current = nil
        let completion = onFinish
        onFinish = nil
        completion?(result)
    }

    // MARK: - Measuring

    /// The box under one point, with no user involved: the agents' road in.
    func measure(at point: CGPoint, completion: @escaping (Result<RulerMeasurement, Failure>) -> Void) {
        refreshAppearance()
        guard CGPreflightScreenCaptureAccess() else {
            completion(.failure(.notPermitted))
            return
        }
        guard let screen = RulerSheet.screens().first(where: { $0.frame.contains(point) }) else {
            completion(.failure(.noScreen))
            return
        }
        capture(only: screen.index) { [weak self] sheets in
            guard let self else { return }
            // Kept only for the length of this call: a still of the whole
            // screen is a good few megabytes, and nobody is hovering over it.
            let previous = self.sheets
            self.sheets = sheets
            defer { self.sheets = previous }
            guard !sheets.isEmpty else {
                completion(.failure(.captureFailed))
                return
            }
            guard let measurement = self.bounds(at: point) else {
                completion(.failure(.noScreen))
                return
            }
            completion(.success(measurement))
        }
    }

    /// A straight line between two points needs no pixels at all, so this
    /// answers without photographing anything.
    func measureLine(from: CGPoint, to: CGPoint) -> Result<RulerMeasurement, Failure> {
        guard let screen = RulerSheet.screens().first(where: { $0.frame.contains(from) })
            ?? RulerSheet.screens().first(where: { $0.frame.contains(to) }) else {
            return .failure(.noScreen)
        }
        let rect = CGRect(x: min(from.x, to.x), y: min(from.y, to.y),
                          width: abs(to.x - from.x), height: abs(to.y - from.y))
        return .success(RulerMeasurement(kind: .line, screen: screen.index, rect: rect,
                                         scale: screen.scale, from: from, to: to))
    }

    /// The visible area of the screen a measurement was taken on, for turning
    /// it into the fractions the layout tools speak.
    func visibleArea(ofScreen index: Int) -> CGRect {
        RulerSheet.screens().first { $0.index == index }?.visible ?? .zero
    }

    private func refreshAppearance() {
        guard let current = appearance?() else { return }
        tint = current.tint
        tolerance = current.tolerance
    }

    private func bounds(at point: CGPoint) -> RulerMeasurement? {
        guard let sheet = sheets.first(where: { $0.frame.contains(point) }) else { return nil }
        let pixel = CGPoint(x: (point.x - sheet.frame.minX) * sheet.scale,
                            y: (point.y - sheet.frame.minY) * sheet.scale)
        guard let box = EdgeDetector.bounds(in: sheet.grid, at: pixel, tolerance: tolerance) else {
            return nil
        }
        let rect = CGRect(x: sheet.frame.minX + box.minX / sheet.scale,
                          y: sheet.frame.minY + box.minY / sheet.scale,
                          width: box.width / sheet.scale, height: box.height / sheet.scale)
        return RulerMeasurement(kind: .bounds, screen: sheet.index, rect: rect, scale: sheet.scale)
    }

    private func line(from: CGPoint, to: CGPoint) -> RulerMeasurement? {
        guard let sheet = sheets.first(where: { $0.frame.contains(from) }) ?? sheets.first else {
            return nil
        }
        let rect = CGRect(x: min(from.x, to.x), y: min(from.y, to.y),
                          width: abs(to.x - from.x), height: abs(to.y - from.y))
        return RulerMeasurement(kind: .line, screen: sheet.index, rect: rect,
                                scale: sheet.scale, from: from, to: to)
    }

    // MARK: - Capture

    /// Photographs the screens with Plonk's own windows out of the way, since
    /// a pinned crop or the crosshairs sitting over the thing being measured
    /// would be what got measured.
    private func capture(only wanted: Int? = nil, completion: @escaping ([RulerSheet]) -> Void) {
        let screens = RulerSheet.screens().filter { wanted == nil || $0.index == wanted }
        let restore = hideOwnWindows?()
        RulerSheet.capture(screens) { sheets in
            restore?()
            completion(sheets)
        }
    }
}
