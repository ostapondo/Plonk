# Handoff — cube and colour

> **Delete this file when the checklist below is done.** It exists to carry
> context from the machine that drafted the design to the machine that can
> build it, and the links in it are private — they open only for @ostapondo,
> and this repository is public. Deleting it is the last task, not an optional
> tidy-up.

## What was agreed

The direction is **cube and colour**, approved after three rounds. Everything
below is already implemented on this branch unless the checklist says otherwise.

| | |
| --- | --- |
| **The approved direction** | https://claude.ai/code/artifact/186fa1eb-ef34-4124-8095-c41f76651b37 |
| **App screens + README in it** | https://claude.ai/code/artifact/fbbcfb4b-08e8-4bcc-9347-5f53a312a4a7 |
| **Full macOS screenshots** | https://claude.ai/code/artifact/fe464db8-cc63-4756-b1c3-25a4ee54d5eb |

Those three are the brief. The rules they encode are written up properly, and
permanently, in [README.md](README.md) beside this file — **read that first**,
because it survives after these links are gone.

<details>
<summary>Directions considered and not chosen — do not resurrect these</summary>

<br>

Kept only so nobody spends a second afternoon rediscovering why they lost.

| | | |
| --- | --- | --- |
| Tile | black ground, full-bleed colour tiles | https://claude.ai/code/artifact/1c4463ee-2bb3-48d3-9f50-f1642408ce0d |
| Deck | light, saturated cards in a stack | https://claude.ai/code/artifact/e36bdef2-081a-4eb2-8c1b-ac3f9472b363 |
| Mono | monochrome, monospaced, hairline grid | https://claude.ai/code/artifact/4739a443-301b-4122-ab70-53fba31d863b |
| Hotkeys in all three, plus a site map | | https://claude.ai/code/artifact/b285dbe5-57fa-4cbd-bfc8-6b1db49a023e |
| App screens in Tile | | https://claude.ai/code/artifact/a7c52a88-3f35-4f80-ac4e-b5767b016097 |
| Deck A — emoji | rejected: the same emoji sit on a thousand other landing pages | https://claude.ai/code/artifact/9bb122a2-1a47-4c6e-a9aa-67f98fae3e4e |
| Deck B — mascot | half of what was chosen | https://claude.ai/code/artifact/61cbb162-7328-43a7-99ec-a448f4dc7da2 |
| Deck C — gradient | the other half | https://claude.ai/code/artifact/a147a698-fb37-423d-afc5-b4e5bfd7723d |

The HTML sources for every one of these are committed at
`design/plonk/` on branch `claude/plonk-design-system-3uuj2h` of
**ostapondo/ostapondo**, which outlives these links.

</details>

## State of this branch

Done and verified on Linux: `docs/index.html` rebuilt, `README.md` restyled,
`docs/banner.gif` and `docs/ways.svg` generated, `docs/design/` holds the
render pipeline. Both themes resolve, no horizontal overflow at 390 or 1280,
no console errors, `scripts/lint.sh` clean, `scripts/check-zone-sets.mjs` valid.

Done and **not** verified: the Swift. The machine that wrote it had no Swift
toolchain, so `swift build` has never run against these three files.

- `App/Sources/plonk/Ink+Zones.swift` — new, the six-hue palette
- `App/Sources/plonk/ZoneCanvas.swift` — `zoneView` draws `Ink.zone(index)`
- `App/Sources/plonk/ZoneOverlay.swift` — added `tint(for:)`, used per zone

`ZoneAppearance.tint` was deliberately left alone: the ruler and the pointer
tools read it, and they should stay one colour.

## Checklist

1. **`(cd App && swift build)`.** Expect this to be where the unverified work
   fails, if it fails. `Ink+Zones.swift` is additive; the two edits are a few
   lines each and read in a minute.
2. **`./scripts/test.sh`.** No test was touched, so a failure here is a real
   regression, most likely in `ZoneGeometryTests` or a screenshot test that
   pins the overlay colour.
3. **Look at a real drag overlay.** Five zones, five hues, the hovered one
   brighter. Then set an explicit zone colour on the Zones page and confirm the
   whole set goes back to one colour — that escape hatch is the reason this
   change does not take a preference away.
4. **Measure the overlay on an Intel Mac** if one is reachable. A gradient
   behind every zone is drawn on every frame of a drag. If it costs frames,
   drop to flat fills in the same six hues; the idea survives intact.
5. **Re-shoot the app screenshots.** Half done. The stale ones —
   `docs/app-home-light.png`, `docs/app-zones-dark.png`, `docs/demo.gif` and
   the unlinked `.mp4`s — are deleted, and `docs/index.html` shows the
   mockups from `docs/design/shots/` in their place, so nothing on the site
   contradicts the design any more. What is still owed is captures from the
   built app, which the mockups are only standing in for.
6. ~~**Redraw `docs/social-preview.png`**~~ — done, from
   `docs/design/social.html`.
7. **Decide about the default.** Numbered colours are the default now, and
   setting an explicit colour opts out. If that is the wrong way round, the
   honest fix is a real toggle on the Zones page rather than overloading what
   "no colour set" means.
8. **Delete this file**, and drop the links from any commit body that quotes
   them.

## Three traps already paid for

Both are encoded in `docs/design/`, but they cost an afternoon each and are
easy to walk back into:

- `page.screenshot({ animations: 'disabled' })` **rewinds** the animations you
  just positioned by hand. The first run produced 36 identical frames.
- GIF `disposal=2` defeats frame differencing. Only the window moves in the
  banner; leaving disposal off took the file from 3.5 MB to 357 KB.
- A positive `animation-delay` leaves frame 0 un-animated and stops the loop
  closing. There is none in `scene.html` now; do not add one back.
