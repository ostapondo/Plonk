# Agent rules

Rules for AI agents working in this repo.

## Layout

- `App/` — Swift package, the menu bar app. One type per file, files stay under ~300 lines.
- `mcp/` — TypeScript MCP server: `src/server.ts` compiled to `dist/` via `npm run build`. Keep it a thin proxy; logic belongs in the app. Tool description rules are in `mcp/AGENTS.md`.
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
curl -s 127.0.0.1:43917/ping   # smoke test while the app is running
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
- No telemetry, no analytics, no crash reporting, and no third-party Swift
  dependencies. The update check in `UpdateManager` is the only outbound
  connection the app is allowed to make — one host, no identifier, and off
  entirely when the user says so. Anything else that wants the network needs
  the README's privacy section rewritten first, which is the point of the rule.
- Do not commit build artifacts (`.build/`, `Plonk.app`, `node_modules/`).
- The claims in `README.md` and `SECURITY.md` are checkable, and have to stay
  that way. Any change to the network, the permissions, the entitlements or the
  update path makes one of them false — fix the document in the same commit,
  and never widen a claim past what the code actually does.

## Agent notes

Things that have already cost someone an hour.

- **Verify against the built bundle, not `swift build`.** `swift build` only
  refreshes `App/.build`; the app the user is running is `Plonk.app`. After any
  change you intend to check live:
  `./scripts/build.sh && pkill -f "Plonk.app/Contents/MacOS/plonk"; sleep 2; open Plonk.app`
- **Permissions are pinned to the code signature, not to the app.** TCC stores
  the designated requirement, so any change to it drops Accessibility and
  Screen Recording at once. `scripts/build.sh` refuses to build without the
  `Plonk Dev` identity for exactly this reason — never work around it by
  ad-hoc signing. A grant that keeps vanishing across rebuilds is a stale entry
  from an older signature: `tccutil reset ScreenCapture dev.plonk.app`, then
  grant it once more.
- **Releases go out through the tag, never by hand.** Pushing `v<version>` runs
  `.github/workflows/release.yml`, which builds, signs and attests on GitHub's
  runners and publishes `plonk-mcp` with npm provenance. Building on a laptop
  and uploading the zip breaks the one claim that ties a shipped binary to this
  source, so `gh attestation verify` on it fails and the release is worse than
  no release. `MARKETING_VERSION` in `version.env`, `version` in
  `mcp/package.json` and the tag all have to agree; the workflow stops if they
  do not.
- **Releases are built by `scripts/release.sh`, never by hand.** v0.0.3 was
  zipped manually, went out ad-hoc signed, and reset the permissions of every
  user who installed it — and no copy can auto-update to or from it, because
  `UpdateManager` installs a build only when it satisfies the running copy's
  designated requirement. The script holds every release to the requirement
  recorded in `scripts/release-requirement` — not to the bundle's own
  signature, which would only be comparing a build with itself. Changing that
  file changes it for everyone who has already installed: they lose both
  permissions once and cannot update automatically across the change.
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
