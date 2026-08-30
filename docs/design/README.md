# Plonk visual system

The visual language shared by the app, README and site, plus the reproducible
scripts that render its assets.

## Brand art

The public face is **Placed Matter**, documented in
[`plonk-visual-philosophy.md`](plonk-visual-philosophy.md). It treats Plonk as
one modular instrument rather than a catalogue of features: eight abstract
forms find a precise place around the cube, without feature icons, fake UI or
generated 3D materials. `render-brand-art.py` produces both committed PNGs from
the same geometry, fonts and paper texture:

```sh
uv run --with pillow python docs/design/render-brand-art.py
```

- `docs/brand-hero.png` is the README and website hero at 1600 × 900.
- `docs/social-preview.png` is the 2:1 link card at 1280 × 640.

The renderer uses the real app icon and the bundled `canvas-design` fonts. The
random paper grain is seeded, so identical source produces identical images.

## Two rules

**Colour is the zone number.** Zone 1 is rose, 2 plum, 3 blue, 4 mint, 5 sun,
6 sky. The same six hues appear in the drag overlay, the zone editor, the menu
bar grid, the desk cards, the website and the README, so a set can be read
before anyone reads a digit — and a window that keeps its number across a set
swap visibly keeps its colour too.

| # | hex | | # | hex |
| --- | --- | --- | --- | --- |
| 1 | `#ff4f81` rose | | 4 | `#12d3a4` mint |
| 2 | `#8b5cf6` plum | | 5 | `#ffc531` sun |
| 3 | `#3a6bff` blue | | 6 | `#25c8ff` sky |

Six is the ceiling: past that the hues stop being reliably distinguishable, and
rose against mint is already the risky pair for a red-green deficiency, so the
palette wraps and the number carries it. Rose and blue sit furthest apart on
every kind of vision, which is why they are 1 and 3 rather than neighbours.

This palette is **not** the accent. The accent is chrome — selection rings, the
delete button, the divider handles, the pointer tools, the ruler — and one
accent cannot tell five zones apart. Setting an explicit zone colour on the
Zones page still overrides the whole set with one colour, exactly as before;
only the default changed.

**The cube is the only hard-edged thing.** It keeps its black outline and flat
fills. Everything else on the site is soft: glass over a mesh mixed from the
cube's own three faces. A flat drawing sitting on a gradient needs the light to
agree, so the cube carries an ambient glow that drifts in hue with the mesh
behind it, and it overlaps the edge of the glass rather than sitting inside it.

## Regenerating the assets

The interface mockups still drive the real stylesheets through Chromium, so
those pictures cannot drift away from the design — change a colour and re-run.

```sh
npm i playwright && python3 -m pip install pillow   # once
node docs/design/shots.js                                       # app screenshots
```

`mac.html` holds four full-size macOS scenes at real system metrics — 13px body
text, a 38px unified toolbar, a 220px sidebar, 12px traffic lights — and
`shots.js` screenshots each by element at 2×. Its output is committed beside it
in `shots/`, downscaled to 1600px wide:

| | |
| --- | --- |
| `shots/s-zones.jpg` | the window: sidebar, unified toolbar, the set, the canvas, grouped settings |
| `shots/s-desks.jpg` | the Workspaces page, four cards |
| `shots/s-drag.jpg`  | the desktop mid-drag, overlay translucent over real windows |
| `shots/s-menu.jpg`  | the desktop at rest with the menu bar panel open |

These are drawings, not photographs. `docs/index.html` shows them where
captures of the built app belong, which was the right trade while the interface
they describe did not exist yet and is a debt now that it does. Replacing one
means shooting the real window and dropping it in beside its mockup.

**If you are writing the SwiftUI, `mac.html` is the spec and `shots/` is the
target.** Take the numbers from the stylesheet, not the markup: the glass is
`backdrop-filter` here and `NSVisualEffectView` there, and the zone gradients
are already `Ink.zoneGradient(_:)` in the app. Nothing else in `mac.html` is a
reference implementation.

The rest of the mockups — the directions that were not chosen, the site
variants, the app screens with their reasoning — are HTML on branch
`claude/plonk-design-system-3uuj2h` of **ostapondo/ostapondo**, under
`design/plonk/`. That is a different repository from this one, which has caught
two people out already:

```sh
git clone --branch claude/plonk-design-system-3uuj2h --single-branch \
  https://github.com/ostapondo/ostapondo ~/plonk-design
```

## Not done yet

- **The site shows the mockups, not the app.** `docs/index.html` now displays
  `shots/s-zones.jpg` and `shots/s-menu.jpg`; the real screenshots it used
  before predated this design and are deleted rather than left to contradict
  it. Re-shoot from the built app once the screens match, and point the site
  back at real captures — a mockup is the target, not the product.
- **`shots/` still shows a page that was renamed.** Keep awake and Stay active
  became one page called Pulse in 0.3.5. `mac.html` says so; the JPEGs beside
  it were shot before that and still label the sidebar entry the old way, and
  `docs/index.html` shows one of them. Re-shoot when the shots are replaced.
- **`shots.js` does not reproduce what is committed.** It writes PNGs at 2x;
  `shots/` holds JPEGs downscaled to 1600px wide, and the step between them is
  somebody's hands. Either put the resize in the script or commit what it
  actually writes.
- **A setting for the palette.** Right now the numbered colours are the default
  and an explicit zone colour opts out. If that turns out to be the wrong
  default, the honest fix is a real toggle on the Zones page rather than
  overloading what "no colour set" means.
- **Performance on Intel.** A gradient behind every zone is drawn on every frame
  of every drag. It degrades gracefully — flat fills in the same six hues keep
  the whole idea — but it should be measured before anyone calls it done.
