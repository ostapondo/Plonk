# Plonk + Cursor

Let Cursor's agent arrange your Mac: layouts, workspaces, snap zones,
keep-awake, screenshots.

## Setup

First install the app — [Plonk](https://github.com/ostapondo/plonk#install)
must be running, with Accessibility granted. Node 18+ for the server.

One click:

[![Add plonk to Cursor](https://cursor.com/deeplink/mcp-install-dark.svg)](cursor://anysphere.cursor-deeplink/mcp/install?name=plonk&config=eyJjb21tYW5kIjoibnB4IiwiYXJncyI6WyIteSIsInBsb25rLW1jcCJdfQ==)

Or by hand: add to `~/.cursor/mcp.json` (all projects) or `.cursor/mcp.json`
(one project):

```json
{
  "mcpServers": {
    "plonk": {
      "command": "npx",
      "args": ["-y", "plonk-mcp"]
    }
  }
}
```

Check Cursor Settings → MCP: plonk should show a green dot and its tools.

## Try it

> browser on the left 60%, terminal top right, notes bottom right

> save this as a workspace called "review", then launch it tomorrow morning

> keep the screen awake for the next hour

> screenshot the screen and circle anything misaligned

Cursor alongside other clients is fine — several agents can drive the same
Plonk at once. If a tool call fails with a connection error, the app is not
running or Accessibility was revoked; see the
[README](https://github.com/ostapondo/plonk#install).
