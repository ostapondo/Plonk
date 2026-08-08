# Changelog

What changed in each release, from a user's side. The commit log has the rest.

Versions before 0.1.0 shipped in two days and are summarized rather than
itemized. The dates are real; the tidiness is not — most of what is listed
under 0.0.4 was written the same afternoon it went out.

Releases up to and including 0.0.4 were zipped by hand and carry no build
attestation, so `gh attestation verify` fails on them. That is the whole reason
[the release workflow](.github/workflows/release.yml) exists now. Do not install
one of those.

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
