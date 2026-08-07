# Agent rules

Rules for AI agents working in this repo.

## Layout

- `App/` — Swift package, the menu bar app. One type per file, files stay under ~300 lines.
- `mcp/` — TypeScript MCP server: `src/server.ts` compiled to `dist/` via `npm run build`. Keep it a thin proxy; logic belongs in the app.
- `scripts/build.sh` — the only build entry point.

Inside `App/Sources/plonk/`, the pieces that are easy to get lost in:

- `Router` owns every HTTP route. `AppDelegate` owns lifecycle, windows and the
  status menu, and nothing else.
- `AppActions` is the full list of things the UI can ask the app to do.
  `AppModel` is state only; views never reach past it.
- `ScreenIdentity` turns a screen index into the keys config is stored under.

## Adding a module

Plonk is a suite; each capability (workspaces, zones, keep-awake, screenshots, …)
is a module. A new module touches five places, nothing else:

1. A manager type in `App/Sources/plonk/` owning the behavior.
2. Methods on `AppActions`, implemented in the `AppDelegate` extension.
3. A `SettingsPage` entry registered in `AppDelegate.refreshModel` (drives the
   sidebar) plus any status-menu items in `StatusMenuController`.
4. HTTP routes under its own path prefix in `Router.handle` (e.g. `/shot/*`).
5. An MCP tool file `mcp/src/tools/<module>.ts` with a `register(server)`
   function, wired in `mcp/src/server.ts`.

Config lives as new fields on `Config` with `decodeIfPresent` defaults so old
config files keep working. Anything stored per monitor is keyed by display UUID
via `ScreenIdentity.keys(forIndex:)`, never by the bare index: indices shift
when a display is unplugged.

## Build & verify

```sh
cd App && swift build          # must pass before any commit
./scripts/test.sh              # unit tests — must pass
cd mcp && npm run typecheck    # must pass when mcp/ changed
./scripts/build.sh             # produces Plonk.app
curl -s 127.0.0.1:43917/state  # smoke test while the app is running
```

The release number lives in `version.env`, and only there. `scripts/build.sh`
reads `MARKETING_VERSION` and `BUILD_NUMBER` into `Info.plist`. Bump them to cut
a release; never edit a version inside the plist heredoc.

Pure logic lives in `ZoneGeometry`, `Config`, `ImageFit`, `Router` and
`ControlServer.parseIfComplete` so it stays testable without a desktop session.
Put new logic there and cover it in `App/Tests/plonkTests/`.

## Code style

- Swift API design guidelines; match the existing code.
- Comments only for non-obvious constraints (coordinate spaces, AX quirks). No narration, no changelog comments.
- No emoji anywhere, user-facing strings included. Key glyphs (⌃⌥⇧↩) are not emoji and are fine.
- User-facing strings are English.
- Coordinate spaces are documented in `WindowManager.swift` — read that before touching geometry.
- Annotations are stored in unit coordinates, not view points; see `Annotation.swift`.

## Boundaries

- The HTTP API binds to loopback only. Never expose it on other interfaces.
- It has no authentication, so it must keep rejecting browser-originated
  requests (`ControlServer.browserRejection`). Do not add CORS headers.
- Nothing on the main thread may wait on another process or on the user.
  `screencapture` runs asynchronously for exactly this reason.
- Do not add network calls, telemetry, or third-party Swift dependencies.
- Do not commit build artifacts (`.build/`, `Plonk.app`, `node_modules/`).

## Agent notes

Things that have already cost someone an hour.

- **Verify against the built bundle, not `swift build`.** `swift build` only
  refreshes `App/.build`; the app the user is running is `Plonk.app`. After any
  change you intend to check live:
  `./scripts/build.sh && pkill -f "Plonk.app/Contents/MacOS/plonk"; sleep 2; open Plonk.app`
- **`CGFloat` is not `Double`.** It is its own struct, so
  `[String: CGFloat] as? [String: Double]` returns nil. Anything that crosses
  the `[String: Any]` boundary — `WindowManager.listWindows` and everything
  parsing it — must convert explicitly. This silently broke layout snapshots for
  a long time; `WorkspaceItem(window:)` now has tests that pin it.
- **AX calls block on the other process.** Waiting for an app's window is
  background-queue work (`WorkspaceLauncher`). Never poll AX from the main
  queue; route handlers run there.
- **An app in the Dock with no windows never grows one on its own.** Reopen it
  (`NSWorkspace.openApplication`) — that is what a Dock click does. TextEdit and
  Notes do this routinely.
- **Do not launch a workspace to "test it" while the user is working.** It moves
  their real windows. Save a throwaway workspace with one harmless app, and
  delete it afterwards.
- `/state` and window placement need a real desktop session, so they stay out of
  the unit suite. Put the logic in a parseable seam and test that instead.
- Read `~/Library/Application Support/Plonk/config.json` before changing config
  shapes, and back it up before anything that rewrites it.

## Commits & PRs

- Conventional commits: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`.
- Imperative subject under 72 chars, body only when the why is not obvious.
- One logical change per commit. `swift build` must pass on every commit.
- A PR states what changed and why, plus the commands you ran. Screenshots for
  anything visual.
- Never push directly to `main`; branch and open a PR.
- No generated marketing prose in PR descriptions: state what changed and why, in plain language.
