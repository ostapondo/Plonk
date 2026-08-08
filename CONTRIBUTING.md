# Contributing

Bug reports, zone sets, client one-pagers and code are all welcome.

Two things worth saying before anything else, because both are usually left to
be guessed at:

**You will get an answer within three days.** If a pull request sits longer than
that, it is an oversight rather than a verdict — say so on the thread. A change
that is not going to land will be told so quickly, and why.

**Your branch is yours.** Review comments will ask for changes rather than push
them. If a pull request is nearly there and you would rather it were finished
for you than iterated on, say so and it will be; otherwise nothing is pushed to
your branch.

Everyone taking part is expected to follow the
[Code of Conduct](CODE_OF_CONDUCT.md).

## Your first change, in about fifteen minutes

You do not need a signing certificate, an Apple account, or the app running.

```sh
git clone https://github.com/ostapondo/plonk && cd plonk
(cd App && swift build)                    # the app compiles
./scripts/test.sh                          # the unit suite
./scripts/lint.sh                          # style rules, no dependencies
(cd mcp && npm ci && npm test)             # the MCP server
```

Each line is a subshell, so the block runs as written from the repository root.
That is exactly what CI runs, and if it passes, the mechanical half of review is
already done.

Now pick something. [Issue #21][21] is a good one to read first: `plonk state`
tells a person to "ask the user to launch Plonk.app" — which, in a shell, means
asking themselves. The fix is a message in `mcp/src/api.ts`, a test in
`mcp/test/`, and `npm test`. Nothing else.

That is the shape of most of the work here: one file, one seam, one test.

[21]: https://github.com/ostapondo/plonk/issues/21

## Where the work is

- **[good first issue][gfi]** — written to be picked up cold. Each says where
  the code is and how to tell it worked.
- **[reserved][res]** — issues deliberately left alone. If one is labelled
  `reserved-for-contributors`, the maintainer is not working on it and will not
  start; it is yours if you say so on the thread. Nothing here moves fast enough
  to be worth racing.
- **[needs-hardware][hw]** — see below. The single most useful thing you can
  send, and it needs neither Swift nor a certificate.
- **A one-pager for an MCP client.** `docs/clients/` has Cursor, Zed and Cline.
  Any client that can run a stdio server works; the page is the missing part.
- **A zone set.** If you have drawn a layout you keep going back to, post it
  under Show and tell. Good ones end up shipping as built-ins.
- **A voice command.** `VoiceCommands.swift` maps spoken phrases to actions that
  run in the app, with no agent and no network. Adding a phrase is a small
  change with a unit test next to it in `VoiceCommandTests.swift`.
- **A file off `scripts/line-limit-baseline`.** Every line in that file is a
  type waiting to be lifted out of something too big. [Issue #17][17] is the
  first one, and it comes with tests that cannot be written until it moves.
- **A new module.** The seam is described under "Adding a module" in
  [AGENTS.md](AGENTS.md). Open an issue first so two people do not build the
  same thing.

[gfi]: https://github.com/ostapondo/plonk/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22
[res]: https://github.com/ostapondo/plonk/issues?q=is%3Aissue+is%3Aopen+label%3Areserved-for-contributors
[hw]: https://github.com/ostapondo/plonk/issues?q=is%3Aissue+is%3Aopen+label%3Aneeds-hardware
[17]: https://github.com/ostapondo/plonk/issues/17

## Hardware nobody here has

This is the honest weak point of the project, and the easiest place to help.

A window manager breaks on arrangements the author cannot see: three monitors,
an ultrawide, a Retina screen beside a 1x one, a display that comes and goes,
Sidecar, a vertical panel. Placement needs a real desktop session, so none of it
is reachable from the unit suite — the whole of `App/Tests/plonkTests/` runs
without one on purpose.

So a report from a desk that is not this one is worth more than a patch. The
[needs-hardware][hw] label is exactly that list, and answering one means running
a few shortcuts and pasting what happened.

`scripts/testbench.sh` opens throwaway TextEdit windows so you never have to
move your real ones:

```sh
./scripts/testbench.sh up 4     # four windows with known titles
./scripts/testbench.sh state    # where each one landed, as fractions
./scripts/testbench.sh down     # close them, delete the files
```

Fractions rather than pixels, because those travel between machines. The pull
request template has the six arrangements worth running through, and you are not
expected to own all six — tick what you ran and write "no hardware" against the
rest.

## Running the app

Only needed to change something you can see. Make your own certificate once:

```sh
./scripts/make-signing-cert.sh   # creates one and prints how to trust it
./scripts/build.sh               # produces Plonk.app
open Plonk.app
```

That certificate is yours, not the one releases are signed with, so a local
build will not auto-update and macOS asks for Accessibility and Screen Recording
again the first time it runs. Both are expected.

Do not work around `build.sh` by ad-hoc signing. macOS pins those two
permissions to the code signature, an ad-hoc signature is a different one every
build, and the result is a bundle that looks built and then silently cannot move
a window.

## Sending a change

- Branch off `main`. Nothing is pushed to `main` directly, including by the
  maintainer.
- **The pull request title is a sentence, and it does not have to be clever.**
  `fix: nil display UUID after unplug` is a good title. So is `Add a setup page
  for Windsurf`. The essayistic subjects in `git log` on `main` are one person's
  habit, not a standard anyone is held to.
- Conventional commits on your branch: `feat:`, `fix:`, `docs:`, `chore:`,
  `refactor:`. Imperative subject under 72 characters, body only when the why is
  not obvious. A pull request with more than one commit is squashed under its
  title, which is why `main` has subjects with no prefix.
- One logical change per commit, and `swift build` passes on every one of them.
- Put new logic somewhere testable. `ZoneGeometry`, `Config`, `ImageFit`,
  `Router` and `ControlServer.parseIfComplete` exist to be reachable without a
  desktop session; cover what you add in `App/Tests/plonkTests/` or `mcp/test/`.
- A pull request says what changed, why, and which commands you ran.
  Screenshots for anything visual.
- Match the surrounding code. Swift API design guidelines, comments only for
  constraints that are not obvious from the code, no emoji anywhere including
  user-facing strings, and user-facing text in English. `./scripts/lint.sh`
  checks the part of that a script can check, so style is not something to find
  out about at review time.

If a change touches the network, the permissions, the entitlements or the update
path, it makes a claim in `README.md` or `SECURITY.md` false. Fix the document in
the same commit. Those claims are meant to be checkable from a terminal, and that
is the only reason they are worth anything.

[AGENTS.md](AGENTS.md) is the long version of all of this: the repo layout, the
five places a new module touches, which coordinate space each number is in, and
the mistakes that have already cost someone an hour. It is phrased as
instructions to an agent because that is what most often reads it, but it is the
engineering guide either way. Read it before a second change, not before a
first.

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
good it is. This list exists so nobody spends a weekend on one:

- Accounts, cloud sync, telemetry, analytics or crash reporting.
- Third-party Swift dependencies in `App/`.
- Any outbound connection other than the existing update check.
- CORS headers on the local API, or binding it to anything but loopback.

Everything outside that list is open, including things already built. If you
think a decision here is wrong, the place to say so is a
[discussion](https://github.com/ostapondo/plonk/discussions), and it will get a
real answer rather than a link back to this page.

`ROADMAP.md` has the rest, including the features that were considered and
deliberately left out.
