import Foundation

// The /update routes.
//
// Both of them dial out, and the app promises a process that only listens
// unless the user asked otherwise. So both are refused when update checks are
// off, however good the caller's token is: a client that could undo the setting
// by calling the route would make the setting a suggestion.

extension Router {
    /// Nil when the caller may proceed. The two routes below share it, because
    /// a promise kept by one of them is not kept.
    private func outboundRefusal(_ instead: String) -> HTTPResponse? {
        guard !store.config.updateCheckAutomatically else { return nil }
        return .conflict("the user turned update checks off, so Plonk makes no outbound "
                         + "connection. \(instead)")
    }

    func checkForUpdatesRoute() -> HTTPResponse {
        guard let checkForUpdates, let updateState else {
            return .failed("updates are not available")
        }
        // The button in Plonk still works: that one is the user asking.
        if let refusal = outboundRefusal(
            "They can check from Plonk's Updates page, or switch it back on."
        ) { return refusal }

        checkForUpdates()
        // The check is a network round trip, and nothing here may wait on one.
        // The caller polls /update/state, or listens for "update" on /events,
        // which is what the tool description tells it to do.
        return .ok(updateState().merging(["ok": true, "checking": true]) { _, new in new })
    }

    func installUpdateRoute() -> HTTPResponse {
        guard let installUpdate, let updateState else {
            return .failed("updates are not available")
        }
        if let refusal = outboundRefusal("They can install from Plonk's Updates page.") {
            return refusal
        }
        let state = updateState()
        guard state["available"] as? Bool == true else {
            return .badRequest("no newer release is on offer; POST /update/check first")
        }
        installUpdate()
        return .ok(state.merging([
            "ok": true,
            "installing": true,
            "note": "Plonk quits to swap the bundle in and relaunches itself; "
                + "the API is unreachable for a few seconds",
        ]) { _, new in new })
    }
}
