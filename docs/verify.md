# Check it yourself

Accessibility is the only way macOS lets one app move another's windows, and
Screen Recording is what a screenshot costs. That is a lot to hand something you
installed a minute ago, so none of this is a promise — it is all checkable.

## The binary comes from the source

Releases are built, signed and zipped by
[a workflow](../.github/workflows/release.yml) on GitHub's runners, never on a
laptop, and ship with a provenance attestation GitHub signs:

```sh
gh attestation verify Plonk-<version>.zip -R ostapondo/plonk
```

That prints the commit and the workflow run the archive was built by. It is the
step that makes reading the rest of this repo worth anything — without it, the
code here and the app on your Mac are two separate claims. (Releases up to and
including 0.0.4 were zipped by hand and carry no attestation, so the command
fails on those. That is the whole reason it exists now.)

The MCP server is published the same way, which matters more, because `npx -y
plonk-mcp` fetches it every time: `npm view plonk-mcp dist.attestations`, or the
Provenance panel on [its npm page](https://www.npmjs.com/package/plonk-mcp).

## One thing dials out, and you can switch it off

Every socket the app has open:

```sh
lsof -nP -i -a -p "$(pgrep -f 'Plonk.app/Contents/MacOS/plonk')"
plonk  …  TCP 127.0.0.1:43917 (LISTEN)
```

One listener on loopback. The only outbound connection Plonk makes is the
update check: on launch and once a day it asks `api.github.com` for the latest
release, and sends nothing but a User-Agent naming the app and its version — no
identifier, no account, no analytics, no crash reporter. A check that failed
for want of a network runs again when one comes back, which is the only thing
the app watches the network path for. Turn it off under
Updates and it stops happening — including for agents, which get a 409 rather
than a connection made on your behalf, so the buttons on that page are the only
thing that can trigger one. `nettop` or Little Snitch will then show a process
that only ever listens. The URLs compiled into the app are that endpoint, the
releases page, and the issue tracker that opens when you click Report a bug.
The first two are in [Release.swift](../App/Sources/plonk/Release.swift), the
third at the top of
[AppDelegate.swift](../App/Sources/plonk/AppDelegate.swift), and
[check-security-claims.sh](../scripts/check-security-claims.sh) fails the build
if a fourth ever appears.

## A web page cannot drive it

The API is loopback-only, so it refuses anything carrying headers a browser
cannot suppress:

```sh
curl -so /dev/null -w '%{http_code}\n' -H 'Origin: https://example.com' \
  http://127.0.0.1:43917/state
403
```

## Neither can another program on your Mac

Loopback keeps the network out and does nothing about the machine, so the API is
gated on a token Plonk writes to `~/Library/Application Support/Plonk/token`,
readable by you and nobody else. The MCP server and the `plonk` command read it
for themselves; you never handle it. Without it, a request gets a 401:

```sh
curl -so /dev/null -w '%{http_code}\n' http://127.0.0.1:43917/state
401
curl -so /dev/null -w '%{http_code}\n' \
  -H "X-Plonk-Token: $(cat ~/Library/'Application Support'/Plonk/token)" \
  http://127.0.0.1:43917/state
200
```

This matters most for the screenshot routes. Plonk holds Screen Recording; a
script running as you may well not, and before the token it could borrow
Plonk's by asking the port. Where it stops: anything that can read that file
can read your screen by asking macOS itself, so this is a fence around the
port, not around your account.

## There is not much else to hide

[Package.swift](../App/Package.swift) declares no third-party dependencies, so a
build from source is this repo and nothing else. Config is plain JSON at
`~/Library/Application Support/Plonk/config.json`. Screenshots go where you send
them. There is no account to make.

The MCP server is a separate npm package that depends only on the official MCP
SDK and zod. It speaks to `127.0.0.1:43917` and nowhere else.

[SECURITY.md](../SECURITY.md) has the rest: the entitlements the bundle ships
with (none), every step the updater takes before it replaces anything, what the
signing certificate does and does not prove, and where each of these checks
stops being one.

---

[README](../README.md) · [SECURITY.md](../SECURITY.md)
