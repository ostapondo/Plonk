# Roadmap

No dates, just order. Things ship when they're ready. Ideas and votes go to
[issues](https://github.com/ostapondo/plonk/issues).

## Now

- **Spoken replies** — short confirmations back after a command, optional and
  off by default. The rest of the voice side is below.

Voice → command shipped: "snap this left", "zone three", "put it back", "keep
awake for an hour", "launch my review workspace" run in the app, with no agent,
no round trip and no network. Anything less clear-cut — two clauses, a
percentage, an app named by hand, awake *until* a build finishes — still goes to
the agent, because guessing at those is worse than the round trip. Off with one
toggle on the Voice page.

Auto-updates shipped, without Sparkle: the Updates page checks GitHub, and
installing swaps in a build only when it is signed with the same certificate as
the running copy. That check is what macOS uses for Accessibility and Screen
Recording too, so an update keeps the permissions the user already granted. The
check is one call to api.github.com, carries no identifier, and can be turned
off.

## Next — any agent, not just one

Plonk speaks MCP, so it already isn't married to Claude. Shipped so far:
several clients connected at once, an agent registry with per-client identity,
an active-agent selector (menu bar, settings, or the `select_agent` tool), an
optional "only the active agent controls" mode, and a Streamable HTTP
transport (`plonk-mcp --http`) for clients that can't spawn a process.

Also shipped: a channel from Plonk to the active agent (`/agents/ask` →
long-polled inbox → MCP sampling, with CLI adapters as the fallback), and live
state — `GET /events` streams `{"rev","what"}` server-sent events while `rev`
rides in `/state`, so agents notice what the user and other agents just did.

## Shipped since

Borrowed from PowerToys, where a decade of Windows power users have already
argued about what a window manager owes them, and rebuilt for the Mac:

- **Excluded apps** — a list Plonk keeps its hands off. Every PowerToys module
  has one; Plonk had none, which made drag snapping all-or-nothing.
- **Zones by number** (`⌃⌥1`–`⌃⌥9`) and **put it back** (`⌃⌥0`), which restores
  the frame a window had before Plonk first moved it.
- **Spanning** two zones with `⌘` held during a drag.
- **Focus by geometry** — step to the window that is actually to the left, or
  cycle through the ones stacked in a zone, instead of alt-tabbing by recency.
- **Windows return after a display change**, on the monitor they were placed on.
- **A screen ruler** (`⌃⌥R`, `measure_screen`, `plonk measure`) — how far the
  pointer can travel each way before the pixels change, drawn as two dimension
  lines, and the distance between two points. macOS ships nothing like it:
  `⌘⇧4` shows the size of a drag and finds no edges.
- **Text off the screen** (`⌃⌥T`, `extract_text`, `plonk text`) — Vision,
  on-device. The agent side hands back a box per line in the same coordinates
  annotations are drawn in, so what was read can be pointed at.
- **Keep-awake that ends by itself** — at a wall-clock time, or when a process
  exits: `plonk awake while npm run build`.
- **A `plonk` CLI** over the same loopback API, for scripts and Makefiles.
- **Grab and move** — hold a key and drag a window from anywhere inside it,
  right-drag to resize from the nearest edge. Off by default.
- **Zone appearance** — gap, colour, opacity, numbers, and every monitor's
  zones shown at once. The gap is real: a snapped window keeps that space.
- **Spanning by hovering** the line between two zones, as well as with ⌘.
- **Zone-set shortcuts**, and windows that follow their zone number when a set
  is edited or swapped.
- **New windows** land where that app's last one went.
- **Pointer tools** — find it, ring every click, crosshairs, jump between
  screens.
- **Pin part of the screen** above everything, live or frozen.
- **A shortcut guide** read from the front app's own menus, so it cannot go
  stale.
- **Keyboard editing** in the zone editor.

What is deliberately not here: pinning another app's window on top (no public
API, and the private one is not worth the promise it would break), switching
the system theme on a schedule (it costs an Automation permission this app
does not ask for), and external-monitor brightness (the Apple Silicon path is
half-private IOKit and breaks per hub).

## Voice

Push-to-talk shipped: hold `⌃⌥V` (rebindable on the Voice page), say it, let
go. Recognition runs on the Mac — nothing leaves it — and the transcript goes
to the active agent over the agents channel: "browser left, terminal right,
save it as review" — unless it is one of the common commands, which run in the
app. Still to come:

- **Spoken replies** — short confirmations back, optional and off by default.

## Not planned

- Accounts, cloud sync, telemetry. Everything stays on your Mac.
- **Notarized builds.** Notarizing needs a Developer ID certificate, and Apple
  issues those only to paid Developer Program members. Plonk is signed with a
  self-signed certificate instead, so macOS holds a hand-downloaded copy on
  first launch; installing with Homebrew avoids that. What notarization buys is
  Apple vouching for the build. What this repo offers instead is a build you
  can check yourself, against the commit it was made from — see
  [SECURITY.md](SECURITY.md). If that trade ever stops making sense, this entry
  moves.
