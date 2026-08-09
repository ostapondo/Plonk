# Changelog

What changed in each release, from a user's side. The commit log has the rest.

Versions before 0.1.0 shipped in two days and are summarized rather than
itemized. The dates are real; the tidiness is not — most of what is listed
under 0.0.4 was written the same afternoon it went out.

Releases up to and including 0.0.4 were zipped by hand and carry no build
attestation, so `gh attestation verify` fails on them. That is the whole reason
[the release workflow](.github/workflows/release.yml) exists now. Do not install
one of those.

## Unreleased

### Fixed

- **A prompt sent to an agent now shows what it is doing.** A CLI adapter takes
  tens of seconds and moves nothing until it has decided what to move, so the
  palette closing was followed by a two-second HUD and then silence — which
  looks exactly like nothing happening. There is now a ticking count for as
  long as it runs, and it ends on how it went. A failure used to be an `NSLog`
  nobody reads; it says so on screen, with the last line the adapter complained
  about.

- **⌘C, ⌘V, ⌘X and ⌘A work in Plonk's text fields.** They never had, anywhere
  in the app: AppKit delivers those through the main menu's key equivalents,
  and Plonk had no main menu at all, so a field would take a typed sentence but
  not a pasted one. An accessory app draws no menu bar, so the menu that fixes
  it stays invisible.

### Added

- **The command palette has a key of its own — `⌃⌥A`.** It was already
  there, and it was reachable only from inside Plonk's own window, which is the
  one place you are not when you want to move a window. It now opens over
  whatever you are looking at, the way Spotlight does.
- **Type a sentence into it and it goes to your agent.** Anything that is not a
  command — "put the browser left and the terminal top right", "save this as a
  workspace called review" — can be sent as it is, with `⌘return` or by picking
  the last row. It takes the same road a spoken command takes, so it can reach
  nothing a key could not.

## 0.2.3 — 2026-08-09

Nothing in the app changed. This release exists so the MCP server can be
installed by opening a file.

### Added

- Every release now carries `plonk-<version>.mcpb`, the bundle format Claude
  Desktop installs in two clicks. It holds the compiled server and a vendored
  copy of its dependencies, so no client config gets edited by hand and nothing
  is fetched at launch. `npx -y plonk-mcp` still works and is still what the
  CLI-based clients use.
- The bundle gets the same build attestation as the app archive and the npm
  tarball, so `gh attestation verify` ties it to the commit it was built from.

### Removed

- `smithery.yaml`. It described a deployment format Smithery's current
  documentation no longer mentions, and nothing in the repository read it. The
  Smithery listing is built from the bundle instead.

## 0.2.2 — 2026-08-09

Nothing in the app changed. If you are on 0.2.1, there is nothing here worth
updating for. As with 0.2.1, the release exists because npm and the MCP Registry
only take a new description when a version goes out.

### Changed

- The README, the site and both package descriptions lead with the window
  manager rather than with the agent. MCP is one of four ways into the app —
  drag, shortcut, voice, agent — and zones, workspaces, OCR, keep-awake and
  voice all work with the MCP server switched off, so opening on it oversold one
  interface and undersold the other nine utilities. Nothing about the agent
  surface is removed: `docs/agents.md`, the "For agents" section, the MCP badge
  and both client install lines are unchanged, and the two package descriptions
  still say plainly that this is an MCP server, because on npm and in the
  registry that is what the thing is.
- `docs/architecture.svg` says "MCP client" rather than naming one, since any of
  them works.

## 0.2.1 — 2026-08-09

Nothing in the app changed, and if you are on 0.2.0 there is nothing here worth
updating for. The release exists because npm and the MCP Registry only take a
new description when a version goes out, and the old one sold one feature out
of ten.

### Changed

- The README, the site and every package description now say what this is: ten
  menu bar utilities, a window manager among them, rather than the window
  manager alone. Anyone who wanted on-device OCR or a keep-awake that ends by
  itself had no way to tell from the top of the page that they are in here. The
  count is not a slogan — the feature table has ten rows and lists the same ten.
- The update check builds its URL from `ostapondo/plonk` instead of
  `ostapondo/Plonk`, which is the spelling every other file in the repository
  already used. GitHub resolves either, so no installed copy notices.

### Removed

- `docs/reference/fancyzones-editor.png` — a screenshot of another company's
  interface, kept as design reference while the zone picker was being drawn.
  `docs/` is the site root, so it was being served publicly, from a repository
  that is MIT and has no right to offer that file under it.

## 0.2.0 — 2026-08-08

A theme of Plonk's own, a command palette, and a settings window that stopped
being a list of everything the app can do.

### Added

- A theme of Plonk's own: light, dark, or whatever macOS is using, plus an
  accent colour, under Settings, Appearance. Both reach further than the
  window — the zone overlay and the pointer tools take the accent unless they
  have been given a colour of their own, and the theme applies to every panel
  the app puts on screen. Stored under a new `appearance` key in `config.json`;
  files written before this keep working and start on "system".
- A command palette on ⌘K, listing every shortcut, workspace, zone set and
  settings page by name. It is built from the same lists the rest of the app
  uses, so it cannot fall out of step with what the app can do. A placement
  command hides Plonk first, because otherwise the window it would move is
  Plonk's own.
- Opening Plonk while it is already running now shows its window, the way a
  Dock click does. It used to do nothing at all.

### Changed

- The settings window was redrawn. Eleven flat sidebar entries became five
  destinations that unfold into their pages, the permission chips moved to a
  strip in the title bar that only takes room when something is wrong, and the
  Zones page now opens on the set that is actually on your screen instead of a
  pop-up menu of names. Shortcuts are printed on the rows that own them.

- `zone-sets/` — a gallery of layouts as JSON the app's own `/zones/save` route
  accepts unmodified, so trying one is a single command and no build. Adding
  one is the smallest useful change this repo takes, and
  `scripts/check-zone-sets.mjs` validates the folder in its own CI job.
- `scripts/lint.sh` — checks the rules AGENTS.md states and nothing enforced:
  file length, no emoji, no trailing whitespace, a newline at the end of every
  file. No dependencies; it runs on a plain checkout.
- `scripts/line-limit-baseline` — the files that were already over the
  300-line limit, with the length each had that day. They may shrink, never
  grow. New files come in under the limit outright.
- `scripts/testbench.sh` — throwaway TextEdit windows to demonstrate a window
  fix on, and `state` to print where each one landed as fractions. Nobody has
  to move their real windows to prove a patch works.
- A test suite for `mcp/`: `npm test`, on the Node test runner, no new
  dependencies. Covers CLI argument parsing, the identity holders that keep one
  MCP session's name out of another's, and the tool input schemas.
- `.editorconfig`.
- This file.

### Changed

- `mcp`: `options()` moved out of `cli.ts` into `args.ts`, so it can be tested
  without running the CLI.
- README is shorter, and the reference sections it carried now live in `docs/`.
- CONTRIBUTING leads with the loop that needs no signing certificate, and says
  how long a review takes.

## 0.1.0 — 2026-08-08

The first release that is signed, attested and installable with one command.

### Added

- **Homebrew.** `brew install --cask ostapondo/plonk/plonk`.
- **Voice commands that run in the app.** The dozen most common ones — "snap
  this left", "zone three", "put it back", "keep awake for an hour", "launch my
  review workspace" — are handled on the Mac, offline, with no agent and no
  round trip. Anything less clear-cut still goes to the agent.
- **A Home page** with the three steps a new install needs, and a shortcut
  guide read from the front app's own menus.
- **A landing page** at [ostapondo.github.io/Plonk](https://ostapondo.github.io/Plonk/).

### Changed

- The zone gap is typed rather than dragged for, and excluded apps are picked
  from a list instead of typed.
- Notarization is off the roadmap, and the README says so plainly instead of
  promising a stamp that needs a paid Apple account.

### Fixed

- Around twenty ways the overlays, the grab handler and the new modules stepped
  on each other or on the rest of the desk: a grab that was really a click ate
  the click, `⌘` was read as `⇧`, and a disabled feature still held its tap.

## 0.0.5 — 2026-08-08

### Added

- **Releases are built on GitHub's runners**, signed there, and ship with a
  provenance attestation: `gh attestation verify Plonk-<version>.zip -R
  ostapondo/plonk`. `plonk-mcp` publishes to npm over OIDC with provenance.
  Nothing ships from a laptop, which is what makes either check mean anything.
- An update's checksum is verified against what GitHub published before
  anything is unpacked.

### Fixed

- Signing uses a key that can leave the machine it was made on, so the release
  workflow can hold one.
- The release refuses to overwrite an asset that has already been published.

## 0.0.4 — 2026-08-08

The release most of the app arrived in.

### Added

- **The things a decade of Windows power users expect from a zone**, rebuilt
  for the Mac:
  zones by number (`⌃⌥1`–`⌃⌥9`), put-it-back (`⌃⌥0`), spanning two zones,
  excluded apps, focus by geometry, zone appearance, and windows that return to
  their monitor after a display change.
- **Grab and move** — hold a key and drag a window from anywhere inside it.
- **Pin part of the screen** above everything, live or frozen.
- **Text off the screen** (`⌃⌥T`), on-device.
- **Pointer tools** and a **shortcut guide**.
- **Push-to-talk voice** (`⌃⌥V`), recognized on the Mac.
- **Updates from inside Plonk**, installing a build only when it is signed with
  the same certificate as the running copy — the same test macOS applies, so
  Accessibility and Screen Recording carry over.
- **Streamable HTTP transport** (`plonk-mcp --http`) for clients that cannot
  spawn a process, a **live-state SSE stream** at `/events`, and a
  **back-channel** so Plonk can reach the active agent.
- Setup pages for Cursor, Zed and Cline, and `llms-install.md`.

### Fixed

- Rebuilding no longer drops Accessibility and Screen Recording:
  `scripts/build.sh` refuses to run without a stable signing identity, because
  macOS pins those grants to the code signature.

## 0.0.3 — 2026-08-07

### Added

- **Several agents at once.** Every client registers itself, `get_state` lists
  who is online, and the user picks an active one from the menu bar or the
  settings. An optional strict mode locks changes to that agent; everyone else
  keeps reading state and gets a 409 on anything that moves a window.
- Workspace rename.

## 0.0.2 — 2026-08-07

### Added

- Listed on the MCP Registry, Glama and Smithery.
- The demo animation the README opens with.
- `ROADMAP.md`.

## 0.0.1 — 2026-08-07

First release. The menu bar app, snap zones, workspaces, keep-awake,
screenshots, and `plonk-mcp` on npm.
