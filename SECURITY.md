# Security

Plonk asks for Accessibility and Screen Recording. Those are the two permissions
that let one app read and move another's windows and see what is on your screen,
and an agent on the other end of them can do both without you watching. That is
a lot to hand a menu bar app you found on the internet.

This page is what you can check instead of trusting it, what the checks actually
prove, and where they stop.

## What Plonk can do

| | |
| --- | --- |
| **Accessibility** | Move and resize windows of other apps, and read their titles, frames and menu shortcuts. It is also what lets the optional grab-and-move intercept a modifier-drag, and what the pointer tools use to watch the mouse without touching it. Granted by you, revocable in System Settings > Privacy & Security |
| **Screen Recording** | Capture a region, a window or a screen, when a capture is asked for. macOS shows its own indicator every time. Reading text off a capture uses the same permission and no other — recognition is Apple's Vision framework, running on this Mac — and so does a pinned live crop, which streams a region to a floating window and writes nothing anywhere |
| **Microphone / Speech** | Only while a push-to-talk key is held. Transcription happens on this Mac |
| **Disk** | One directory: `~/Library/Application Support/Plonk/`, plus wherever you save a screenshot, plus a temporary folder while an update is being unpacked |
| **Login item** | Registered on first launch, through `SMAppService` — see below |
| **Network** | One host — `api.github.com`, for the update check — and one loopback listener on `127.0.0.1:43917` |

## What it cannot do

The bundle ships with **no entitlements at all**, under the hardened runtime.
Check the copy you have:

```sh
codesign -d --entitlements - --xml /Applications/Plonk.app   # empty
codesign -dv --verbose=2 /Applications/Plonk.app 2>&1 | grep flags   # flags=0x10000(runtime)
```

There is no Full Disk Access, no Automation (it cannot script other apps), no
Keychain access, no helper daemon, no privileged tool, no installer script. It
is one binary in one bundle.

**It does start at login, and it turns that on by itself.** A menu bar app that
is not there after a reboot is not much of a menu bar app, so the first launch
registers Plonk as a login item. It does that the supported way —
`SMAppService.mainApp`, the API that puts a visible entry in System Settings >
General > Login Items, which you can revoke there — and nothing outside the
bundle is written to do it. The toggle is on Plonk's own Home page, and turning
it off unregisters immediately. It is called out here because a login item you
did not ask for is a fair thing to be annoyed about, not because it hides
anywhere.

Uninstalling is quitting Plonk, dragging it to the trash, and deleting
`~/Library/Application Support/Plonk/`. Nothing survives that.

## Where the build came from

Releases are built, signed and packaged by
[the release workflow](.github/workflows/release.yml) on GitHub's runners, never
on a laptop, and leave with a provenance attestation GitHub signs. That is what
connects the zip you downloaded to a commit you can read:

```sh
gh attestation verify Plonk-<version>.zip -R ostapondo/plonk
```

It prints the commit, the workflow file and the run that produced the archive. A
build made by anyone else, or from a source tree that is not this repository,
cannot produce that statement.

Releases up to and including 0.0.4 predate this: they were built and zipped on a
laptop and carry no attestation, so the command above fails on them. Nothing can
be done about that retroactively — an attestation is a statement about a build
that happened, and those builds happened somewhere nobody can check.

The MCP server is published the same way, so `npx -y plonk-mcp` is checkable too:

```sh
npm view plonk-mcp dist.attestations
```

npmjs.com shows the same thing as a "Provenance" panel on the package page,
naming the commit and the workflow run the tarball was built by.

There is no publish token for `plonk-mcp` anywhere — not in a secret, not on a
laptop. npm is told to trust this repository's release workflow directly and
authenticates it by the identity GitHub mints for each run, so the credential
that would let someone else publish under that name does not exist.

**What this does not cover.** Attestations say where a binary came from, not
that its source is harmless — that part is still reading the code, and there is
not much of it: ~7,600 lines of Swift and ~530 of TypeScript, with no
third-party Swift dependencies at all
([Package.swift](App/Package.swift)) and two on the npm side, the official MCP
SDK and zod. A Homebrew install checks the cask's sha256 but carries no
attestation of its own; verify the zip if you want the stronger statement.

## The signing certificate, and what it is not

Plonk is signed with a self-signed certificate called `Plonk Signing`. It is **not**
an Apple Developer ID and proves nothing about who wrote the app — Gatekeeper
does not trust it, which is why first launch needs one trip through System
Settings > Privacy & Security > **Open Anyway**.

What it does do is pin identity across versions. macOS ties your Accessibility
and Screen Recording grants to the signature, and Plonk installs an update only
when the new build satisfies the same designated requirement the running copy
carries. So the certificate is what makes "the update is from the same author as
the copy you already trusted" a checkable claim rather than a promise. The
requirement every release has to satisfy is committed to this repo, in
[scripts/release-requirement](scripts/release-requirement), and
[scripts/release.sh](scripts/release.sh) refuses to ship a build that does not
match it.

That requirement changed once, at 0.0.5. Releases up to 0.0.4 were signed with
a key that lived only in one Mac's keychain and could not be got back out of
it, which made building releases anywhere else impossible. Anyone who installed
0.0.4 or earlier has to install 0.0.5 by hand and grant Accessibility and
Screen Recording once more; updates carry across from there on. It is the kind
of change that costs every user something, so it was made while there was
almost nobody to charge.

The private key lives in GitHub Actions secrets. Its worst case is worth stating
plainly: someone holding that key could sign a build that installed copies of
Plonk would accept as an update. There is no revocation for a self-signed
certificate. Attestations are the check that survives that — a build signed with
the key but not produced by this repository's workflow will not verify.

Notarization would remove the Gatekeeper warning and add Apple's own malware
scan on top. It requires a paid Apple Developer account, and Plonk does not have
one.

## The update path

This is the part of the app with the most reach, so here is every step it takes:

1. On launch and once a day it asks `api.github.com` for the latest release, and
   sends nothing but a `User-Agent` naming the app and its version. No
   identifier, no account, no analytics. Turn the check off under Updates and
   this stops happening, agents included — they get a 409 rather than a
   connection opened on your behalf.
2. Nothing downloads until you press Install.
3. The archive's SHA-256 is checked against the digest GitHub published for that
   asset, before it is unpacked. This catches a download that arrived damaged or
   stale; it is not a defence against the feed itself lying, because both
   travel in the same response.
4. The unpacked bundle has to be Plonk, at the version that was offered.
5. It has to satisfy the running copy's designated requirement — the step above
   that matters, and the same test macOS applies to your permissions.
6. Only then is the bundle swapped, by a script that puts the old copy back if
   the swap fails.

Anything that fails a step is discarded and nothing is replaced.

## The local API

The HTTP API on `127.0.0.1:43917` is unauthenticated, because it is how an agent
on your own machine drives the app. Two things keep that from being a hole:

- It binds to loopback. Nothing off the machine can reach it.
- It refuses any request carrying headers a browser cannot suppress, so an open
  web page cannot drive your desktop:

```sh
curl -so /dev/null -w '%{http_code}\n' -H 'Origin: https://example.com' \
  http://127.0.0.1:43917/state
403
```

What this does **not** protect against: any other program already running as
your user can talk to that port. If something hostile is running locally with
your privileges, Plonk is not the weakest thing it has access to — but it is
fair to know the API is there.

Optional strict mode narrows it further: only the agent you have made active can
change anything, and everyone else gets a 409 on any call that moves a window or
edits config.

## Reporting a problem

Open an issue at https://github.com/ostapondo/plonk/issues. For anything you
would rather not post publicly, mark the issue with what you have found and ask
for a private channel before writing details, or email the address on
[ostapondo](https://github.com/ostapondo)'s GitHub profile.

Plonk is one person's project with no paid support and no bounty. What you will
get is an honest answer about whether it is real and when it is fixed.
