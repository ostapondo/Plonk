# Roadmap

No dates, just order. Things ship when they're ready. Ideas and votes go to
[issues](https://github.com/ostapondo/plonk/issues).

## Now

- **Notarized builds** — no more "Open Anyway" dance on first launch.
- **Auto-updates** — Sparkle, so 0.0.x fixes reach you without re-downloading.

## Next — any agent, not just one

Plonk speaks MCP, so it already isn't married to Claude. Shipped so far:
several clients connected at once, an agent registry with per-client identity,
an active-agent selector (menu bar, settings, or the `select_agent` tool), and
an optional "only the active agent controls" mode.

Still to do:

- **HTTP transport** — connect over local HTTP, not just stdio, so agents that
  can't spawn a process (the ChatGPT desktop app among them) can still drive
  the desktop.
- **Live state** — push changes to every connected client instead of each one
  polling `/state`, so agents see what the user and other agents just did.
- **Reaching the agent** — a channel from Plonk to the active agent, so voice
  and hotkeys have somewhere to send what you said.

## Later — voice

- **Push-to-talk** — hold a hotkey, say it, release. Local speech recognition,
  nothing leaves the Mac.
- **Voice → agent** — what you said goes to the active agent from the selector,
  and the agent drives Plonk as usual: "browser left, terminal right, save it
  as review".
- **Voice → command** — common actions ("snap this left", "keep awake an hour")
  run directly, no agent in the loop, so they work offline and instantly.
- **Spoken replies** — short confirmations back, optional and off by default.

## Not planned

- Accounts, cloud sync, telemetry. Everything stays on your Mac.
