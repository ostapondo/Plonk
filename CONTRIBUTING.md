# Contributing

Bug reports, zone sets, client one-pagers and code are all welcome. You do not
need a signing certificate, an Apple account, or the app running.

What you can expect:

- **A real answer within 48 hours**, even if the answer is that it needs another
  week of thought. There is one maintainer, so that is a promise about attention,
  not speed. If something sits longer, it is an oversight. Say so on the thread.
- **A change that is declined is declined with the reason.** "What this project
  will not take" below exists so that happens as rarely as possible.
- **Your branch is yours.** Review asks for changes rather than pushing them. If
  a pull request is nearly there and you would rather it were finished for you,
  say so and it will be.
- Anyone whose change lands is listed in the release notes it ships in.

Everyone taking part follows the [Code of Conduct](CODE_OF_CONDUCT.md).

## Get it building

```sh
git clone https://github.com/ostapondo/plonk && cd plonk
(cd App && swift build)                    # the app compiles
./scripts/test.sh                          # the unit suite
./scripts/lint.sh                          # style rules, no dependencies
(cd mcp && npm ci && npm test)             # the MCP server
node scripts/check-zone-sets.mjs           # the layouts in zone-sets/
```

Each line is a subshell, so the block runs as written from the repository root.
That is exactly what CI runs. If it passes, the mechanical half of review is
already done.

## Pick something

If you want one handed to you: [issue #21][21]. `plonk state` tells a person to
"ask the user to launch Plonk.app", which, in a shell, means asking themselves.
The fix is a message in `mcp/src/api.ts`, a test in `mcp/test/`, and `npm test`.
Nothing else. That is the shape of most of the work here: one file, one seam, one
test.

The rest, roughly in order of how much of the repo you have to hold in your head.
The first two need no Swift at all. The third needs no Swift on your machine.

- **A zone set.** One JSON file in [`zone-sets/`](zone-sets/), a gallery of
  layouts people keep going back to. Draw it in the app, read the numbers out of
  `plonk state --json`, drop them in a file. That folder has its own CI job and
  answers in about twenty seconds. Good ones ship as built-ins.
  [`zone-sets/README.md`](zone-sets/README.md) has the format.
- **[needs-hardware][hw].** See below. The single most useful thing you can send.
- **Something in `mcp/`.** The MCP server and the `plonk` CLI are TypeScript, a
  thin proxy over the app's HTTP API. They build and test anywhere, Linux
  included, with no Mac in sight. `npm ci && npm test` in `mcp/` is the whole
  loop.
- **A one-pager for an MCP client.** `docs/clients/` has Cursor, Zed and Cline.
  Any client that runs a stdio server works; the page is the missing part.
- **A voice command.** `VoiceCommands.swift` maps spoken phrases to actions that
  run in the app, with no agent and no network. Adding a phrase is a small change
  with a unit test next to it in `VoiceCommandTests.swift`. The parser is pure,
  so the tests need no desktop session.
- **A file off `scripts/line-limit-baseline`.** Every line in that file is a type
  waiting to be lifted out of something too big. [Issue #17][17] is the first,
  and it comes with tests that cannot be written until it moves.
- **A new module.** The seam is under "Adding a module" in [AGENTS.md](AGENTS.md).
  Open an issue first so two people do not build the same thing.

Issues tagged **[good first issue][gfi]** name the file to open, what done looks
like, and the command that proves it. Comment on one to claim it.

Issues tagged **[reserved][res]** are deliberately left alone: the maintainer is
not working on them and will not start. Say so on the thread and it is yours.

[gfi]: https://github.com/ostapondo/plonk/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22
[res]: https://github.com/ostapondo/plonk/issues?q=is%3Aissue+is%3Aopen+label%3Areserved-for-contributors
[hw]: https://github.com/ostapondo/plonk/issues?q=is%3Aissue+is%3Aopen+label%3Aneeds-hardware
[17]: https://github.com/ostapondo/plonk/issues/17
[21]: https://github.com/ostapondo/plonk/issues/21

## Hardware nobody here has

This is the honest weak point of the project, and the easiest place to help.

A window manager breaks on arrangements the author cannot see: three monitors,
an ultrawide, a Retina screen beside a 1x one, a display that comes and goes,
Sidecar, a vertical panel. Placement needs a real desktop session, so none of it
is reachable from the unit suite. `App/Tests/plonkTests/` runs without one on
purpose.

A report from a desk that is not this one is worth more than a patch. The
[needs-hardware][hw] label is that list, and answering one means running a few
shortcuts and pasting what happened.

`scripts/testbench.sh` opens throwaway TextEdit windows so you never have to
move your real ones:

```sh
./scripts/testbench.sh up 4     # four windows with known titles
./scripts/testbench.sh state    # where each one landed, as fractions
./scripts/testbench.sh down     # close them, delete the files
```

Fractions rather than pixels, because those travel between machines. The pull
request template lists six arrangements worth running through. You are not
expected to own all six: tick what you ran, write "no hardware" against the rest.

## Running the app

Only needed to change something you can see. Make your own certificate once:

```sh
./scripts/make-signing-cert.sh   # creates one and prints how to trust it
./scripts/build.sh               # produces Plonk.app
open Plonk.app
```

That certificate is yours, not the one releases are signed with, so a local build
will not auto-update and macOS asks for Accessibility and Screen Recording again
the first time it runs. Both are expected.

Do not work around `build.sh` with ad-hoc signing. macOS pins those two
permissions to the code signature, an ad-hoc signature is different every build,
and the result is a bundle that looks built and then silently cannot move a
window.

## Sending a change

- Branch off `main`. Nothing is pushed to `main` directly, including by the
  maintainer.
- **The title is a sentence, and it does not have to be clever.** `fix: nil
  display UUID after unplug` is a good title. So is `Add a setup page for
  Windsurf`. The essayistic subjects in `git log` are one person's habit, not a
  standard anyone is held to.
- Conventional commits on your branch: `feat:`, `fix:`, `docs:`, `chore:`,
  `refactor:`. Imperative subject under 72 characters, body only when the why is
  not obvious. A pull request with more than one commit is squashed under its
  title.
- One logical change per commit, and `swift build` passes on every one.
- Put new logic somewhere testable. `ZoneGeometry`, `Config`, `ImageFit`,
  `Router` and `ControlServer.parseIfComplete` exist to be reachable without a
  desktop session. Cover what you add in `App/Tests/plonkTests/` or `mcp/test/`.
- Say what changed, why, and which commands you ran. Screenshots for anything
  visual.
- Match the surrounding code: Swift API design guidelines, comments only for
  constraints the code does not show, no emoji anywhere including user-facing
  strings, user-facing text in English. `./scripts/lint.sh` checks the part a
  script can check.

A change that touches the network, the permissions, the entitlements or the
update path makes a claim in `README.md` or `SECURITY.md` false. Fix the document
in the same commit. Those claims are meant to be checkable from a terminal, and
that is the only reason they are worth anything.

[AGENTS.md](AGENTS.md) is the long version: the repo layout, the five places a
new module touches, which coordinate space each number is in, and the mistakes
that have already cost someone an hour. It is phrased as instructions to an agent
because that is what most often reads it, but it is the engineering guide either
way. Read it before a second change, not a first.

## Reporting a bug

Use the bug template. The three things that decide whether a window bug is
reproducible are the macOS version, the monitor arrangement, and which app owned
the window, so the template asks for all three.

The fastest way to show what your desk looked like is `plonk state`, which finds
the API token for you. The raw route, if you would rather not install the CLI:

```sh
curl -s -H "X-Plonk-Token: $(cat ~/Library/'Application Support'/Plonk/token)" \
  127.0.0.1:43917/state
```

It lists the title of every open window, so read it before you paste it.

## Security

Do not open a normal issue for something exploitable. `SECURITY.md` has the
reporting route, and describes the boundaries the app is supposed to hold, which
is the useful thing to check a finding against.

## What this project will not take

Some directions are settled, and a pull request in them will be declined however
good it is. This list exists so nobody spends a weekend on one.

- Accounts, cloud sync, telemetry, analytics or crash reporting.
- Third-party Swift dependencies in `App/`.
- Any outbound connection other than the existing update check.
- CORS headers on the local API, or binding it to anything but loopback.

Everything outside that list is open, including things already built. If you
think a decision here is wrong, say so in a
[discussion](https://github.com/ostapondo/plonk/discussions) and it will get a
real answer rather than a link back to this page.

`ROADMAP.md` has the rest, including features that were considered and
deliberately left out.
