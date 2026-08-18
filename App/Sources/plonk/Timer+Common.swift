import Foundation

// The managers' timers all run on the main run loop in `.common` mode, so a
// tick still lands while a menu is open or a slider is being dragged.

extension Timer {
    static func common(every interval: TimeInterval, _ tick: @escaping () -> Void) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in tick() }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    static func common(at date: Date, _ fire: @escaping () -> Void) -> Timer {
        let timer = Timer(fire: date, interval: 0, repeats: false) { _ in fire() }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
