# Cube and colour

The design the site, the README and the app share, and the scripts that render
its assets.

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

Every one of these drives the real stylesheets through Chromium, so the pictures
cannot drift away from the design — change a colour and re-run.

```sh
npm i playwright && python3 -m pip install pillow   # once
node docs/design/shoot.js && python3 docs/design/assemble.py   # docs/banner.gif
node docs/design/shots.js                                       # app screenshots

# docs/social-preview.png, 640x320 at 2x. Chrome directly, because one still
# frame is not worth a playwright install, and the flags are part of the
# recipe: two runs with these are byte-identical, and dropping --disable-gpu
# rasterises differently and produces a different file.
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless --disable-gpu --hide-scrollbars \
  --force-device-scale-factor=2 --window-size=640,320 \
  --screenshot=docs/social-preview.png docs/design/social.html
```

`scene.html` is the banner animation. It carries no `animation-delay`: a
delayed animation has not begun at `currentTime` 0, so frame 0 came out
un-animated and flashed once per loop, and its phase at 3s no longer matched
its phase at 0 — a fill mode hides the first fault but not the second.
50 frames at 60 ms is exactly 3000 ms; GIF stores delays in centiseconds, so
a frame time that is not a multiple of 10 ms silently rounds and the loop
drifts. Every animation in the scene is exactly 3s long so the loop closes
without a stutter, and `shoot.js` pauses them all and steps `currentTime` by
hand, which is what makes the frames deterministic.

Two things that cost an afternoon each, both now encoded in the scripts:

- `page.screenshot({ animations: 'disabled' })` **rewinds** the animations you
  just positioned. Do not pass it when sampling frames.
- GIF `disposal=2` defeats frame differencing. Only the window moves in the
  banner, so leaving it off took the file from 3.5 MB to 357 KB. Dithering
  costs another 500 KB on a flat mesh for banding nobody can see at this
  size. Both are now switched off in `assemble.py` itself, which is the
  point: the script has to reproduce the committed file, or the claim that
  the assets cannot drift is not true.

`social.html` is that same drawing at rest: the card GitHub, Slack and every
other chat window draw when someone pastes the link. One frame needs no
pipeline, so Chrome writes the PNG straight out. Keep it 1280x640 — what GitHub
asks for, and what the file it replaced already was.

`mac.html` holds four full-size macOS scenes at real system metrics — 13px body
text, a 38px unified toolbar, a 220px sidebar, 12px traffic lights — and
`shots.js` screenshots each by element at 2×. Its output is committed beside it
in `shots/`, downscaled to 1600px wide:

| | |
| --- | --- |
| `shots/s-zones.jpg` | the window: sidebar, unified toolbar, the set, the canvas, grouped settings |
| `shots/s-desks.jpg` | the Desks page, four cards |
| `shots/s-drag.jpg`  | the desktop mid-drag, overlay translucent over real windows |
| `shots/s-menu.jpg`  | the desktop at rest with the menu bar panel open |

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
