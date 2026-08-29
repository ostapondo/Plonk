import Foundation

/// A monitor index crossing the untyped HTTP boundary. Parsing it once keeps
/// every route from disagreeing about strings, booleans and detached screens.
enum ScreenInput {
    enum Result {
        case omitted
        case attached(index: Int, keys: [String])
        case invalidType
        case notFound(Int)
    }

    static func parse(_ value: Any?) -> Result {
        guard let value, !(value is NSNull) else { return .omitted }
        guard !(value is Bool), let index = (value as? NSNumber)?.intValue else {
            return .invalidType
        }
        guard let keys = ScreenIdentity.attachedKeys(forIndex: index) else {
            return .notFound(index)
        }
        return .attached(index: index, keys: keys)
    }
}
