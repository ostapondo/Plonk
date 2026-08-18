import Foundation

// The /workspaces routes, and the /layouts aliases older clients still call.
//
// Saving with no items snapshots the desktop, which is the shape agents use
// most: "remember this" without having to describe what "this" is.

extension Router {
    func saveWorkspaceRoute(_ body: [String: Any]) -> HTTPResponse {
        guard let name = Self.trimmedName(body["name"]) else {
            return .badRequest("body must include name")
        }
        let items: [WorkspaceItem]
        if let raw = body["items"] as? [[String: Any]], !raw.isEmpty {
            items = raw.compactMap { WorkspaceItem(dict: $0) }
            guard items.count == raw.count else {
                return .badRequest("every item needs app and frame {x,y,w,h} within 0..1, with w and h above 0")
            }
        } else {
            items = snapshotWorkspace()
            guard !items.isEmpty else {
                return .badRequest("nothing on screen to snapshot")
            }
        }
        // Editing an existing workspace keeps its launch behavior unless the
        // request says otherwise.
        let moveExisting = (body["move_existing"] as? Bool)
            ?? store.config.workspaces[name]?.moveExisting ?? true
        store.update { $0.workspaces[name] = Workspace(items: items, moveExisting: moveExisting) }
        return .ok(["ok": true, "saved": name, "items": items.count, "apps": Workspace(items: items).apps])
    }

    func launchWorkspaceRoute(_ body: [String: Any], respond: @escaping (HTTPResponse) -> Void) {
        guard let name = Self.trimmedName(body["name"]) else {
            respond(.badRequest("body must include name"))
            return
        }
        guard let workspace = store.config.workspaces[name] else {
            respond(.notFound("no workspace named \"\(name)\""))
            return
        }
        guard let launchWorkspace else {
            respond(.failed("launching is not available"))
            return
        }
        let screen = (body["screen"] as? NSNumber)?.intValue
        launchWorkspace(name, workspace, screen) { results in
            respond(.ok([
                "ok": results.allSatisfy { $0["ok"] as? Bool == true },
                "workspace": name,
                "results": results,
            ]))
        }
    }

    func deleteWorkspaceRoute(_ body: [String: Any]) -> HTTPResponse {
        guard let name = Self.trimmedName(body["name"]) else {
            return .badRequest("body must include name")
        }
        guard store.config.workspaces[name] != nil else {
            return .notFound("no workspace named \"\(name)\"")
        }
        store.update { $0.workspaces.removeValue(forKey: name) }
        return .ok(["ok": true, "deleted": name])
    }

    func renameWorkspaceRoute(_ body: [String: Any]) -> HTTPResponse {
        guard let from = Self.trimmedName(body["from"]), let to = Self.trimmedName(body["to"]) else {
            return .badRequest("body must include from and to")
        }
        guard store.config.workspaces[from] != nil else {
            return .notFound("no workspace named \"\(from)\"")
        }
        guard from == to || store.config.workspaces[to] == nil else {
            return .conflict("a workspace named \"\(to)\" already exists")
        }
        // Renaming to the name it already has is not an error, and writing it
        // would announce a change that did not happen.
        if from != to {
            store.update {
                guard let workspace = $0.workspaces.removeValue(forKey: from) else { return }
                $0.workspaces[to] = workspace
            }
        }
        return .ok(["ok": true, "renamed": from, "to": to])
    }

    /// Everything on screen, as a workspace.
    func snapshotWorkspace() -> [WorkspaceItem] {
        windows.listWindows().compactMap { entry in
            let screen = entry["screen"] as? Int
            return WorkspaceItem(window: entry,
                                 screenUUID: screen.flatMap { ScreenIdentity.uuid(forIndex: $0) })
        }
    }
}
