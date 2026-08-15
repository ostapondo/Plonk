# Everything else

The parts that are not zones, workspaces or hotkeys.

| | |
| --- | --- |
| **Keep awake** | IOKit power assertions, not a jiggler. Display-on or system-only, pause on battery, auto while charging, and a session that ends when you say: after N minutes, at a wall-clock time, or the moment a process exits — `plonk awake while npm run build` holds the Mac up for exactly as long as the build lasts and not a second longer |
| **Screenshots** | Region, window or screen through the native picker, then pen, arrow, rectangle, ellipse and highlighter. Saves at native resolution |
| **Text** | `⌃⌥T` selects an area and copies the words in it, including text that is only pixels — a screenshot, a paused video, a PDF that will not let you select. Recognition is on-device; `plonk text \| grep …` works too |
| **Ruler** | `⌃⌥R`, then hover: Plonk reads the pixels and measures how far the pointer can travel each way before it meets an edge — the width of a row, the height of a bar, the gap between two things — and draws each run as its own dimension line. Drag instead for a straight-line distance. Points and pixels both, because a 44-point tap target is 88 pixels and only one of those numbers is in the asset. Click copies, `Space` re-photographs the screen, Escape ends it |
| **Pinned crops** | `⌃⌥P` drags out a region and floats it above everything, mirroring whatever is underneath. `⌃⌥⇧P` freezes it instead. Streamed, never written down |
| **Shortcut guide** | `⌃⌥⇧/` lists every shortcut the front app has, read from its own menus rather than from a table someone has to keep up to date |
| **Pointer** | Find the cursor, ring every click for a screen recording, crosshairs, and a key that warps the pointer to the next display |
| **Grab and move** | Hold a key and drag a window from anywhere inside it; right-drag resizes from the nearest edge. Off by default, because option-drag already means something in plenty of apps |
| **Notices** | A panel in the top-right corner, not Notification Center: no permission to ask for, nothing left in your history, and it can show the screenshot instead of describing it |
| **Updates** | One button on the Updates page. The download is checked against the checksum GitHub published for it before it is unpacked, and Plonk installs a build only if it is signed with the same certificate as the copy you are running — the same test macOS applies, so your Accessibility and Screen Recording grants carry over instead of being asked for again. Anything that fails is discarded and nothing is replaced. Switch the check off and the app never looks |

---

[Zones](zones.md) · [Workspaces](workspaces.md) · [Hotkeys](hotkeys.md) · [README](../README.md)
