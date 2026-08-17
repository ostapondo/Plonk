# For agents

This is the part no other Mac window manager has. Plonk exposes its whole
surface over MCP, so an agent can read the desk, rearrange it, save the result
and read the screen back — without a screenshot round trip for anything that is
really just words.

Frames are fractions of a monitor's visible area, origin top-left — which is why
"left 60%" is just `{x: 0, y: 0, w: 0.6, h: 1}`.

<p align="center">
  <img src="agent-desk.svg" alt="A sentence typed to an agent becomes a desk: the browser takes the left 0.6 of the screen, the terminal the top right and the notes the bottom right, and the result is saved as a workspace called review" width="720">
</p>

## The tools

| Tool | |
| --- | --- |
| `get_state` | Monitors, every open window and where it sits, zone sets, saved workspaces, awake status |
| `apply_layout` | Place any set of windows, across any number of monitors, in one call |
| `save_workspace` · `launch_workspace` · `delete_workspace` | Named desktops, launched from nothing |
| `snap_window` | Drop a window into a numbered zone |
| `save_zone_set` · `assign_zone_set` · `delete_zone_set` | Snap zones, per monitor |
| `set_awake` | Keep-awake — for N minutes, until a time, or until a process exits |
| `set_active` | Stay active — resets the idle timer so chat apps do not show Away |
| `take_screenshot` · `annotate_screenshot` | Capture, mark up, hand the image back — `mode: "app"` photographs one named window even when it is buried, without raising it |
| `extract_text` | Read the words off the screen and hand back text, with a box for every line in the same coordinates `annotate_screenshot` draws in |
| `measure_screen` | How far a point can go each way before it meets an edge, or the distance between two points, in points and pixels — no image, no eyeballing |
| `select_agent` | Make an agent the user's active one, optionally the only one allowed to control |

## Several agents at once

Every client registers itself, so `get_state` lists who is online; the user
picks an active agent from the menu bar or the settings — or an agent does it
with `select_agent`. An optional strict mode locks changes to the active agent:
everyone else keeps reading state and taking screenshots, but gets a clear 409
on anything that moves windows or edits config. Set `PLONK_AGENT_NAME` in a
client's MCP config to tell two sessions of the same client apart.

## Connecting

```sh
claude mcp add plonk -- npx -y plonk-mcp   # Claude Code
codex mcp add plonk -- npx -y plonk-mcp    # Codex CLI
```

Any MCP client works the same way — give it `npx -y plonk-mcp` as a stdio
server. One-pagers: [Cursor](clients/cursor.md) (with a one-click install
button), [Zed](clients/zed.md), [Cline](clients/cline.md).

A client that cannot spawn a process connects over HTTP instead:
`npx -y plonk-mcp --http` serves Streamable HTTP at
`http://127.0.0.1:43918/mcp` (loopback only, many clients per process,
`--port` to change). That port asks for the same token the app does, so give
the client an `X-Plonk-Token` header holding the contents of
`~/Library/Application Support/Plonk/token` — otherwise the transport would be
a way around the gate rather than through it.

## From a shell

The same package carries a `plonk` command, for the things that are neither an
agent nor a settings window — a Makefile, a Raycast script, a shell alias.
`npm i -g plonk-mcp`, then:

```sh
plonk state                      # screens, zone sets, workspaces, windows
plonk launch review              # a saved workspace
plonk awake while npm run build  # awake for exactly as long as the build
plonk text | pbcopy              # OCR a region straight into the clipboard
plonk measure 0.5 0.5            # size of whatever is in the middle of the screen
```

---

[README](../README.md) · [Check it yourself](verify.md)
