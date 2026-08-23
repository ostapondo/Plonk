<!--
CONTRIBUTING.md has the long version. Delete any section that does not apply —
a one-line docs fix should not carry a geometry checklist.

The title does not have to be clever. `fix: nil display UUID on unplug` is a
good title. So is `Add a setup page for Windsurf`.
-->

## What changed, and why

<!-- One paragraph. The why matters more than the what; the diff has the what. -->

## What you ran

<!--
The loop CI runs, from the repository root. Paste the ones you ran:

  (cd App && swift build)
  ./scripts/test.sh
  ./scripts/lint.sh
  (cd mcp && npm ci && npm test)
  node scripts/check-zone-sets.mjs
  node scripts/check-strings.mjs
  ./scripts/check-security-claims.sh

None of them need a signing certificate.
-->

## Checks

- [ ] `swift build` passes on every commit in the branch, not just the last one
- [ ] New logic is covered in `App/Tests/plonkTests/` or `mcp/test/`, or it is not the kind that can be
- [ ] Commits use `feat:` / `fix:` / `docs:` / `chore:` / `refactor:`
- [ ] If this touches the network, the permissions, the entitlements or the update path, `README.md` and `SECURITY.md` still tell the truth — fixed in this PR if not
- [ ] Screenshots below for anything visual

<!-- ===================================================================== -->

## If this moves windows

<!--
Delete this whole section unless the change touches zones, snapping, drag,
workspaces, focus, or anything else that decides where a window ends up.

Nothing in the unit suite can see a real desktop, so this is the only evidence
there is. `scripts/testbench.sh` opens throwaway TextEdit windows so you never
have to move your real ones:

  ./scripts/testbench.sh up 4     open four windows
  ./scripts/testbench.sh state    print where they landed, as fractions
  ./scripts/testbench.sh down     close them, delete the files

Run `state` before and after and paste both. Fractions travel between machines;
pixels do not.

You are not expected to own every arrangement below. Tick what you ran, and
write "no hardware" against the rest — an honest gap is more useful than a
blank, and it is what the `needs-hardware` label is for.
-->

**Setup:** macOS <!-- 15.2 -->, <!-- 1 built-in display @ 2x -->

- [ ] **One screen.** Snap into a zone by drag and by `⌃⌥1`–`⌃⌥9`. Both land in the same place.
- [ ] **Put it back.** `⌃⌥0` returns the window to the frame it had before Plonk first touched it.
- [ ] **A second monitor.** A window snapped on each screen stays on its own, and the zone numbers follow the screen the cursor is on.
- [ ] **Mixed scale factors.** A Retina screen beside a 1x one, a window snapped on each. Nothing is half-size or double-size.
- [ ] **Unplug and plug back in.** Windows return to the monitor they were on, not to index 0.
- [ ] **An excluded app.** A window of an app on the exclusions list is left alone by drag and by shortcut, and still moves when an agent names it on purpose.

<details>
<summary>Before / after from <code>testbench.sh state</code></summary>

```
```

</details>
