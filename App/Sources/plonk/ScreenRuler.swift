import AppKit

// A ruler for the screen: what is that, how big is it, how far apart are those.
//
// macOS has no ruler. ⌘⇧4 shows the size of a drag while it is happening, which
// answers the second question and only while a crosshair is up. What it cannot
// do is find the edges of a thing for you, and that is most of the work: nobody
// wants to aim a drag at the exact corner of a button.
//
// So the screen is photographed once at the start and every measurement is
// taken against that still. Hovering asks EdgeDetector how far the pointer can
// go each way before it meets an edge and draws those two runs, dragging
// measures a straight line, a click copies whatever is showing, Space takes a
// fresh picture, Escape ends it. Measuring against a frozen frame rather than
// the live screen is deliberate: it costs one capture instead of thirty a
// second, and a picture that stops moving is the one being measured.

final class ScreenRuler {
    static let shared = ScreenRuler()

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
    /// Puts Plonk's own windows back. Held for the length of a session rather
    /// than the length of the capture: the ruler is often started from the
    /// Ruler page, and leaving that window up would mean hovering over Plonk
    /// and measuring what is behind it.
    private var restoreOwnWindows: (() -> Void)?
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
        hideOwnWindowsForSession()
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
        announce?(String(localized: .rulerHint))
        update(at: NSEvent.mouseLocation)
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .keyDown:
            // 53 is Escape, 36 Return. Nothing else does anything: a stray
            // keystroke must not leave the overlay up with no way out.
            if event.keyCode == 53 { finish(current.map { .success($0) } ?? .failure(.cancelled)) }
            if event.keyCode == 36 { copyCurrent() }
            // 49 is Space: the still goes stale the moment anything on the
            // screen moves, and re-opening the ruler to get a fresh one is a
            // silly thing to make somebody do.
            if event.keyCode == 49 { recapture() }
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
            current = spans(at: point)
        }
        overlay?.update(measurement: current, pointer: pointer, anchor: anchor.map(RulerSheet.toScreen))
    }

    /// Photographs the screen again, with the ruler's own overlay out of the
    /// picture, and goes on measuring against that.
    private func recapture() {
        overlay?.setVisible(false)
        capture { [weak self] sheets in
            guard let self else { return }
            if !sheets.isEmpty { self.sheets = sheets }
            overlay?.setVisible(true)
            announce?(String(localized: sheets.isEmpty
                                        ? LocalizedStringResource.rulerRephotographFailed
                                        : .rulerRephotographed))
            update(at: NSEvent.mouseLocation)
        }
    }

    private func copyCurrent() {
        guard let current else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(current.clipboardText, forType: .string)
        announce?(String(localized: .rulerCopied(current.clipboardText)))
    }

    private func finish(_ result: Result<RulerMeasurement, Failure>) {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        restoreOwnWindows?()
        restoreOwnWindows = nil
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

    /// The two runs through one point, with no user involved: the agents' way in.
    /// `tolerance` overrides the user's setting for this one measurement, for a
    /// caller that knows it is looking at something faint or something noisy.
    func measure(at point: CGPoint, tolerance override: Int? = nil,
                 completion: @escaping (Result<RulerMeasurement, Failure>) -> Void) {
        refreshAppearance()
        if let override {
            tolerance = override.clamped(to: EdgeDetector.toleranceRange)
        }
        guard CGPreflightScreenCaptureAccess() else {
            completion(.failure(.notPermitted))
            return
        }
        guard let screen = RulerSheet.screens().first(where: { $0.frame.contains(point) }) else {
            completion(.failure(.noScreen))
            return
        }
        let restore = hideOwnWindows?()
        capture(only: screen.index) { [weak self] sheets in
            restore?()
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
            guard let measurement = self.spans(at: point) else {
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

    private func spans(at point: CGPoint) -> RulerMeasurement? {
        guard let sheet = sheets.first(where: { $0.frame.contains(point) }) else { return nil }
        let pixel = CGPoint(x: (point.x - sheet.frame.minX) * sheet.scale,
                            y: (point.y - sheet.frame.minY) * sheet.scale)
        guard let box = EdgeDetector.spans(in: sheet.grid, at: pixel, tolerance: tolerance) else {
            return nil
        }
        let rect = CGRect(x: sheet.frame.minX + box.minX / sheet.scale,
                          y: sheet.frame.minY + box.minY / sheet.scale,
                          width: box.width / sheet.scale, height: box.height / sheet.scale)
        return RulerMeasurement(kind: .spans, screen: sheet.index, rect: rect, scale: sheet.scale)
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

    /// Plonk's own windows go out of the way before any of this: a pinned crop
    /// or the settings window sitting over the thing being measured would be
    /// what got measured.
    private func hideOwnWindowsForSession() {
        guard restoreOwnWindows == nil else { return }
        restoreOwnWindows = hideOwnWindows?()
    }

    private func capture(only wanted: Int? = nil, completion: @escaping ([RulerSheet]) -> Void) {
        RulerSheet.capture(RulerSheet.screens().filter { wanted == nil || $0.index == wanted },
                           completion: completion)
    }
}
