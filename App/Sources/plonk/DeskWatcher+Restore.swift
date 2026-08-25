import AppKit
import ApplicationServices

// Putting a desk back, and the two pure steps both halves share: which
// screen a window is on, and the fraction it sits at there.

extension DeskWatcher {
    /// Puts every remembered window back for this set of displays, off the
    /// main queue, and says which windows it saw to: the ones it had a note
    /// and a display for, whether or not the app took the frame. A window
    /// whose app has quit or is excluded, or whose display is not among
    /// them, is left alone; one already where the note says is not touched.
    /// Overtaken by another display change, it stops, calls back nothing and
    /// leaves the settling to that change's own restore.
    func restore(for displays: Set<String>, completion: @escaping (Set<WindowKey>) -> Void) {
        guard enabled else {
            settling = false
            completion([])
            return
        }
        let generation = self.generation
        let screens = Self.identified(windows.screens())
        let moves: [(window: AXUIElement, rect: CGRect)] = memory.entries(for: displays).compactMap { entry in
            guard let screen = screens.first(where: { $0.uuid == entry.screenUUID })?.screen,
                  let app = windows.app(ofWindow: entry.window), isExcluded?(app) != true else { return nil }
            return (entry.window, ZoneGeometry.frame(for: entry.frac, in: screen.visible))
        }
        restoreQueue.async { [weak self] in
            guard let self else { return }
            for move in moves {
                guard self.generation == generation else { return }
                if let now = WindowAccess.frame(of: move.window), Self.close(now, move.rect) { continue }
                _ = WindowAccess.setFrame(move.rect, of: move.window)
            }
            DispatchQueue.main.async {
                guard self.generation == generation else { return }
                self.settling = false
                completion(Set(moves.map { WindowKey(element: $0.window) }))
            }
        }
    }

    /// Within a point on every side: what a window that has not moved reads
    /// back as, once the app has rounded the frame it was given.
    static func close(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= 1 && abs(a.minY - b.minY) <= 1
            && abs(a.width - b.width) <= 1 && abs(a.height - b.height) <= 1
    }

    /// The screens with the identity each is stored under; one with none is
    /// left out, since there would be nowhere to put a window back.
    static func identified(_ screens: [WindowManager.ScreenInfo]) -> [(screen: WindowManager.ScreenInfo, uuid: String)] {
        screens.compactMap { screen in ScreenIdentity.uuid(forIndex: screen.index).map { (screen, $0) } }
    }

    /// Each window as a fraction of the display its centre is on. A window
    /// on no display is not worth noting, and nor is one over the menu bar:
    /// that is a fullscreen window on a Space of its own, and where it goes
    /// is not the desk's to say.
    static func entries(of windows: [(window: AXUIElement, frame: CGRect)],
                        screens: [(screen: WindowManager.ScreenInfo, uuid: String)]) -> [DeskMemory.Entry] {
        windows.compactMap { item in
            let centre = CGPoint(x: item.frame.midX, y: item.frame.midY)
            guard let home = screens.first(where: { $0.screen.frame.contains(centre) }),
                  item.frame.minY >= home.screen.visible.minY - 1,
                  let frac = ZoneGeometry.fraction(of: item.frame, in: home.screen.visible) else { return nil }
            return DeskMemory.Entry(window: item.window, frac: frac, screenUUID: home.uuid)
        }
    }
}
