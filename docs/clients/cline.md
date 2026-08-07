# Plonk + Cline

Let Cline arrange your Mac: layouts, workspaces, snap zones, keep-awake,
screenshots.

## Setup

First install the app — [Plonk](https://github.com/ostapondo/plonk#install)
must be running, with Accessibility granted. Node 18+ for the server.

In VS Code, open Cline → MCP Servers icon → Installed → Configure MCP Servers,
and add:

```json
{
  "mcpServers": {
    "plonk": {
      "command": "npx",
      "args": ["-y", "plonk-mcp"],
      "disabled": false
    }
  }
}
```

Cline reloads the file on save; plonk appears in the Installed list with its
tools.

## Try it

> browser on the left 60%, terminal top right, notes bottom right

> save this as a workspace called "review", then launch it tomorrow morning

> keep the screen awake for the next hour

> screenshot the screen and circle anything misaligned

Cline alongside other clients is fine — several agents can drive the same
Plonk at once. If a tool call fails with a connection error, the app is not
running or Accessibility was revoked; see the
[README](https://github.com/ostapondo/plonk#install).
