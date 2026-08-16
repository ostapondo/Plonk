import Foundation

// Run something on the main queue, without hopping when it is already there.
//
// A plain `DispatchQueue.main.async` would work everywhere this is used, but it
// defers a callback that could have run now, which turns "the switch is set" or
// "the workspace finished" into a state the caller can observe one tick early.
// Two copies of this had grown in the app; this is the one.

enum OnMain {
    static func run(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}
