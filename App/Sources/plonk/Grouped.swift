extension Sequence {
    /// Buckets by `key`, in the order each key was first seen, so a list drawn
    /// from it keeps the order its source already had.
    func groupedPreservingOrder<Key: Hashable>(by key: (Element) -> Key) -> [(key: Key, elements: [Element])] {
        var order: [Key] = []
        var buckets: [Key: [Element]] = [:]
        for element in self {
            let bucket = key(element)
            if buckets[bucket] == nil { order.append(bucket) }
            buckets[bucket, default: []].append(element)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }
}
