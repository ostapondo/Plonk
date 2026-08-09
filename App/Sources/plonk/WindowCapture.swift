import AppKit

// Finding the one window an agent asked for, by name rather than by pointing.
//
// The interactive modes hand the user a picker and wait for a click, which is
// no use to something with no hands. So an agent says which window it wants and
// the window server is asked for a matching id. Capturing by id is what makes
// this worth having: macOS keeps every window's image to itself, so one buried
// under three others photographs cleanly, with nothing raised and no focus
// taken. The screenshot is of the window, not of the part of it that shows.

enum WindowCapture {

    /// Both fields are matched case-insensitively, and `app` is tried against
    /// the app's name and its bundle id — the same forgiveness the window
    /// routes give, so whatever `get_state` printed can be pasted straight back.
    struct Query {
        var app: String? = nil
        var titleContains: String? = nil

        var isEmpty: Bool {
            (app?.isEmpty ?? true) && (titleContains?.isEmpty ?? true)
        }
    }

    /// A window the window server admits to, reduced to what choosing between
    /// them needs.
    struct Candidate {
        let id: CGWindowID
        let app: String
        let bundleID: String
        let title: String
        let bounds: CGRect
        let onScreen: Bool

        var area: CGFloat { bounds.width * bounds.height }

        /// For the error message, which is the only place a caller sees this.
        var described: String { title.isEmpty ? app : "\(app) — \(title)" }
    }

    enum Failure: LocalizedError {
        case nothingAsked
        case notPermitted
        case noMatch(Query, tried: Int)
        case captureFailed(Candidate)
        case shuttingDown

        var errorDescription: String? {
            switch self {
            case .nothingAsked:
                return "say which window: 'app', 'title_contains', or both"
            case .shuttingDown:
                return "Plonk is shutting down"
            case .notPermitted:
                return "Plonk does not have Screen Recording, so it can neither read window "
                    + "titles nor photograph anything. Grant it in System Settings › Privacy & "
                    + "Security › Screen Recording."
            case .noMatch(let query, let tried):
                var wanted: [String] = []
                if let app = query.app, !app.isEmpty { wanted.append("app containing \"\(app)\"") }
                if let title = query.titleContains, !title.isEmpty {
                    wanted.append("title containing \"\(title)\"")
                }
                let subject = wanted.joined(separator: " and ")
                if tried == 0 { return "nothing is open that Plonk can see" }
                return "no window matches \(subject); get_state lists what is open"
            case .captureFailed(let candidate):
                return "macOS would not photograph \(candidate.described). A minimized window "
                    + "keeps no image, so un-minimize it — snap_window does that — and ask again."
            }
        }
    }

    /// Every normal window on the desktop, front to back, across all Spaces.
    ///
    /// `optionAll` also returns the menu bar, the Dock, tooltips, the shadow
    /// behind an open menu and a fair number of one-pixel helpers no user would
    /// call a window. Layer 0 is the ordinary-window layer and drops nearly all
    /// of it; the size floor takes the rest.
    static func candidates(excluding ownPID: pid_t = ProcessInfo.processInfo.processIdentifier)
        -> [Candidate]
    {
        let info = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        // The window list carries no bundle id, and an app with six windows
        // would otherwise be looked up six times.
        var bundleIDs: [pid_t: String] = [:]
        var result: [Candidate] = []

        for entry in info {
            guard let id = entry[kCGWindowNumber as String] as? CGWindowID,
                  let pid = entry[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID,
                  (entry[kCGWindowLayer as String] as? Int) == 0,
                  let boundsDict = entry[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  bounds.width >= minimumSide, bounds.height >= minimumSide
            else { continue }

            if bundleIDs[pid] == nil {
                bundleIDs[pid] = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? ""
            }
            result.append(Candidate(
                id: id,
                app: entry[kCGWindowOwnerName as String] as? String ?? "?",
                bundleID: bundleIDs[pid] ?? "",
                // Titles need Screen Recording; without it every one is empty,
                // and a title query then finds nothing. capture() preflights
                // the permission so that never reaches anyone as a bad match.
                title: entry[kCGWindowName as String] as? String ?? "",
                bounds: bounds,
                // The key is only present when it is true.
                onScreen: entry[kCGWindowIsOnscreen as String] as? Bool ?? false
            ))
        }
        return result
    }

    /// Smaller than this and it is a shadow, a drop target or an off-screen
    /// scratch surface, never something a person would ask for by name.
    private static let minimumSide: CGFloat = 40

    /// Every window the query matches, best first.
    ///
    /// Ranking, in order: how squarely the name was hit — an exact one beats a
    /// partial, or "Code" lands on Xcode while the editor that was named sits
    /// there open; then one that is actually on screen, over one parked on
    /// another Space or minimized; then the largest, because an app's main
    /// window is the big one and its inspector or mini player is not; then
    /// whichever the window server listed first, which is front-most.
    static func ranked(_ query: Query, among all: [Candidate]) -> [Candidate] {
        guard !query.isEmpty else { return [] }
        return all.enumerated()
            .compactMap { offset, candidate in
                rank(candidate, query).map { (tier: $0, offset: offset, candidate: candidate) }
            }
            .sorted { a, b in
                if a.tier != b.tier { return a.tier < b.tier }
                if a.candidate.onScreen != b.candidate.onScreen { return a.candidate.onScreen }
                if a.candidate.area != b.candidate.area { return a.candidate.area > b.candidate.area }
                return a.offset < b.offset
            }
            .map(\.candidate)
    }

    /// The best window for the query, or why there is none.
    static func find(_ query: Query, among all: [Candidate]) -> Result<Candidate, Failure> {
        guard !query.isEmpty else { return .failure(.nothingAsked) }
        guard let best = ranked(query, among: all).first else {
            return .failure(.noMatch(query, tried: all.count))
        }
        return .success(best)
    }

    /// How squarely a candidate answers the query — lower is better — or nil
    /// when it does not answer it at all. Exact before partial, and the name
    /// before the bundle id, is the order `WindowManager.findApp` already uses
    /// for the same question.
    private static func rank(_ candidate: Candidate, _ query: Query) -> Int? {
        if let title = query.titleContains, !title.isEmpty,
           !candidate.title.localizedCaseInsensitiveContains(title) { return nil }
        guard let app = query.app, !app.isEmpty else { return 0 }

        if candidate.app.compare(app, options: .caseInsensitive) == .orderedSame { return 0 }
        if candidate.bundleID.compare(app, options: .caseInsensitive) == .orderedSame { return 0 }
        if candidate.app.localizedCaseInsensitiveContains(app) { return 1 }
        if !candidate.bundleID.isEmpty, candidate.bundleID.localizedCaseInsensitiveContains(app) { return 2 }
        return nil
    }

    /// Finds the window and photographs it. `completion` runs on the main
    /// queue, as the interactive captures do.
    static func capture(_ query: Query, completion: @escaping (Result<NSImage, Failure>) -> Void) {
        // Asked first because without it the desk looks nearly normal and
        // nothing works: the window list still answers, every title in it comes
        // back empty, and the capture writes no file. Left to itself that reads
        // as "your window is minimized", which sends the caller after the wrong
        // thing entirely. Preflight only reports; it never prompts.
        guard CGPreflightScreenCaptureAccess() else {
            DispatchQueue.main.async { completion(.failure(.notPermitted)) }
            return
        }
        guard !query.isEmpty else {
            DispatchQueue.main.async { completion(.failure(.nothingAsked)) }
            return
        }
        let all = candidates()
        let matches = ranked(query, among: all)
        guard let best = matches.first else {
            DispatchQueue.main.async { completion(.failure(.noMatch(query, tried: all.count))) }
            return
        }
        photograph(matches, blaming: best, completion: completion)
    }

    /// Tries the matches in turn. A minimized window and one merely parked on
    /// another Space are the same thing from here — neither is on screen — but
    /// only the first cannot be photographed, so one that will not come out
    /// stands for itself rather than for the whole app. The blame stays with
    /// the best match either way: that is the window the caller named.
    private static func photograph(_ remaining: [Candidate], blaming named: Candidate,
                                   completion: @escaping (Result<NSImage, Failure>) -> Void) {
        guard let next = remaining.first else {
            completion(.failure(.captureFailed(named)))
            return
        }
        ScreenshotManager.captureWindow(next.id) { image in
            guard let image else {
                photograph(Array(remaining.dropFirst()), blaming: named, completion: completion)
                return
            }
            completion(.success(image))
        }
    }
}
