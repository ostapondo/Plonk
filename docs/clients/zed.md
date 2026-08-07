# Plonk + Zed

Let Zed's agent arrange your Mac: layouts, workspaces, snap zones, keep-awake,
screenshots.

## Setup

First install the app — [Plonk](https://github.com/ostapondo/plonk#install)
must be running, with Accessibility granted. Node 18+ for the server.

Add to Zed's `settings.json` (`zed: open settings`, or
`~/.config/zed/settings.json`):

```json
{
  "context_servers": {
    "plonk": {
      "source": "custom",
      "command": "npx",
      "args": ["-y", "plonk-mcp"]
    }
  }
}
```

Zed restarts context servers on save — no editor restart needed. In the Agent
Panel settings, plonk should show a green "Server is active" dot.

## Try it

> browser on the left 60%, terminal top right, notes bottom right

> save this as a workspace called "review", then launch it tomorrow morning

> keep the screen awake for the next hour

> screenshot the screen and circle anything misaligned

Zed alongside other clients is fine — several agents can drive the same Plonk
at once. If a tool call fails with a connection error, the app is not running
or Accessibility was revoked; see the
[README](https://github.com/ostapondo/plonk#install).
