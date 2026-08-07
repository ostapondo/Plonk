# Installing Plonk (for AI agents)

You are setting up Plonk for a user on macOS. Plonk is two pieces: a menu bar
app that owns the windows, and an MCP server that lets you talk to it. Both are
needed — the server alone does nothing.

## 1. Install the app

macOS 13 or newer. Ask the user to run:

```sh
brew install --cask ostapondo/plonk/plonk
```

If they do not use Homebrew, point them at
<https://github.com/ostapondo/plonk/releases/latest>: download the zip, unzip,
drag `Plonk.app` into `/Applications`. The build is not notarized yet, so the
first launch is blocked — they approve it under System Settings → Privacy &
Security → Open Anyway.

## 2. Permissions — the user must do this, you cannot

On first launch Plonk asks for Accessibility. macOS only picks the grant up
after a relaunch, so tell the user: grant it, then quit and reopen Plonk.
Screen Recording is asked for separately, the first time a screenshot is taken.
Nothing else is needed.

Two failure modes worth knowing:

- Windows of newly launched apps are invisible to Plonk → the Accessibility
  grant is tied to the old path because the app was moved or renamed. Fix:
  remove Plonk from Privacy & Security → Accessibility, add it again.
- Every tool call fails to connect → the app is not running. Launch it.

## 3. Add the MCP server

Node 18 or newer. The server is on npm as `plonk-mcp`, run over stdio:

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

Client-specific one-pagers live in
[docs/clients](https://github.com/ostapondo/plonk/tree/main/docs/clients)
(Cursor, Zed, Cline). For Claude Code and Codex the one-liners are
`claude mcp add plonk -- npx -y plonk-mcp` and
`codex mcp add plonk -- npx -y plonk-mcp`.

A client that cannot spawn a process uses HTTP instead: run
`npx -y plonk-mcp --http` and point it at `http://127.0.0.1:43918/mcp`.

No API keys, no accounts, no environment variables. Several clients may be
connected at once.

## 4. Verify

Call `get_state`. A working setup returns the monitors, the visible windows,
and any saved workspaces and zone sets. If it returns a connection error, go
back to step 2.
