# Contributing

Bug reports, zone sets, client one-pagers and code are all welcome. This page is
the short version; [AGENTS.md](AGENTS.md) is the long one and is worth reading
before you write anything, even though it is addressed to agents. It has the
repo layout, the five places a new module touches, which coordinate space each
number is in, and the mistakes that have already cost someone an hour.

## You do not need a signing certificate

`scripts/build.sh` refuses to run without one, which makes the repo look closed
on first clone. It is not: the certificate is needed only to produce and launch
`Plonk.app`. Everything else works on a plain checkout, and these three commands
are exactly what CI runs:

```sh
cd App && swift build                        # the app compiles
./scripts/test.sh                            # the unit suite
cd mcp && npm ci && npm run typecheck        # the MCP server
```

Zone geometry, config decoding, HTTP routing, MCP tools, voice command parsing,
the CLI and every document in the repo are all reachable from that loop, and
most changes never need more.

To actually run the app, make your own certificate once:

```sh
./scripts/make-signing-cert.sh   # creates one and prints how to trust it
./scripts/build.sh               # produces Plonk.app
open Plonk.app
```

That certificate is yours, not the one releases are signed with, so a local
build will not auto-update and macOS asks for Accessibility and Screen Recording
again the first time it runs. Both are expected. Do not work around `build.sh`
by ad-hoc signing: macOS pins those two permissions to the code signature, an
ad-hoc signature is a different one every build, and the result is a bundle that
looks built and then silently cannot move a window.

## Places to start

- **A one-pager for an MCP client.** `docs/clients/` has Cursor, Zed and Cline.
  Any client that can run a stdio server works; the page is the missing part.
- **A zone set.** If you have drawn a layout you keep going back to, post it
  under Show and tell. Good ones end up shipping as built-ins.
- **A voice command.** `VoiceCommands.swift` maps spoken phrases to actions
  that run in the app, with no agent and no network. Adding a phrase is a small
  change with a unit test next to it in `VoiceCommandTests.swift`.
- **A bug with a reproduction.** Window managers break on hardware nobody else
  has: unusual monitor arrangements, mixed scale factors, apps that fight back.
  A report that says which is often worth more than a patch.
- **A new module.** The seam is described under "Adding a module" in AGENTS.md.
  Open an issue first so two people do not build the same thing.

## Sending a change

- Branch off `main`. Nothing is pushed to `main` directly, including by the
  maintainer.
- Conventional commits: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`.
  Imperative subject under 72 characters, body only when the why is not obvious.
- One logical change per commit, and `swift build` passes on every one of them.
- Put new logic somewhere testable. `ZoneGeometry`, `Config`, `ImageFit`,
  `Router` and `ControlServer.parseIfComplete` exist to be reachable without a
  desktop session; cover what you add in `App/Tests/plonkTests/`.
- A pull request says what changed, why, and which commands you ran.
  Screenshots for anything visual.
- Match the surrounding code. Swift API design guidelines, comments only for
  constraints that are not obvious from the code, no emoji anywhere including
  user-facing strings, and user-facing text in English.

If a change touches the network, the permissions, the entitlements or the update
path, it makes a claim in `README.md` or `SECURITY.md` false. Fix the document
in the same commit. Those claims are meant to be checkable from a terminal, and
that is the only reason they are worth anything.

## Reporting a bug

Use the bug template. The three things that decide whether a window bug is
reproducible are the macOS version, the monitor arrangement, and which app owned
the window, so the template asks for all three.

The fastest way to show what your desk looked like is the state route. It is
gated on the API token like everything else, so pass it:

```sh
curl -s -H "X-Plonk-Token: $(cat ~/Library/'Application Support'/Plonk/token)" \
  127.0.0.1:43917/state
```

It lists the title of every open window, so read it before you paste it. `plonk
state` prints the same thing and finds the token for you.

## Security

Do not open a normal issue for something exploitable. `SECURITY.md` has the
reporting route, and the same page describes the boundaries the app is supposed
to hold, which is the useful thing to check a finding against.

## What this project will not take

Some directions are settled, and a pull request in them will be declined however
good it is:

- Accounts, cloud sync, telemetry, analytics or crash reporting.
- Third-party Swift dependencies in `App/`.
- Any outbound connection other than the existing update check.
- CORS headers on the local API, or binding it to anything but loopback.

`ROADMAP.md` has the rest, including the features that were considered and
deliberately left out.
