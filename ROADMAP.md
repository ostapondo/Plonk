# Roadmap

No dates, just order. Things ship when they're ready. Ideas and votes go to
[issues](https://github.com/ostapondo/plonk/issues).

## Now

- **Notarized builds** — no more "Open Anyway" dance on first launch.
- **Auto-updates** — Sparkle, so 0.0.x fixes reach you without re-downloading.

## Next — any agent, not just one

Plonk speaks MCP, so it already isn't married to Claude. Shipped so far:
several clients connected at once, an agent registry with per-client identity,
an active-agent selector (menu bar, settings, or the `select_agent` tool), an
optional "only the active agent controls" mode, and a Streamable HTTP
transport (`plonk-mcp --http`) for clients that can't spawn a process.

Also shipped: a channel from Plonk to the active agent (`/agents/ask` →
long-polled inbox → MCP sampling, with CLI adapters as the fallback), and live
state — `GET /events` streams `{"rev","what"}` server-sent events while `rev`
rides in `/state`, so agents notice what the user and other agents just did.

## Voice

Push-to-talk shipped: hold `⌃⌥V` (rebindable on the Voice page), say it, let
go. Recognition runs on the Mac — nothing leaves it — and the transcript goes
to the active agent over the agents channel: "browser left, terminal right,
save it as review". Still to come:

- **Voice → command** — common actions ("snap this left", "keep awake an hour")
  run directly, no agent in the loop, so they work offline and instantly.
- **Spoken replies** — short confirmations back, optional and off by default.

## Not planned

- Accounts, cloud sync, telemetry. Everything stays on your Mac.
