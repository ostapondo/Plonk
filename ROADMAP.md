# Roadmap

No dates, just order. Things ship when they're ready. Ideas and votes go to
[issues](https://github.com/ostapondo/plonk/issues).

## Now

- **Notarized builds** — no more "Open Anyway" dance on first launch.
- **Auto-updates** — Sparkle, so 0.0.x fixes reach you without re-downloading.

## Next — any agent, not just one

Plonk speaks MCP, so it already isn't married to Claude. Making that real in
practice:

- **First-class setup for other clients** — Cursor, Windsurf, Zed, Cline,
  anything that talks MCP. One-liner install docs for each.
- **Multiple agents at once** — several clients connected to the same app,
  each seeing live state. No lock, no "who's driving" conflicts.
- **HTTP transport** — connect over local HTTP/SSE, not just stdio, so agents
  that can't spawn a process can still drive the desktop.

## Later — voice

- **Push-to-talk** — hold a hotkey, say it, release. Local speech recognition,
  nothing leaves the Mac.
- **Voice → agent** — what you said goes to whichever agent is connected, and
  the agent drives Plonk as usual: "browser left, terminal right, save it as
  review".
- **Voice → command** — common actions ("snap this left", "keep awake an hour")
  run directly, no agent in the loop, so they work offline and instantly.
- **Spoken replies** — short confirmations back, optional and off by default.

## Not planned

- Accounts, cloud sync, telemetry. Everything stays on your Mac.
