# Task — build the app UI

The website and the zone palette are done and on this branch. **The app's own
interface is not.** That is this task.

Read [README.md](README.md) first — it is the design system in one page — then
come back here.

## Where things are

| | |
| --- | --- |
| **The spec** | `docs/design/mac.html` — the whole app drawn at real macOS metrics |
| **The target** | `docs/design/shots/*.jpg` — what each screen should end up looking like |
| **The rules** | `docs/design/README.md` — palette, why six colours is the ceiling, what the accent is still for |
| **Already built** | `App/Sources/plonk/Ink+Zones.swift` — the palette, with a SwiftUI and an AppKit accessor |

Take **numbers** from `mac.html`, not markup. The glass there is
`backdrop-filter`; in the app it is `NSVisualEffectView`, which the sidebar
already uses. The zone gradients are already `Ink.zoneGradient(_:)`.

## Do this first

Three Swift files on this branch have never been compiled — the machine that
wrote them had no toolchain. Before anything else:

```sh
(cd App && swift build) && ./scripts/test.sh && ./scripts/lint.sh
```

If it fails, it will be in `Ink+Zones.swift` (new), `ZoneCanvas.swift`
(`zoneView` now takes its colour from `Ink.zone(index)`) or `ZoneOverlay.swift`
(added `tint(for:)` alongside the existing `tint`). Fix and commit that on its
own before starting the UI.

## The work, in order of how much it shows

One commit per area. They are independent, and a broken one should be obvious
without unpicking the others.

**1 · Window chrome and sidebar** — `MainWindowView.swift`, `MainSidebar.swift`
Target: `shots/s-zones.jpg`. Section headers (LAYOUT / TOOLS / AUTOMATION) in
11px uppercase, rows at 13px with a 15px icon, the selected row filled with a
plum gradient rather than the system selection, a trailing count or state on
the right, and a footer carrying the cube and the version. The sidebar keeps
its vibrancy.

**2 · Zones page** — `ZonesPage.swift`, `ZoneSetCanvas.swift`
Target: `shots/s-zones.jpg`. A display-weight title with the screen and set
described under it, sets as pill tabs, and settings in one rounded container
with hairline separators — the pattern System Settings uses, not one card per
row. Each zone prints its fraction; that is the same number an agent sends
over MCP, so the two never disagree.

**3 · Desks** — `WorkspacesPage.swift`
Target: `shots/s-desks.jpg`. Each card draws the monitors it rebuilds as bars
in the colours of the zones the windows return to, so two desks are
distinguishable before their names are read.

**4 · Menu bar panel** — `StatusMenuController.swift`
Target: `shots/s-menu.jpg`. The zone grid at the top is the live set and each
rectangle is clickable — it sends the front window there. That makes the menu
a fourth way to place a window, next to drag, key and voice.

**5 · First run** — `GettingStarted.swift`
Two permissions, each saying what it buys, and a line for everything that is
never asked for. The cube here has its eyes shut, the same drawing as the
privacy card on the site. It is the only screen every user sees, and where a
window manager loses people.

## Rules that are not negotiable

- **Colour is the zone number.** Zone 1 rose, 2 plum, 3 blue, 4 mint, 5 sun,
  6 sky, then it wraps. Always through `Ink.zone(_:)` / `Ink.zoneTint(_:)`,
  never a literal.
- **The accent is still the accent.** Selection rings, the delete button,
  divider handles, the ruler and the pointer tools keep `Color.accentColor`.
  One accent cannot tell five zones apart; that is the whole reason the palette
  exists. `ZoneAppearance.tint` stays as it is — the ruler and pointer read it.
- **Setting an explicit zone colour still overrides the set**, exactly as
  before. The default changed; the preference did not go away.
- **No third-party dependencies.** The app ships with zero and that is a
  feature on the site.
- **Both themes.** `Ink` already spells out light and dark; use it rather than
  asking `NSColor` what grey to use.
- **`./scripts/lint.sh` must stay clean** — 300 lines per file, no emoji, no
  trailing whitespace, a newline at the end.

## Done means

```sh
(cd App && swift build)
./scripts/test.sh
./scripts/lint.sh
node scripts/check-zone-sets.mjs
```

all pass, and each screen matches its shot in `docs/design/shots/`.

Then re-shoot `docs/app-home-light.png`, `docs/app-zones-dark.png` and
`docs/demo.gif` from the real app — `docs/index.html` displays all three, and
they currently show the old single-accent overlay, which is the last thing on
the site contradicting the design. `docs/social-preview.png` needs redrawing
too.

Finally, work through the rest of [HANDOFF.md](HANDOFF.md) and delete it. Its
links are private and this repository is public.

## One thing that will waste an hour otherwise

Spotlight and Launchpad open `/Applications/Plonk.app`, not the copy you just
built. The signature is the same, so overwriting keeps the permission grants —
but move the old one aside rather than deleting it, so a failed copy does not
leave you with no app at all:

```sh
pkill -f "Plonk.app/Contents/MacOS/plonk"
mv /Applications/Plonk.app /Applications/Plonk.app.old \
  && cp -R ~/Desktop/ok/plonk/Plonk.app /Applications/ \
  && open /Applications/Plonk.app
```
