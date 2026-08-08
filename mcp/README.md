# plonk-mcp

The MCP server for [Plonk](https://github.com/ostapondo/plonk), a macOS menu bar
window manager. It lets an agent arrange your desktop: apply layouts across
monitors, save and relaunch workspaces, snap windows into zones, keep the screen
awake, and take and annotate screenshots.

> browser on the left 60%, terminal top right, notes bottom right
>
> save that as a workspace called "review"
>
> screenshot the screen and tell me what looks off

## This package is only half of it

`plonk-mcp` is a thin bridge. The app does the work, and without it every tool
call returns "Plonk menu bar app is not running". Install it first — macOS 13+:

```sh
brew install --cask ostapondo/plonk/plonk
```

Launch it, grant Accessibility when asked, and relaunch once so macOS picks the
grant up. Screen Recording is asked for separately, the first time you capture.

## Then point an agent at it

Node 18+.

```sh
claude mcp add plonk -- npx -y plonk-mcp   # Claude Code
codex mcp add plonk -- npx -y plonk-mcp    # Codex CLI
```

Any MCP client works the same way — give it `npx -y plonk-mcp` as a stdio
server. One-pagers for
[Cursor](https://github.com/ostapondo/plonk/blob/main/docs/clients/cursor.md),
[Zed](https://github.com/ostapondo/plonk/blob/main/docs/clients/zed.md) and
[Cline](https://github.com/ostapondo/plonk/blob/main/docs/clients/cline.md).

A client that cannot spawn a process connects over HTTP instead:
`npx -y plonk-mcp --http` serves Streamable HTTP at
`http://127.0.0.1:43918/mcp` (loopback only, `--port` to change).

Several clients may be connected at once. Set `PLONK_AGENT_NAME` in a client's
config to tell two sessions of the same client apart.

## Tools

| | |
| --- | --- |
| `get_state` | Monitors, every open window and where it sits, zone sets, saved workspaces, awake status |
| `apply_layout` · `snap_window` | Place windows by fraction of a screen, or drop one into a numbered zone |
| `save_workspace` · `launch_workspace` · `delete_workspace` | Named desktops that reopen their apps and restore every window |
| `save_zone_set` · `assign_zone_set` · `delete_zone_set` | Snap zones, assigned per monitor |
| `set_awake` | Keep-awake, optionally time-limited |
| `take_screenshot` · `annotate_screenshot` | Capture, mark up, hand the image back |
| `select_agent` | Make an agent the active one, optionally the only one allowed to control |
| `check_for_update` · `install_update` | Ask GitHub for a newer release and install it |

`save_layout`, `apply_saved_layout` and `delete_layout` are older names kept for
compatibility; they map onto the workspace tools.

Frames are fractions `0..1` of a monitor's visible area with the origin at the
top left, so the left 60% is `{x: 0, y: 0, w: 0.6, h: 1}`.

## Where things run

The server talks to the app over loopback HTTP on `127.0.0.1:43917` and nowhere
else. No account, no cloud, no telemetry. It depends only on the official MCP
SDK and zod.

The app gates that API on a token it writes to
`~/Library/Application Support/Plonk/token`. This server reads the file itself,
so there is nothing to configure — but it does have to run as the same user
Plonk is running as.

MIT. Source, screenshots and the rest of the documentation are in the
[repository](https://github.com/ostapondo/plonk).
