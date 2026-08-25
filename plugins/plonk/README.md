# Plonk, as a Claude Code plugin

Two commands instead of finding a JSON config and restarting the client:

```sh
/plugin marketplace add ostapondo/plonk
/plugin install plonk@plonk
```

That registers the MCP server, and Claude Code starts it whenever the plugin is
enabled. The twenty tools then appear scoped as `mcp__plugin_plonk_plonk__*`,
which matters if you write hooks against them.

## It needs the app

The plugin is a bridge, not the thing itself. The server talks to Plonk over a
loopback API on your own Mac, so the app has to be installed and running or
every call fails with nothing listening:

```sh
brew install --cask ostapondo/plonk/plonk
```

Grant Accessibility when it asks, then relaunch. Screen Recording is asked for
separately, the first time you capture.

## What it does not do

Nothing leaves the machine. There is no account, no cloud and no telemetry, and
the server holds no state of its own — the app is the single source of truth.
The zones, workspaces, OCR, keep-awake and voice all work with the MCP server
switched off; this plugin only adds a fourth way in, next to drag, shortcut and
voice.

[Tools and arguments](../../docs/agents.md) · [Zones](../../docs/zones.md) ·
[Workspaces](../../docs/workspaces.md)
