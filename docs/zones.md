# Zones

<p align="center">
  <img src="zones.gif" alt="Five clicks in the zone editor cut one screen into six zones, six windows fill them, and ⌃⌥⇧2 then swaps the whole set for another while the windows already in it follow their numbers across" width="720">
</p>

<p align="center">
  <img src="zone-sets.svg" alt="Five built-in zone sets and a sixth, irregular one drawn by hand" width="720">
</p>

Five sets ship with it. Everything past that you draw yourself: any number of
zones, any size, overlapping if you want — a narrow rail for chat, a wide middle
split in two, a strip for the terminal. Or describe it and let the agent build
it.

| | |
| --- | --- |
| **Editor** | Click to split, `⇧`-click to split vertically, drag a divider to resize neighbours, `✕` to delete and let them heal over the gap |
| **Per monitor** | Each screen gets its own set, remembered by display, not by index |
| **Overlap** | Allowed — the smallest zone under the cursor wins |
| **Trigger** | On drag, or only with a modifier held. Holding it inverts the mode, so a free move stays one keypress away |
| **Span** | Hold `⌘` as well: the zone you started over and the one under the cursor become a single drop, so two columns make one wide window without editing the set |
| **By number** | `⌃⌥1`–`⌃⌥9` drop the front window into the zone the overlay draws that number on. `⌃⌥0` gives it back the frame it had before Plonk first moved it |
| **Or none** | Edge snapping instead: middles are halves, top is maximize, corners are quarters |
| **Or hover the line** | Bring the cursor near the border between two zones and both light up, no modifier at all |
| **Whole sets** | `⌃⌥⇧1`–`⌃⌥⇧9` swap the set on the screen the cursor is on. Windows already sitting in a numbered zone move to where that number is now |
| **Picking one** | `⌃⌥L` draws the sets for that screen as a list: arrows or the digit to pick, `return` to use it, `E` to open it in the editor, `N` for a new one |
| **Looks** | Gap, colour, opacity, numbers on or off, every monitor's zones shown while dragging. The gap is real — a window keeps that much space around it |
| **Exceptions** | A list of apps Plonk keeps its hands off — games, remote desktops, anything that manages its own geometry. Asking an agent to place one still works; that names the window on purpose |
| **New windows** | Optionally, a window that opens goes where that app's last one went |

---

[Workspaces](workspaces.md) · [Hotkeys](hotkeys.md) · [Everything else](features.md) · [README](../README.md)
