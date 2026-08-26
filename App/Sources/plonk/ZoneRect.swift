import Foundation

// One zone: a fractional rect of a screen's visible area, origin top-left,
// and optionally a name. The name is what voice and an agent can call the
// zone by ("put this in chat"), drawn under the number in the overlay; the
// number stays the address the keys use, so a set with no names loses
// nothing.

struct ZoneRect: Codable, Equatable {
    var x: Double
    var y: Double
    var w: Double
    var h: Double
    /// As stored, `cleanName` has been through it: trimmed, never empty,
    /// never a bare number, at most `nameLimit` characters; nil is the common
    /// case. The editor's draft is the one place it holds raw text, until
    /// the set is saved. Compared ignoring case wherever it is looked up.
    var name: String?

    /// Long enough for "build log", short enough to stay a label on a
    /// narrow zone of the overlay.
    static let nameLimit = 24

    init(_ x: Double, _ y: Double, _ w: Double, _ h: Double, name: String? = nil) {
        self.x = x; self.y = y; self.w = w; self.h = h
        self.name = Self.cleanName(name)
    }

    init?(dict: [String: Any]) {
        guard let x = (dict["x"] as? NSNumber)?.doubleValue,
              let y = (dict["y"] as? NSNumber)?.doubleValue,
              let w = (dict["w"] as? NSNumber)?.doubleValue,
              let h = (dict["h"] as? NSNumber)?.doubleValue,
              w > 0, h > 0, x >= 0, y >= 0,
              x + w <= 1.0001, y + h <= 1.0001 else { return nil }
        self.x = x; self.y = y; self.w = w; self.h = h
        name = Self.cleanName(dict["name"] as? String)
    }

    var frac: FracRect { FracRect(x, y, w, h) }

    var asDict: [String: Any] {
        var dict: [String: Any] = ["x": x, "y": y, "w": w, "h": h]
        if let name { dict["name"] = name }
        return dict
    }

    /// A name as it is stored: the space around it dropped, cut to the limit,
    /// and nil when nothing is left or when it is a bare number, since a
    /// number already means the zone in that place. One place, so a name
    /// typed in the editor, sent by an agent, read from a hand-edited file or
    /// asked for over the API is the same name.
    static func cleanName(_ raw: String?) -> String? {
        guard let raw else { return nil }
        // Trimmed again after the cut, so a cut that lands on a space does
        // not store one: cleaning a clean name changes nothing.
        let trimmed = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(nameLimit))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, Int(trimmed) == nil else { return nil }
        return trimmed
    }

    /// Whether `raw` is a name that will not be kept: something was typed
    /// and it cleans to nothing, which is a bare number. Blank is not that;
    /// blank means no name.
    static func isRefusedName(_ raw: String) -> Bool {
        !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && cleanName(raw) == nil
    }
}

extension ZoneRect {
    /// A hand-edited file goes through the same cleaning as everything else,
    /// and a name that is not text is no name rather than a config that will
    /// not load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        x = try c.decode(Double.self, forKey: .x)
        y = try c.decode(Double.self, forKey: .y)
        w = try c.decode(Double.self, forKey: .w)
        h = try c.decode(Double.self, forKey: .h)
        name = Self.cleanName(try? c.decodeIfPresent(String.self, forKey: .name))
    }
}
