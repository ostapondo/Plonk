# Zone sets

A zone set is a layout, drawn once and assigned to a monitor. These are ones
people keep going back to. Every file here is valid input to the app's own
`/zones/save` route, so trying one takes a single command and no build.

The app ships five built-ins — Halves, Thirds, 60 / 40, Quarters, Priority —
which cover the common cases and are deliberately dull. This folder is for the
rest: the ultrawide split that only makes sense at 34 inches, the rotated
monitor, the layout that exists because of one recurring meeting.

**Adding yours is the smallest useful contribution this repo takes.** It is one
JSON file, it needs no Swift, no Xcode and no signing certificate, and CI
answers in about twenty seconds. Good ones end up shipping as built-ins.

## Trying one

With Plonk running:

```sh
curl -s -X POST 127.0.0.1:43917/zones/save \
  -H "X-Plonk-Token: $(cat ~/Library/'Application Support'/Plonk/token)" \
  -d @zone-sets/writing.json
```

The route reads `name` and `zones` and ignores the rest, which is why the file
can be posted as it stands. Then assign it to a monitor:

```sh
plonk zones "Writing"          # or the Zones page, or ask an agent
```

To go back, pick another set on the Zones page — `Halves` is the default.

## The gallery

Numbers are what the overlay draws and what `⌃⌥1`–`⌃⌥9` fill. Redraw these any
time with `node scripts/check-zone-sets.mjs --preview`.

### Ultrawide 25 / 50 / 25 · [`ultrawide-25-50-25.json`](ultrawide-25-50-25.json)

A wide middle for the thing being worked on, with a rail either side.

```
+----------++----------------------++----------+
|          ||                      ||          |
|    1     ||          2           ||    3     |
|          ||                      ||          |
+----------++----------------------++----------+
```

### Ultrawide Quarters · [`ultrawide-quarters.json`](ultrawide-quarters.json)

Four full-height columns. At 34 inches each is about a laptop wide.

```
+----------++----------++----------++----------+
|          ||          ||          ||          |
|    1     ||    2     ||    3     ||    4     |
|          ||          ||          ||          |
+----------++----------++----------++----------+
```

### Focus and Stack · [`focus-and-stack.json`](focus-and-stack.json)

The editor is zone 1, a narrow rail is zone 2, and 3 and 4 stack.

```
+--------++----------------------++------------+
|        ||                      ||     3      |
|        ||                      |+------------+
|   2    ||          1           |+------------+
|        ||                      ||     4      |
+--------++----------------------++------------+
```

### Writing · [`writing.json`](writing.json)

A centred column at a readable line length, with margins for notes and sources.

```
+------------++------------------++------------+
|            ||                  ||            |
|     2      ||        1         ||     3      |
|            ||                  ||            |
+------------++------------------++------------+
```

### Call and Work · [`call-and-work.json`](call-and-work.json)

The work fills zone 1, the call sits top right, notes take the rest.

```
+----------------------------------++----------+
|                                  ||    2     |
|                                  |+----------+
|                1                 |+----------+
|                                  ||    3     |
+----------------------------------++----------+
```

### Strip and Four · [`strip-and-four.json`](strip-and-four.json)

A full-width band for a log or a build, and four cells under it.

```
+----------------------------------------------+
|                      1                       |
+----------------------------------------------+
+----------++----------++----------++----------+
|          ||          ||          ||          |
|    2     ||    3     ||    4     ||    5     |
+----------++----------++----------++----------+
```

### Portrait 70 / 30 · [`portrait-70-30.json`](portrait-70-30.json)

A rotated monitor: the file being read on top, a terminal along the bottom.

```
+-------------------+
|                   |
|         1         |
|                   |
+-------------------+
+-------------------+
|         2         |
+-------------------+
```

### Portrait Thirds · [`portrait-thirds.json`](portrait-thirds.json)

Three stacked rows, the tall middle one for whatever is being read.

```
+-------------------+
|         1         |
+-------------------+
+-------------------+
|         2         |
|                   |
+-------------------+
+-------------------+
|         3         |
+-------------------+
```

## Adding one

1. Draw it in the app, on the Zones page. Nothing here has to be typed by hand.
2. Read it back out: `plonk state --json` prints `zone_sets`, with the exact
   numbers the editor produced.
3. Save it as `zone-sets/<slug>.json` in the shape below, where the slug is the
   name lowercased with everything that is not a letter or a digit turned into
   a hyphen. The check enforces this, and tells you the filename it wants.
4. `node scripts/check-zone-sets.mjs --preview` — it validates every set and
   draws yours, which is the fastest way to see you got the numbers right.
5. Open a pull request with the drawing in it. Say which monitor it is for and
   what each zone holds. That sentence is most of what makes a layout worth
   copying.

```json
{
  "name": "Writing",
  "description": "One line on what it is for, and which zone holds what.",
  "screen": "wide",
  "author": "@your-handle",
  "zones": [
    { "x": 0.3, "y": 0, "w": 0.4, "h": 1 }
  ]
}
```

## The rules, and why

[`schema.json`](schema.json) is the formal version;
[`scripts/check-zone-sets.mjs`](../scripts/check-zone-sets.mjs) is what CI runs.

- **Fractions of the visible area, origin top left.** A set is screen-agnostic:
  the same numbers stretch to a laptop and to a 49 inch monitor. That is why
  `screen` is only a hint about what it was drawn for.
- **Order is the numbering.** Zone 1 is the first in the array and the one
  `⌃⌥1` fills. Read left to right, top to bottom — unless the set is built
  around one main zone, in which case put that first and say so in the
  description, the way Focus and Stack and Writing do.
- **Nothing smaller than 0.1 on a side.** That is `ZoneGeometry.minSide`: the
  editor cannot draw a zone below it, so a smaller one could not be adjusted
  after it was installed.
- **At most four decimals.** More of them means a number came out of a division
  rather than the editor. A third of a screen is `0.3333`, and the rounding is
  invisible.
- **A name no built-in uses.** `Config.zones(named:)` prefers the built-in, so a
  set called Quarters would install and then never be reachable.
- **ASCII only.** Same rule as the rest of the repo: no emoji, no smart quotes.
- **Overlaps warn rather than fail.** They are legal, and occasionally what you
  want, but two zones under one cursor make a drag ambiguous.

## Still missing

Layouts nobody has contributed yet, if you have the desk for it:

- A laptop screen on its own, where the built-in Halves is genuinely too coarse.
- Two monitors of different shapes, as a pair of sets meant to be used together.
- A 5K in portrait beside a laptop.
- Anything built around one app that is fussy about its width.
