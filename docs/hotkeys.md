# Hotkeys

<p align="center">
  <img src="hotkeys.svg" alt="Where each hotkey puts the front window" width="720">
</p>

<p align="center">
  All on <code>⌃⌥</code>. Every one of them is rebindable, and any of them can be unbound.
</p>

| | |
| --- | --- |
| `⌃⌥` arrows, `U I J K`, `↩`, `C` | Halves, quarters, maximize, centre |
| `⌃⌥1`–`⌃⌥9`, `⌃⌥0` | Into a numbered zone, or back where it was |
| `⌃⌥⇧1`–`⌃⌥⇧9` | Swap the whole zone set on this screen |
| `⌃⌥L` | The zone sets as a list on screen — pick one, or press `E` to edit it |
| `⌃⌥⇧` arrows | Focus the window that is actually in that direction |
| `` ⌃⌥` `` · `` ⌃⌥⇧` `` | Next window in this zone · the previous one |
| `⌃⌥Z` | Show the zones. Hold it and click one, or press its digit, and the front window goes there |
| `⌃⌥S` · `⌃⌥T` | Grab a region · lift the text out of one |
| `⌃⌥P` · `⌃⌥⇧P` | Pin a live crop on top · pin a still one |
| `⌃⌥R` | Measure what is under the pointer |
| `⌃⌥⇧/` | Every shortcut the front app has |
| `⌃⌥/` · `⌃⌥\` | Find the pointer · jump it to the next screen |
| `⌃⌥V` | Hold to talk |
| `⌃⌥A` | Command palette — run anything by name, or type a sentence for the agent |

## Without a key

Every one of these has a name, and a URL that runs it. Useful where a keyboard
shortcut is the wrong shape: a Raycast script, an Alfred workflow, a Stream
Deck button, a line in a Makefile.

```sh
open -g "plonk://execute-action?name=left-half"
open -g "plonk://execute-action?name=zone-3"
open -g "plonk://execute-action?name=ruler"
```

The names are `left-half`, `right-half`, `top-half`, `bottom-half`,
`top-left`, `top-right`, `bottom-left`, `bottom-right`, `maximize`, `center`,
`unsnap`, `zone-1` to `zone-9`, `zone-set-1` to `zone-set-9`,
`zone-set-palette`, `cycle-zone`, `cycle-zone-back`, `focus-left`,
`focus-right`, `focus-up`, `focus-down`, `show-zones`, `capture-region`,
`capture-text`, `crop-live`, `crop-still`, `ruler`, `find-cursor`,
`jump-cursor`, `shortcut-guide` and `command-palette`.

`voice` is not one of them. Holding `⌃⌥V` talks and letting go stops, and a URL
has no second half, so one would leave the microphone listening with nothing to
close it. Asking for it says so rather than starting it.

The first ten are spelled the way Rectangle spells them, and `restore` is
accepted for `unsnap`, so a config written against `rectangle://` works after
one substitution. [Coming from Rectangle](from-rectangle.md) has that, and the
switch that skips it.

A name nothing answers to says so on screen rather than failing quietly, since
the caller is a script with nowhere to receive an error.

---

[Zones](zones.md) · [Workspaces](workspaces.md) · [Everything else](features.md) ·
[Coming from Rectangle](from-rectangle.md) · [README](../README.md)
