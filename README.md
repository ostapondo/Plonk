<h1 align="center">Plonk</h1>

<p align="center"><strong>The Mac window manager that puts your desk back together.</strong><br>
<sub>To plonk is to set a thing down exactly where it belongs. This menu bar does it to your
windows — you drag them there, or your agent says where.</sub></p>

<p align="center">
  <img alt="Version" src="https://img.shields.io/badge/version-0.0.4-58a6ff?style=flat-square">
  <img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-111?style=flat-square">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138?style=flat-square">
  <img alt="MCP" src="https://img.shields.io/badge/MCP-18_tools-8957e5?style=flat-square">
  <img alt="No dependencies" src="https://img.shields.io/badge/dependencies-0-2ea043?style=flat-square">
  <img alt="MIT" src="https://img.shields.io/badge/license-MIT-blue?style=flat-square">
</p>

<p align="center">
  <img src="docs/demo.gif" alt="An agent is told where the windows go, arranges them, saves the setup as a workspace, and launches it back onto an empty desktop" width="720">
</p>

Drag a window, the zones light up, drop it in. Or skip the dragging and say it:

> browser on the left 60%, terminal top right, notes bottom right
>
> save that as a workspace called "review"
>
> keep the screen awake for the next hour
>
> screenshot the screen and tell me what looks off

Everything runs on your Mac. No account, no cloud, no telemetry.

## Install

macOS 13+.

```sh
brew install --cask ostapondo/plonk/plonk
```

Or download [the latest release](https://github.com/ostapondo/plonk/releases/latest),
unzip, and drop Plonk.app into Applications. The build is not notarized yet, so
macOS will balk at the first launch — approve it under System Settings → Privacy
& Security → Open Anyway.

Grant Accessibility when asked, then relaunch. Screen Recording is asked for
separately, the first time you capture. Nothing else — no Full Disk Access, no
Automation, no Keychain.

If you later move or rename Plonk.app (or its folder), macOS quietly ties the
old grant to the old path: windows of newly launched apps stop being seen.
Remove Plonk from Privacy & Security → Accessibility and grant it again.

To let an agent drive it (Node 18+):

```sh
claude mcp add plonk -- npx -y plonk-mcp   # Claude Code
codex mcp add plonk -- npx -y plonk-mcp    # Codex CLI
```

Any MCP client works the same way — give it `npx -y plonk-mcp` as a stdio
server. One-pagers: [Cursor](docs/clients/cursor.md) (with a one-click
install button), [Zed](docs/clients/zed.md), [Cline](docs/clients/cline.md).
Several clients at once is fine; see [Agents](#for-agents) below.

A client that cannot spawn a process connects over HTTP instead:
`npx -y plonk-mcp --http` serves Streamable HTTP at
`http://127.0.0.1:43918/mcp` (loopback only, many clients per process,
`--port` to change).

Or build everything from source: clone the repo, run `./scripts/build.sh`, and
point `claude mcp add plonk -- node …/mcp/dist/server.js` at a locally built
server (`cd mcp && npm install && npm run build`).

## Check it yourself

Accessibility is the only way macOS lets one app move another's windows, and
Screen Recording is what a screenshot costs. That is a lot to hand something you
installed a minute ago, so none of this is a promise — it is all checkable.

**One thing dials out, and you can switch it off.** Every socket the app has
open:

```sh
lsof -nP -i -a -p "$(pgrep -f 'Plonk.app/Contents/MacOS/plonk')"
plonk  …  TCP 127.0.0.1:43917 (LISTEN)
```

One listener on loopback. The only outbound connection Plonk makes is the
update check: on launch and once a day it asks `api.github.com` for the latest
release, and sends nothing but a User-Agent naming the app and its version — no
identifier, no account, no analytics, no crash reporter. Turn it off under
Updates and it stops happening — including for agents, which get a 409 rather
than a connection made on your behalf, so the buttons on that page are the only
thing that can trigger one. `nettop` or Little Snitch will then show a process
that only ever listens. The URLs compiled into the app are that endpoint, the
releases page, and the issue tracker that opens when you click Report a bug —
[Release.swift](App/Sources/plonk/Release.swift) has all three.

**A web page cannot drive it.** The API is loopback-only and unauthenticated, so
it refuses anything carrying headers a browser cannot suppress:

```sh
curl -so /dev/null -w '%{http_code}\n' -H 'Origin: https://example.com' \
  http://127.0.0.1:43917/state
403
```

**There is not much else to hide.** [Package.swift](App/Package.swift) declares
no third-party dependencies, so a build from source is this repo and nothing
else. Config is plain JSON at `~/Library/Application Support/Plonk/config.json`.
Screenshots go where you send them. There is no account to make.

The MCP server is a separate npm package that depends only on the official MCP
SDK and zod. It speaks to `127.0.0.1:43917` and nowhere else.

## Workspaces

<p align="center">
  <img src="docs/workspaces.svg" alt="A workspace of four windows, saved, closed to an empty desktop, then launched back into place" width="720">
</p>

A workspace is a desk you can put away. It remembers the apps, the frame of
every window, the monitor each one belongs on, and what each app should open on
the way up. Launching one opens whatever is closed, waits for the windows, and
puts them back — from the Workspaces page, or right-click the menu bar icon.
Rename, recapture or delete from the workspace's `⋯` menu.

| | |
| --- | --- |
| **Per app** | Files, folders or URLs to open with it: a project folder for an editor, a set of tabs for a browser |
| **Per monitor** | Windows return to the display they were captured on, keyed by display UUID so unplugging a monitor does not scramble them. Or pull the whole workspace onto one screen |
| **Already open** | Running apps get moved, not relaunched. Turn that off to leave them alone and only open what is missing |
| **The catch** | macOS cannot open an app straight into a position, so windows appear first and jump a moment later. A second window of the same app cannot be conjured — give it a file to open instead |

## Zones

<p align="center">
  <img src="docs/zones.svg" alt="A screen split into three zones, with a window being dragged into the highlighted one" width="720">
</p>

<p align="center">
  <img src="docs/zone-sets.svg" alt="Five built-in zone sets and a sixth, irregular one drawn by hand" width="720">
</p>

Five sets ship with it. Everything past that you draw yourself: any number of
zones, any size, overlapping if you want — a narrow rail for chat, a wide middle
split in two, a strip for the terminal. Or describe it and let the agent build
it.

| | |
| --- | --- |
| **Editor** | Click to split, `⇧`-click to split vertically, drag a divider to resize neighbours, `✕` to delete and let them heal over the gap |
| **Per monitor** | Each screen gets its own set, remembered by display, not by index |
| **Overlap** | Allowed — the smallest zone under the cursor wins |
| **Trigger** | On drag, or only with a modifier held. Holding it inverts the mode, so a free move stays one keypress away |
| **Or none** | Edge snapping instead: middles are halves, top is maximize, corners are quarters |

## Hotkeys

<p align="center">
  <img src="docs/hotkeys.svg" alt="Where each hotkey puts the front window" width="720">
</p>

<p align="center">
  All on <code>⌃⌥</code>. Plus <code>⌃⌥Z</code> to flash the zones and <code>⌃⌥S</code> to grab a region.
</p>

## And the rest

| | |
| --- | --- |
| **Keep awake** | IOKit power assertions, not a jiggler. Display-on or system-only, pause on battery, auto while charging, timed sessions, and a menu bar icon that glows while it holds |
| **Screenshots** | Region, window or screen through the native picker, then pen, arrow, rectangle, ellipse and highlighter. Saves at native resolution |
| **Notices** | A panel in the top-right corner, not Notification Center: no permission to ask for, nothing left in your history, and it can show the screenshot instead of describing it |
| **Updates** | One button on the Updates page. Plonk installs a build only if it is signed with the same certificate as the copy you are running — which is the same test macOS applies, so your Accessibility and Screen Recording grants carry over instead of being asked for again. Anything that fails the check is discarded and nothing is replaced. Switch the check off and the app never looks |

## For agents

Frames are fractions of a monitor's visible area, origin top-left — which is why
"left 60%" is just `{x: 0, y: 0, w: 0.6, h: 1}`.

| Tool | |
| --- | --- |
| `get_state` | Monitors, every open window and where it sits, zone sets, saved workspaces, awake status |
| `apply_layout` | Place any set of windows, across any number of monitors, in one call |
| `save_workspace` · `launch_workspace` · `delete_workspace` | Named desktops, launched from nothing |
| `snap_window` | Drop a window into a numbered zone |
| `save_zone_set` · `assign_zone_set` · `delete_zone_set` | Snap zones, per monitor |
| `set_awake` | Keep-awake, optionally time-limited |
| `take_screenshot` · `annotate_screenshot` | Capture, mark up, hand the image back |
| `select_agent` | Make an agent the user's active one, optionally the only one allowed to control |

Several agents can be connected at once. Every client registers itself, so
`get_state` lists who is online; the user picks an active agent from the menu
bar or the settings — or an agent does it with `select_agent`. An optional
strict mode locks changes to the active agent: everyone else keeps reading
state and taking screenshots, but gets a clear 409 on anything that moves
windows or edits config. Set `PLONK_AGENT_NAME` in a client's MCP config to
tell two sessions of the same client apart.

## Under the hood

<p align="center">
  <img src="docs/architecture.svg" alt="Claude talks to the MCP server over stdio, which calls the app's loopback HTTP API" width="760">
</p>

- The app is the single source of truth; the MCP server is a stateless bridge.
- The API binds to `127.0.0.1` and refuses anything carrying browser headers, so
  an open web page cannot drive your desktop — see
  [Check it yourself](#check-it-yourself).
- Config is plain JSON at `~/Library/Application Support/Plonk/config.json`.

## Build

```sh
cd App && swift build     # the app
./scripts/test.sh         # 149 unit tests
./scripts/build.sh        # produces Plonk.app
cd mcp && npm run build   # the MCP server
```

`App/` is the Swift menu bar app, `mcp/` the TypeScript MCP server. Point an
agent at [AGENTS.md](AGENTS.md) before it touches either.

`build.sh` signs with a `Plonk Dev` keychain identity and stops if it is
missing. macOS ties Accessibility and Screen Recording to the signature, and an
ad-hoc one changes every build, so create that certificate once (Keychain
Access → Certificate Assistant → Create a Certificate → type "Code Signing",
name it `Plonk Dev`) and rebuilds stop resetting permissions. Set
`PLONK_SIGN_IDENTITY` to sign with a different one.

If a permission was first granted while the app was ad-hoc signed, the old
grant is pinned to a signature that no longer exists and every rebuild looks
like a reset. Clear it once and grant again:

```sh
tccutil reset ScreenCapture dev.plonk.app
tccutil reset Accessibility dev.plonk.app
```

Releases: bump `MARKETING_VERSION` and `BUILD_NUMBER` in
[version.env](version.env). `scripts/build.sh` reads both into `Info.plist`.
`scripts/release.sh` then builds with a Developer ID certificate, notarizes,
staples the ticket into the bundle and writes `Plonk-<version>.zip` with the
sha256 the cask needs. It needs a paid Apple account and stored `notarytool`
credentials, and says how to get both if either is missing.

## License

MIT © [ostapondo](https://github.com/ostapondo)
