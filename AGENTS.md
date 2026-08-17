# Agent rules

Rules for AI agents working in this repo.

## Layout

- `App/` — Swift package, the menu bar app. One type per file, files stay under ~300 lines.
- `mcp/` — TypeScript MCP server: `src/server.ts` compiled to `dist/` via `npm run build`. Keep it a thin proxy; logic belongs in the app. Tests are `mcp/test/*.test.js`, run against `dist/` on the Node test runner with no extra dependencies. Tool description rules are in `mcp/AGENTS.md`.
- `scripts/build.sh` — the only build entry point.

Inside `App/Sources/plonk/`, the pieces that are easy to get lost in:

- `Router` owns the route table and nothing else: every case is one line to the
  module that handles it, in a `Router+*` file of its own.
- `AppDelegate.swift` is the list of what the app is made of and the order it
  comes up in, and nothing else. Every module's wiring lives in an
  `AppDelegate+<Module>.swift` beside it, which is why none of those stored
  properties is private: Swift only lets an extension in the same file see
  that. New behavior goes in the module's file, or in a new one.
- `ConfigStore` is the only way a setting is written. `update` clamps and saves
  it, then `didMutate` fires and `AppDelegate.applyConfig` hands the whole
  config to every manager. Nothing pushes a single field at a manager itself.
- `Ink` holds the surfaces, the radius and the accent gradient every page draws
  with, and `SettingRows` the rows a settings card is made of. Pages compose
  those instead of spelling out colours.
- `Resources/en.lproj/Localizable.strings` holds every word the user reads, and
  the `Strings+*.swift` files declare the keys that reach it. Views hold keys,
  never sentences — see "Text" below.
- `AppActions` is what the UI can ask the app to *do*: commands, not settings.
  A setting needs nothing there — `update(\.field, to:)` writes any field of
  `Config`. `AppModel` holds that config plus the state config cannot answer:
  what a manager is doing now, what macOS has granted, what is on screen.
  Views never reach past it.
- `ScreenIdentity` turns a screen index into the keys config is stored under.
- `WindowAccess` is every call into the Accessibility API and nothing else.
  `WindowManager` decides where a window goes and is the only caller; a window
  that moves without `WindowManager.place` seeing it announces nothing.

## Adding a module

Plonk is a suite; each capability (workspaces, zones, keep-awake, screenshots, …)
is a module. A new module touches five places, nothing else:

1. A manager type in `App/Sources/plonk/` owning the behavior, with an
   `apply(_ config: Config)` taking its settings. It is called after every
   config change, so it must be cheap and safe to run when nothing moved —
   guard any `didSet` that does real work on the value having changed.
2. A `SettingsPage` entry in `SettingsPages.all`, naming the `SettingsGroup` it
   belongs under as its `parent` (that is what the sidebar draws), plus any
   status-menu items in `StatusMenuController`.
3. A `Router+<Module>.swift` holding its route handlers, and one line per route
   in `Router.handle` under its own path prefix (e.g. `/shot/*`).
4. An MCP tool file `mcp/src/tools/<module>.ts` with a `register(server)`
   function, wired in `mcp/src/server.ts`.
5. A call to the manager's `apply` in `AppDelegate.applyConfig`.

Only a command belongs on `AppActions` — something the app *does*, like taking
a screenshot or launching a workspace. A setting is a field on `Config` and a
row bound with `model.binding(\.field)`; no method, no mirrored property, and
no push at a manager. Anything that has to be held inside bounds gets a line in
`Config.clamp`, which runs on every write and on load.

A setting is a new field on `Config` with a default, and that is the whole of
it. `Config.decode` merges the file over the defaults before decoding, so an
old config file keeps working without a line written anywhere; never hand-write
an `init(from:)` on `Config`, because it would bypass that merge and take the
tolerance with it.

Anything stored per monitor is keyed by display UUID via
`ScreenIdentity.keys(forIndex:)`, never by the bare index: indices shift when a
display is unplugged.

## Build & verify

Each line is a subshell, so the block runs as written from the repository root:

```sh
(cd App && swift build)          # must pass before any commit
./scripts/test.sh                # unit tests — must pass
./scripts/lint.sh                # style rules — must pass
(cd mcp && npm test)             # must pass when mcp/ changed
node scripts/check-zone-sets.mjs # must pass when zone-sets/ changed
node scripts/check-strings.mjs   # must pass when any user-facing text changed
./scripts/build.sh               # produces Plonk.app; needs a signing identity
curl -s 127.0.0.1:43917/ping     # smoke test while the app is running
```

The first four need no signing certificate. `build.sh` does, and refuses
rather than produce a bundle that cannot hold its permissions; see
[CONTRIBUTING.md](CONTRIBUTING.md) for why and how to make one.

`scripts/lint.sh` enforces the file-length rule above, plus no emoji, no
trailing whitespace and a final newline. Files already over 300 lines are
recorded in `scripts/line-limit-baseline` with the length they had that day:
they may shrink, never grow, and a new file has to come in under the limit
outright. Shortening one means lowering its number in the same commit.

Anything that decides where a window lands is checked by hand, because none of
it is reachable from the unit suite. `scripts/testbench.sh up 4` opens
throwaway TextEdit windows, `state` prints where each landed as fractions, and
`down` clears them away. Use it instead of moving the user's real windows.

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
- Coordinate spaces are documented in `WindowManager.swift` — read that before touching geometry.
- Annotations are stored in unit coordinates, not view points; see `Annotation.swift`.

## Text

Every string the user reads lives in `App/Sources/plonk/Resources/en.lproj/`,
and nowhere else. A view holds a key:

```swift
Text(.zonesOverlay)                       // a page heading
Button(.commonCancel) { dismiss() }       // a button
HUD.shared.show(.hudNoTextFound)          // a notice
```

Adding one is two edits and no more. Put the English in
`Localizable.strings`, keyed by `<module>.<thing>`; declare it in the
`Strings+*.swift` file for that module as `Self.key("module.thing")`. Anything
counted goes in `Localizable.stringsdict` instead, because English needing two
plural forms is not a reason to assume every language does.

Rules the checker enforces, so they are worth knowing before it tells you:

- A type that carries text to the screen holds a `LocalizedStringResource`, not
  a `String` — `SettingRow`, `HotkeyAction.title`, `SettingsPage.title`. That is
  what makes a raw sentence impossible to pass rather than merely discouraged.
- Never key anything off displayed text. `HotkeyAction.Group` is a value, and
  `group.title` is what gets drawn; filtering on the words would break the
  moment they were translated.
- English is a translation like any other. `en.lproj` is where it lives, and
  adding a language means one new `.lproj` beside it and no Swift at all.
- What an agent reads over the API is a different surface: ids, route names,
  `phase` and every other machine-readable field stay English, always. Sentences
  written for a person are translated even when they also reach an agent — the
  update status, the keep-awake status, and why an app in a workspace did not
  land. Each of those sits beside a structured field that did not change.

`scripts/check-strings.mjs` fails on a key with no value, a value nothing uses,
a mismatched number of format specifiers, a translation that has drifted from
English, and a literal sentence left in a view.

## Boundaries

- The HTTP API binds to loopback only. Never expose it on other interfaces.
- It must keep rejecting browser-originated requests
  (`ControlServer.browserRejection`). Do not add CORS headers.
- Every route but `/ping` is gated on the token in `APIToken`, and the check
  lives in the transport so a new route is covered without doing anything.
  Do not add exemptions. `/ping` is the only one, so a client can tell a closed
  app from a stale token, and it has to stay free of anything worth reading.
- Nothing on the main thread may wait on another process or on the user.
  `screencapture` runs asynchronously for exactly this reason.
- No telemetry, no analytics, no crash reporting, and no third-party Swift
  dependencies. The update check in `UpdateManager` is the only outbound
  connection the app is allowed to make — one host, no identifier, and off
  entirely when the user says so. Anything else that wants the network needs
  the README's privacy section rewritten first, which is the point of the rule.
- Do not commit build artifacts (`.build/`, `Plonk.app`, `node_modules/`).
- The claims in `README.md`, `docs/verify.md` and `SECURITY.md` are checkable,
  and have to stay that way. Any change to the network, the permissions, the
  entitlements or the update path makes one of them false — fix the document in
  the same commit, and never widen a claim past what the code actually does.
- Anything a user would notice goes in `CHANGELOG.md` under Unreleased, in the
  same commit that changes it.

## Agent notes

Things that have already cost someone an hour.

- **Verify against the built bundle, not `swift build`.** `swift build` only
  refreshes `App/.build`; the app the user is running is `Plonk.app`. After any
  change you intend to check live:
  `./scripts/build.sh && pkill -f "Plonk.app/Contents/MacOS/plonk"; sleep 2; open Plonk.app`
- **Permissions are pinned to the code signature, not to the app.** TCC stores
  the designated requirement, so any change to it drops Accessibility and
  Screen Recording at once. `scripts/build.sh` refuses to build without the
  `Plonk Signing` identity for exactly this reason — never work around it by
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
  anything visual, and the geometry checklist in the PR template filled in for
  anything that moves a window.
- Never push directly to `main`; branch and open a PR.
- No generated marketing prose in PR descriptions: state what changed and why, in plain language.
- Never push to somebody else's branch. Review asks for changes; it does not
  make them. CONTRIBUTING.md promises this, so it is a rule, not a courtesy.
