# Coming from Rectangle

Rectangle is good, and most of what you press in it already works here. This is
what carries over on its own, what one button carries over, and the two things
that do not carry over at all.

## Your shortcuts already work

Plonk's defaults are Rectangle's defaults. Not deliberately compatible after
the fact — the same keys, because `⌃⌥` is the one combination macOS leaves
alone, and both apps landed on it.

| | Rectangle | Plonk |
| --- | --- | --- |
| Left, right, top, bottom half | `⌃⌥←` `⌃⌥→` `⌃⌥↑` `⌃⌥↓` | the same |
| Corners | `⌃⌥U` `⌃⌥I` `⌃⌥J` `⌃⌥K` | the same |
| Maximize | `⌃⌥↩` | the same |
| Centre | `⌃⌥C` | the same |
| Put it back | `⌃⌥⌫` | `⌃⌥0` |
| Thirds | `⌃⌥D` `⌃⌥E` `⌃⌥F` `⌃⌥T` `⌃⌥G` | `⌃⌥1`–`⌃⌥9`, over a zone set |

The ten placements are identical. The last two rows are the whole difference,
and the second of them is the point of the app: a third is a fixed fraction in
Rectangle and a zone you drew in Plonk, so it is reached by its number rather
than by its own key. Pick the **Thirds** set on a screen and `⌃⌥1` `⌃⌥2` `⌃⌥3`
are your thirds. Draw something else and the same three keys follow it.

## If you changed yours

**Shortcuts → Import from Rectangle** reads the setup you have and takes the
bindings that mean the same thing in both apps.

It looks in two places, in this order: the preferences of an installed
Rectangle, and then `~/Library/Application Support/Rectangle/RectangleConfig.json`
if you exported your settings from the old machine. Rectangle does not have to
be running, or still installed, for the second one.

What comes across: the eight halves and corners, maximize, centre, and restore.
What does not: thirds, fourths, sixths, eighths, ninths, and the rest of the
fixed grid. Those are not missing features, they are zone sets here, and there
is no way to tell which numbered zone a "first third" should become without
knowing what set that screen is wearing. Guessing would put the window
somewhere wrong on every screen not using Thirds, so the import leaves them and
says nothing happened to them.

Rectangle's window gap comes across too, since it means the same thing.

If an imported key was already doing something here — `⌃⌥T` copies the text out
of a region, for instance — the imported binding wins and the app says out loud
what lost its key. Nothing is unbound quietly.

## Your URLs already work, after one sed

Rectangle can be driven by URL, and if you have a Raycast script, an Alfred
workflow or a Stream Deck button, that is probably how. Plonk answers the same
verb with the same action names:

```sh
open -g "plonk://execute-action?name=left-half"
```

So an existing config is one substitution away:

```sh
sed -i '' 's|rectangle://execute-action|plonk://execute-action|g' your-script.sh
```

`left-half`, `right-half`, `top-half`, `bottom-half`, `top-left`, `top-right`,
`bottom-left`, `bottom-right`, `maximize` and `center` are spelled exactly as
Rectangle spells them, and `restore` works as well as `unsnap`. Past that the
names are Plonk's own: `zone-1` to `zone-9`, `zone-set-1` to `zone-set-9`,
`cycle-zone`, `focus-left`, `capture-text`, `ruler`, `crop-live`, and one for
every other shortcut.

Two answers you can get instead of a window moving, both of which say so on
screen rather than failing silently:

- **`first-third` and the rest of the fixed grid.** Named, and told to use a
  zone number instead.
- **`next-display` and `previous-display`.** Refused rather than approximated.
  Those move the window to another screen; the nearest thing here moves the
  pointer, and answering to the name while doing something else is worse than
  not answering.

### Or let Plonk answer `rectangle://` directly

**Shortcuts → Answer rectangle:// URLs too** skips the substitution. Your
existing scripts keep the URLs they have and Plonk receives them.

It is off by default, and the reason is worth reading before you turn it on. A
URL scheme belongs to one app at a time. Turning this on takes `rectangle://`
from an installed Rectangle, and *its* URLs stop working from that moment —
silently, because nothing tells an app it has lost a scheme. If you have
removed Rectangle there is nobody to lose it and the switch costs nothing.

Off is not passive either. Merely declaring the scheme is enough for macOS to
hand it over on install, so if a `rectangle://` URL ever arrives while the
switch is off, Plonk hands the scheme back to Rectangle and runs that one URL
anyway. The switch shows what macOS actually does, not what was asked for.

## Running both at once

Fine, until they collide. Every shortcut above is bound in both apps, so
whichever registered it first gets the key and the other silently does nothing.
Pick one to hold the window shortcuts, or move one app's bindings.

Rectangle has an **Ignore app** feature for exactly this: focus Plonk, open the
Rectangle menu, and select it. Plonk's own equivalent is the exclusions list on
the Zones page, which is for apps that manage their own geometry rather than
for other window managers.

Tiling managers that own every window on screen — yabai, Amethyst — are a
different matter. They will pull a window straight back out of a zone. Run one
or the other.

## What you get that Rectangle does not have

Rectangle is intentionally slim, and that is a reasonable thing to want. If it
is what you want, it is the better app, and this page has done its job by
telling you so.

The reasons to move are narrower than "more features":

- **Zones you draw**, per monitor, rather than a fixed grid. This mostly
  matters on an ultrawide or a third monitor, where halves and thirds stop
  describing anything you actually want.
- **[Workspaces](workspaces.md)** that remember which display each window was
  on, and reopen the apps with the right files.
- **[An agent can drive it](agents.md)** over MCP: the same zones and
  workspaces as tools, so a sentence can rearrange the desk.

---

[Zones](zones.md) · [Workspaces](workspaces.md) · [Hotkeys](hotkeys.md) ·
[For agents](agents.md) · [README](../README.md)
