# Changelog

What changed in each release, from a user's side. The commit log has the rest.

## 0.4.1 — 2026-08-30

### Changed

- **Background pointer work stays asleep when it is not needed.** Click
  highlighting no longer listens to every mouse movement, crosshair movement
  coalesces bursts before redrawing, and drag snapping removes its global
  monitors while the feature is switched off.
- **Screen-aware API calls reject displays that are not attached.** A bad
  monitor index can no longer leave an unreachable zone assignment in the
  saved config.

Versions before 0.1.0 shipped in two days and are summarized rather than
itemized. The dates are real; the tidiness is not — most of what is listed
under 0.0.4 was written the same afternoon it went out.

Releases up to and including 0.0.4 were zipped by hand and carry no build
attestation, so `gh attestation verify` fails on them. That is the whole reason
[the release workflow](.github/workflows/release.yml) exists now. Do not install
one of those.

## 0.4.0 — 2026-08-26

### Added

- **The windows go back after a display change, not only the ones Plonk
  placed.** Where each window on screen sits is noted as windows move, per
  set of monitors, and put back when that set of monitors returns: unplug
  the desk, work on the laptop, plug it back in, and the desk is as it was.
  A window Plonk placed that the note has no line for still returns to its
  zone. A switch under When the desktop changes, on by default beside the
  one that was there; apps on the exceptions list are left alone as ever.
- **The zones can be clicked.** Hold `⌃⌥Z` and every screen's zones stay up;
  click one, or press its digit while holding, and the front window goes
  there. Let go and they linger a moment, still clickable. A tap is the
  flash it always was. The overlay never takes focus, so the window that
  was in front stays in front.
 - **Shake a window to see the zones.** With the modifier required, wiggle a
   window sideways while dragging it and the zones come up anyway, for the
   rest of that drag. A switch on the Zones page, off by default.
- **The click ring is yours to set.** Ring every click was one colour, one
  size, one shape: the zone colour, 34 points, an outline. Pointer and clicks
  now says how it is drawn — a colour of its own, a second colour for right
  clicks so the two can be told apart in a recording, a ring or a filled dot or
  both, how wide it lands, how heavy its line is and how long it lasts. The
  crosshairs get the same treatment, with a colour, a thickness and an opacity,
  and finding the pointer gets the size of its circle and how far the rest of
  the desk dims behind it. Everything left unset still follows the zone colour,
  so a setup that was never touched looks exactly as it did.
- **An app can be told where its windows open.** Where apps open, on the
  Zones page: pick the app, a zone, and if it matters the monitor, and every
  window it opens from then on lands there. A rule is written down, so it
  outlives a relaunch where the habit of "where the last one went" does not,
  and it wins when both apply. Agents get `set_app_rule` and `clear_app_rule`,
  and `get_state` lists `app_rules`.
- **Empty zones can fill themselves.** A switch under When the desktop
  changes: a window that opens on a screen with a free zone goes into the
  first one. Most of what a tiling manager does, without it taking over the
  windows you placed yourself. Off by default, like the habit beside it.
  Both, and the habit, now leave dialogs, sheets and panels where they open:
  only a window in the ordinary sense is placed, and hidden apps or windows
  on another Space no longer count as holding a zone.
- **The MCP server reports its installed version.** Run `plonk-mcp --version`
  or `plonk-mcp -v` to print the package version without starting the server.
- **Throw a window to the next display, grow it, shrink it, cycle a half.**
  `⌃⌥⌘→` and `⌃⌥⌘←` send the front window to the next or previous display,
  into the same zone number where that display has one. `⌃⌥=` and `⌃⌥-`
  grow and shrink it by 30 points about the centre, with a side against the
  screen edge staying put. `⌃⌥←` on a window already in the left half takes
  two thirds, then a third, then the half again, and the other three halves
  do the same; the Keys card on the Zones page turns the cycle off. Keys,
  names and cycle are Rectangle's, so they import with the rest, and the
  `next-display` URL is answered rather than refused. Out loud: "throw it to
  the next screen", "make it bigger".
- **A zone can have a name.** Give one to any zone in the editor — chat,
  editor, build log — and it is drawn under the number in the overlay, on the
  Zones page and beside the zone's shortcut. Then "put this in chat" works
  out loud, on the screen the front window is on, and an agent can hand
  `snap_window` the name instead of the number. The number keeps working;
   a set with no names loses nothing. Zone sets in `zone-sets/` may carry
   names too, and Call and Work now does.

### Changed

- **Every settings page is drawn the same way.** Four pages — Zones,
  Workspaces, Appearance and Home — had rolled their own scroll, margins and
  spacing, so cards sat on a different rhythm depending on which sidebar entry
  you came from. They share one now. Zones and Appearance gained the heading
  and the line of description every other page already had; Workspaces keeps
  its own, drawn by the same code as the rest.
- **One shape for every measurement.** A number with a range — the zone gap,
  edge spanning, the overlay's opacity, the ruler's sensitivity — is now one
  row: the name, a knob and the exact value, with the explanation on hover.
  Three different shapes were doing this, one of which took three lines per
  number and one of which showed no value at all. Opacity reads as a
  percentage rather than as nothing.
- **A switch that is off hides what it governs.** Turning off "Grab a window
  anywhere" used to leave its three settings on screen at half brightness,
  costing the same room switched off as on. They are put away now and come
  back when it is switched on; nothing is forgotten in between.
- **Choosing a zone colour no longer shifts the rows under it.** The line
  under Colour says where the colour comes from in both states instead of
  appearing only while none was set.
- **A numbered zone's shortcut shows the zone.** Zone 1 to Zone 9 all carried
  the same grid glyph, which said nothing that "Zone 5" had not already failed
  to say. Each row now draws the set that is actually on your main screen, with
  its own zone filled and the rest outlined round it, the same way Left Half
  draws a left half. A number the set has no zone for draws an empty screen,
  which is what pressing it does.
- **A zone set's shortcut carries the set.** Zone set 1 to Zone set 9 shared
  one glyph and one generic name. Each row now draws the arrangement it
  applies and calls it by the name you gave it, falling back to "Zone set 7"
  only for a place the list does not reach.
- **Flashing the zones is filed with the zones.** It sat under "Halves,
  quarters and the rest", among the shortcuts that move a window; it moves
  none. It is at the top of Numbered zones now, where it is the way to see
  which number is which before pressing one.
- **Shortcut lists flow into columns.** A shortcut is a thumbnail, a name and
  a key — 300 points of content — and a full-width card gave each one the
  whole window, names staring at keys across a gulf of nothing. Rows now flow
  into as many columns as the card is wide: one on a narrow window, two or
  three on a desk — and each row sits on a surface of its own, so a key reads
  with its shortcut rather than with the neighbouring column's name. Every
  page with a shortcut list gets this, the Keyboard page included — which is
  also one card in sections now, like the Zones page, instead of a dozen cards
  in a scatter.
- **A shortcut recorder looks like something to click.** It has a border now
  whether or not it is recording; a flat pill in a column of eleven read as a
  label.
- **The Zones page puts its settings first and its shortcuts last.** Which
  zones the screen has, the two ways to drop a window into one by hand, then
  how it all behaves — the overlay, display changes, the apps left alone. The
  keys close the page under a labelled rule of their own, as one card in four
  sections rather than four cards in a scatter, each section's explanation
  right under its rows. They are the longest thing on the page and the least
  often changed.

### Fixed

- **An invalid click-ring style in a hand-edited config repairs itself.** The
  overlay already drew a ring for an unknown value, but the settings picker
  showed no selected style and the invalid value was saved again.

## 0.3.5 — 2026-08-23

### Changed

- **Keep awake and Stay active are one feature, called Pulse.** They were never
  two: a power assertion stops the Mac sleeping without touching the idle
  counter Slack and Teams read, so keep-awake alone still left you Away, and
  resetting that counter postpones sleep, so stay-active always implied
  keep-awake. Two switches for one thing, one of which quietly did the other's
  job. Now there is one session with a level — hold the Mac up, and optionally
  hold your chat status at available with it — and every way of starting one
  works at either level. The schedule and the watched apps used to arm only
  stay-active; a process binding used to end only keep-awake. All of them now
  start and end the one session, so `set_awake` with a `pid` can keep you
  available for exactly as long as a build runs.
  - Your setup carries over. A schedule or a watched-app list from Stay active
    comes across as it was, and turns the level on, unless the feature had been
    switched off in Tools. The two settings that existed twice — allow on
    battery, turn off after — keep their keep-awake values; check them if you
    had them set differently on each page.
  - `set_active` is gone. `set_awake` takes `available` instead, and reports
    `available` beside `awake`. `/state` reports one `awake_details` with the
    schedule and the apps in it; `active` and `active_details` are gone, and
    `active` is no longer a switchable feature in `disabled_features`.
- **Everything that starts a session by itself is in one card.** The schedule,
  the watched apps and the charger were spread over two cards and a third
  page's Power section, and the app list armed itself by having anything in it,
  which read as though the schedule and the apps were two halves of one rule.
  They are three independent reasons: each has a switch, and the card says the
  rule out loud — any one of them is enough, and the session ends when the last
  one lets go. An app list can now be kept while switched off, the way the
  schedule keeps its hours.
- **The screen numbers only appear when you ask for them.** Opening the Zones
  page or moving the screen selector used to flash every display's number over
  whatever was on it. Preview does that now, and it draws each screen's own
  layout on it at the same time, so one press answers both which monitor is
  which and what is on it.

## 0.3.4 — 2026-08-23

### Added

- **Keep going with the lid closed.** A switch under Awake > Power that stops
  the Mac sleeping when the lid is shut, so music keeps playing, a download
  keeps going and an ssh session stays up. Sleep on lid close is a forced
  sleep that no power assertion holds off, so this one turns system sleep off
  outright and asks for your password once. A root guard puts it back when you
  switch it off, and within a minute of Plonk being gone for good; it outlives
  a relaunch, so an update does not ask again. The menu bar cube goes half red
  while the hold is on, and `/state` reports `lid_closed`.
- **Which monitor is which, said on the monitors.** Opening the Zones page or
  moving the screen selector flashes the display's number and size on the
  display itself, the selected one in the zone tint. Picking "screen 2" in a
  settings window is no longer guesswork.

### Fixed

- **A divider stays where it is dropped.** Dragging one used to round every
  zone to a twentieth of the screen on release, which on a 5120-point display
  is a 256-point jump away from the pointer, and made half the positions on the
  screen impossible to ask for. Dividers are now pulled onto halves, thirds,
  quarters and the edges of neighbouring zones from within twelve points, and
  left exactly where they are put otherwise. The pull happens under the
  pointer, so what you see while dragging is what you get.
- **Splitting a zone left and right no longer needs a modifier.** The right
  button does it: left click cuts a zone into top and bottom, right click into
  left and right. ⇧-click still works, and works more reliably, now that the
  invisible view reading keys in the editor has stopped swallowing right-button
  clicks before the canvas could see them.

## 0.3.3 — 2026-08-19

### Added

- **Tools: a switch for every module.** Under Tools in the menu bar
  dropdown, which opens a menu of switches from the icon, and on a Tools page under Settings, each of zones, workspaces,
  screenshots, pointer tools, the ruler, voice, keep awake and stay active has
  a switch. Off means off everywhere: the page leaves the sidebar, its entry
  leaves the menu, its shortcuts are released to other apps, its manager
  stands down and its API routes answer 409 to agents, who can read
  `disabled_features` in `/state`. Settings are kept, so switching back on
  restores what was there.

### Changed

- **The menu bar dropdown opens on either button.** A left click used to open
  the window and a right click the menu; both open the menu now, and Open Plonk
  is its first line. The zone grid at the top is gone, Quit is Quit, and the
  bottom section no longer indents around an icon.

## 0.3.2 — 2026-08-19

### Fixed

- **The window's close, minimise and zoom buttons work again.** 0.3.1 moved
  the traffic lights down into the sidebar's panel, and in doing so moved them
  out of the strip that takes their clicks: they drew where they should and did
  nothing when pressed. They are back to working where they are.

## 0.3.1 — 2026-08-19

### Changed

- **The window has been redrawn.** The sidebar is a dark panel set into the
  window, the page's cards sit a step lighter on the ground between them, and
  the bar over the page is gone: the menu says where you are and every page
  opens with its own title. The menu carries the zone palette, one hue per
  destination, with the ⌘K search under the traffic lights, workspaces as
  coloured dots and connected agents as a line in the footer; permissions
  only speak up when one is missing. Light mode gets the same three steps as
  dark. Narrow windows stop breaking: two-column blocks collapse, the zone set
  header drops its buttons under the title, shortcut names truncate instead of
  folding into a column, and a text field beside a button gives way instead of
  the button.

### Fixed

- **A single click no longer moves your windows.** Clicking a workspace in the
  sidebar launched it on the spot, and clicking a row in the zone set palette
  swapped the layout and relaid out every window on the screen. Both were one
  stray click away from a mess. The sidebar row now opens the Workspaces page,
  where each workspace has its own Launch button; in the palette a click only
  moves the highlight, and return, a digit or a double click applies it.
- **`snap_window` with a title that matches nothing no longer reports the app
  as not running.** Placing a window into a zone by app and title, without
  naming a screen, looked for the window one way and moved it another: the
  screen lookup gave up when no title matched, while the move fell back to the
  app's front window as documented. Both now pick the window the same way.

## 0.3.0 — 2026-08-18

### Added

- **A layout can keep its own gap.** The gap in Zones › Overlay is the default;
  the editor's Gap row lets one layout set its own number of points instead,
  or go back to following the default. Six narrow zones can sit tight while a
  two-zone layout keeps its air. Drag snapping, numbered zones, previews and
  the flash all draw and place with the gap of the set on that screen.
  `save_zone_set` takes `gap` (points, or `null` for the default) and
  `get_state` lists `zone_gap` and `zone_set_gaps`.
- **Switching from Rectangle costs nothing now.** The ten placement shortcuts
  were already the same keys in both apps — `⌃⌥` and an arrow, a corner letter,
  return or C — because that is the one combination macOS leaves alone and both
  landed on it. What was missing was everything either side of that: a changed
  binding had to be re-entered by hand, and a `rectangle://execute-action` URL
  sitting in a Raycast script or on a Stream Deck button did nothing at all.

  Plonk looks once at launch, and a Mac with a Rectangle setup on it gets the
  offer on the Home page rather than a button on a settings page nobody opens
  first. Taking it or turning it down settles it for good, and a Mac with no
  Rectangle is shown nothing.

  **Shortcuts → Import from Rectangle** reads the preferences of an installed
  copy, or a `RectangleConfig.json` exported from an old machine, and takes the
  bindings that mean the same thing here: the halves, the corners, maximize,
  centre, restore, and the window gap. Rectangle's thirds, sixths, eighths and
  ninths are deliberately left behind and named instead of imported. They are a
  fixed grid; the equivalent here is a zone set, and there is no way to know
  which numbered zone a "first third" should be without knowing what set that
  screen is wearing. If an imported key was already doing something — `⌃⌥T`
  copies text out of a region — the imported binding wins and the app says what
  lost it, and a Rectangle whose bindings are *all* fixed-grid is told apart
  from one that is not there at all.

  URLs answer to the same verb and the same names:
  `open -g "plonk://execute-action?name=left-half"`. The ten placements are
  spelled exactly as Rectangle spells them and `restore` is accepted alongside
  `unsnap`, so an existing script is one `sed` away. Past that the vocabulary is
  this app's own: `zone-1` to `zone-9`, `zone-set-1` to `zone-set-9`,
  `cycle-zone`, `focus-left`, `capture-text`, `ruler`, and one name for every
  other shortcut. Asking for a fixed-grid action, or for `next-display`, says so
  on screen rather than failing quietly — the nearest thing to `next-display`
  here moves the pointer and not the window, and answering to the name while
  doing something else would be worse than not answering.

  `rectangle://` is declared as well, but answering it is a switch on the
  Shortcuts page and it is off. A scheme belongs to one app at a time, so
  turning it on takes those URLs from an installed Rectangle and its own stop
  working, with nothing to say so. Off is not passive: declaring a scheme is
  enough for macOS to hand it over on install, so a `rectangle://` URL arriving
  while the switch is off makes Plonk give the scheme back to Rectangle and run
  that one URL anyway. The switch reads its state back from macOS rather than
  from config, so it shows what is true rather than what was asked for.

  [docs/from-rectangle.md](docs/from-rectangle.md) is the whole of it, including
  what happens when both apps are running and hold the same key.

- **Stay active**, a page of its own under Settings, for the thing keep-awake
  was never able to do: stop Slack and Teams showing you as Away. They do not
  ask whether the Mac is asleep, they ask how long it is since the last
  keypress, and a power assertion does not touch that number. Stay active
  resets it with a Shift every two minutes. Run it by hand with a timeout, on a
  schedule of hours and weekdays, or while a chosen app is open. The schedule is
  read from the clock rather than fired by a timer, so a Mac that slept through
  09:00 and woke at 11:00 is inside the window rather than waiting for tomorrow,
  and a window may cross midnight. Off on battery unless you allow it, and it
  needs Accessibility — without the permission the page says so instead of
  quietly sending nothing. Agents get `set_active`.

- **The zone sets, as a list you can see.** `⌃⌥L` draws every set available for
  the screen the cursor is on, each one as a small picture of itself, with the
  one that screen is wearing marked. Arrows or the digit picks, `return` puts it
  on the screen, `E` opens it in the fullscreen editor, `N` starts a new one,
  Escape leaves everything as it was.

  `⌃⌥⇧1`–`⌃⌥⇧9` already swapped a set, but only for someone who remembers which
  set is number four. The digits in the list are those same numbers, so the list
  is also the thing that teaches them. Editing from here duplicates a built-in
  template first, exactly as the Zones window does, so the shipped sets stay
  intact.

- **A ruler for the screen.** `⌃⌥R`, then hover: Plonk photographs the screen
  once, walks out from the pointer in all four directions until one pixel is
  unlike the one beside it, and draws each run as a dimension line with its own
  number. That is the width of a row, the height of a bar, the size of the gap
  between two things, without anybody aiming a drag at a corner. Drag instead
  and it measures a straight line. Points and pixels both, because a 44-point
  tap target is 88 pixels and only one of those numbers is in the asset. A click
  copies, `Space` takes a fresh picture of the screen, Escape ends it.

  Two numbers on two lines rather than a box: the run across and the run down
  are separate answers, often about different things, and a rectangle drawn
  round them would claim they are the sides of one object — the one thing
  pixels cannot say.

  Borrowed from PowerToys' Screen Ruler, tolerance setting included, on the
  Ruler page under Capture. Ten out of 255 suits an interface: gradients and
  shadows step by less, borders by more. Raise it for a photograph or a video,
  where every pixel differs a little from the last.

- **`measure_screen` for agents, and `plonk measure` for a shell.** The same
  measurement without a person: hand it a point and it answers with the two
  runs through it, or two points and it answers with the distance. The reply
  carries the points, the display's own pixels, and the fraction of the screen
  ready to hand back to `apply_layout`. An agent that would have taken a
  screenshot and guessed at sizes can ask for the number instead, at a fraction
  of the tokens. `interactive: true` hands the ruler to the user and waits for
  what they measure. Needs Screen Recording, like every other capture.

### Changed

- **A hand-edited `config.json` is held to the same limits the sliders are.**
  A gap of 100, an opacity of 0.02 or an edge span of 200 used to be honoured
  verbatim and could leave zones you could not see or windows with nothing left
  of them. They are now brought inside the same bounds on load, wherever the
  value came from. Nothing else about the file changed: it is written exactly
  as before.
- **A `null` in `config.json` costs you that one setting, not all of them.**
  Any field written as `null` — by hand, or by a tool that spells "unset" that
  way — used to make the whole file unreadable, which set it aside and reset
  every setting, workspace and zone set you had. It now reads as "not set" and
  falls back to that field's default, which is what a missing key has always
  done.

- **The window looks like the rest of Plonk now.** Colour is the zone number
  everywhere it is drawn, so the sidebar, the Zones page, the website and the
  README all say the same thing the same way. The sidebar lists every page under
  the heading it belongs to instead of hiding ten of them behind groups that
  expanded, the selected row is the accent rather than a grey fill, and the
  Zones page opens with the set named in full, what it is running under it, and
  each zone printing the fraction an agent would send for it.

- **The README and the docs dropped the screen recordings** that still showed
  the old single-accent overlay. What replaced them is drawn to the same palette
  as the app, so a picture cannot go stale the next time the interface moves.

- **Every word the app says now lives in one file.** The text was written into
  the views that draw it, spread across sixty-odd Swift files, which meant a
  second language would have had to start by unpicking all of them. It is a
  string catalog now — `Resources/en.lproj/Localizable.strings`, with counted
  things in `Localizable.stringsdict` so plural rules belong to the language
  rather than to the code — and the source holds keys. Adding a language is one
  new folder beside the English one and no Swift at all.

  Nothing looks different, and that is the point: this is the groundwork, not
  the translation. Two things did have to change underneath. A shortcut's group
  ("Halves", "Numbered zones") was both the heading on screen and the value the
  pages filtered on, so translating it would have quietly emptied those lists;
  the two are separate now. And a handful of sentences are read by a person and
  by an agent both — the update status, the keep-awake status, why an app in a
  workspace did not land — so those reach the API in whatever language the app
  is running in. Every machine-readable field beside them is untouched: ids,
  route names and `phase` stay English, because that is the half a client
  actually branches on.

  The two permission dialogs macOS draws are covered too, through an
  `InfoPlist.strings` beside the catalog, since Info.plist itself cannot be
  translated.

### Fixed

- **An update check that failed offline runs again when the network is back.**
  It stopped at "The update check failed: The Internet connection appears to be
  offline", and that is where it stayed: nothing watched for the network
  returning, so the next attempt was the daily timer or the Check Now button. A
  copy launched away from a network sat on a day-old error next to a version it
  had never managed to check. Only that failure is retried, and only while
  automatic checks are on — a Wi-Fi hop does not re-ask GitHub about a feed that
  answered badly, and with checks turned off the buttons are still the only way
  a connection is opened.

## 0.2.5 — 2026-08-15

Two fixes, one of them a setting that only worked when a person asked for it.
The same zone gave an agent a different frame than the keyboard did, so the
zone gap looked broken to anyone driving Plonk over MCP.

### Fixed

- **The zone gap applies when an agent drops a window into a zone.** `⌃⌥3` left
  the gap around the window and `snap_window` did not, so the same zone gave two
  different frames depending on who asked for it, and the setting looked broken
  to anyone driving Plonk over MCP or from the CLI. The agent path built the
  zone's rectangle and placed the window without ever insetting it. Both paths
  now compute the frame in one function, `ZoneGeometry.frame`, which is where
  the gap comes off, so they cannot drift apart again.

- **The main window's header sits at the top edge again.** The title bar is
  hidden so the app draws its own, but the hosting view still reserved the
  height of the one it hid: every page opened under an empty strip the width of
  the window, and the sidebar started lower than it was told to.

### Changed

- **README and CONTRIBUTING are shorter.** Roughly a fifth off each. Install
  moved above the feature tour, and CONTRIBUTING leads with what there is to do
  rather than with how review works. The version badge said 0.2.2, and so did
  the `gh attestation verify` example next to it.

## 0.2.4 — 2026-08-10

The command palette got a key of its own, an agent can photograph a window it
names without disturbing it, and Claude Code installs the whole toolset in two
commands.

### Fixed

- **A prompt sent to an agent now shows what it is doing.** A CLI adapter takes
  tens of seconds and moves nothing until it has decided what to move, so the
  palette closing was followed by a two-second HUD and then silence — which
  looks exactly like nothing happening. There is now a ticking count for as
  long as it runs, and it ends on how it went. A failure used to be an `NSLog`
  nobody reads; it says so on screen, with the last line the adapter complained
  about.

- **⌘C, ⌘V, ⌘X and ⌘A work in Plonk's text fields.** They never had, anywhere
  in the app: AppKit delivers those through the main menu's key equivalents,
  and Plonk had no main menu at all, so a field would take a typed sentence but
  not a pasted one. An accessory app draws no menu bar, so the menu that fixes
  it stays invisible.

### Added

- **An agent can screenshot a window it names, even a covered one.**
  `take_screenshot` grew a `mode: "app"`, taking `app` and `title_contains`:
  "what is playing in Spotify" now works with Spotify hidden behind the editor.
  The three modes before it were the whole screen, or a picker waiting for a
  hand on the mouse — so anything you could not see, an agent could not see
  either, and the way round it was to raise the window and take your desktop
  with it. macOS keeps every window's image apart from every other's, which is
  what makes a buried one photograph cleanly; nothing is raised and no focus is
  taken. A minimized window keeps no image at all and says so, rather than
  handing back whatever was standing in its place.

- **The command palette has a key of its own — `⌃⌥A`.** It was already
  there, and it was reachable only from inside Plonk's own window, which is the
  one place you are not when you want to move a window. It now opens over
  whatever you are looking at, the way Spotlight does.
- **Type a sentence into it and it goes to your agent.** Anything that is not a
  command — "put the browser left and the terminal top right", "save this as a
  workspace called review" — can be sent as it is, with `⌘return` or by picking
  the last row. It takes the same road a spoken command takes, so it can reach
  nothing a key could not.

- **Claude Code installs the tools in two commands.**
  `/plugin marketplace add ostapondo/plonk`, then `/plugin install plonk@plonk`.
  The repository is its own marketplace, so there is no config file to find and
  no directory's approval to wait on. The plugin launches the exact `plonk-mcp`
  version its manifest names rather than whatever npm is serving, so the tools
  it advertises are the tools you get. It needs the app installed — the server
  is a bridge to a loopback API and does nothing on its own.

### Changed

- **New animations in the README and the docs — three of them, and each one
  shows a different thing.** The old one tried to be all of it at once: nineteen
  seconds, seven beats, and windows drawn a shade darker than the wallpaper
  behind them, so eight of them read as one dark rectangle with the same grey
  lines inside. The hero is now the README's own headline, one window at a time
  — dragged, sent with `⌃⌥2`, spoken, then a sentence to an agent.
  [Zones](docs/zones.md) opens with five clicks cutting a grid and a whole set
  being swapped under the windows in it, and [For agents](docs/agents.md) with
  four sentences landing on six named MCP tools. Every window now looks like
  the app it is meant to be rather than like a grey rectangle, and the hero is
  half the size it was. Still drawn rather than recorded, still one `swift`
  script per scene: `scripts/make-demo.sh`.

- **The Zones screenshot in the README is of this version.** The one it
  replaces was taken on 0.1.0, and it showed a build that had not been granted
  Screen Recording and a zone set — Edge snapping — whose preview is an empty
  rectangle by definition. The new one is 0.2.3 with the permissions green and
  a set of three numbered zones actually drawn in it.

## 0.2.3 — 2026-08-09

Nothing in the app changed. This release exists so the MCP server can be
installed by opening a file.

### Added

- Every release now carries `plonk-<version>.mcpb`, the bundle format Claude
  Desktop installs in two clicks. It holds the compiled server and a vendored
  copy of its dependencies, so no client config gets edited by hand and nothing
  is fetched at launch. `npx -y plonk-mcp` still works and is still what the
  CLI-based clients use.
- The bundle gets the same build attestation as the app archive and the npm
  tarball, so `gh attestation verify` ties it to the commit it was built from.

### Removed

- `smithery.yaml`. It described a deployment format Smithery's current
  documentation no longer mentions, and nothing in the repository read it. The
  Smithery listing is built from the bundle instead.

## 0.2.2 — 2026-08-09

Nothing in the app changed. If you are on 0.2.1, there is nothing here worth
updating for. As with 0.2.1, the release exists because npm and the MCP Registry
only take a new description when a version goes out.

### Changed

- The README, the site and both package descriptions lead with the window
  manager rather than with the agent. MCP is one of four ways into the app —
  drag, shortcut, voice, agent — and zones, workspaces, OCR, keep-awake and
  voice all work with the MCP server switched off, so opening on it oversold one
  interface and undersold the other nine utilities. Nothing about the agent
  surface is removed: `docs/agents.md`, the "For agents" section, the MCP badge
  and both client install lines are unchanged, and the two package descriptions
  still say plainly that this is an MCP server, because on npm and in the
  registry that is what the thing is.
- `docs/architecture.svg` says "MCP client" rather than naming one, since any of
  them works.

## 0.2.1 — 2026-08-09

Nothing in the app changed, and if you are on 0.2.0 there is nothing here worth
updating for. The release exists because npm and the MCP Registry only take a
new description when a version goes out, and the old one sold one feature out
of ten.

### Changed

- The README, the site and every package description now say what this is: ten
  menu bar utilities, a window manager among them, rather than the window
  manager alone. Anyone who wanted on-device OCR or a keep-awake that ends by
  itself had no way to tell from the top of the page that they are in here. The
  count is not a slogan — the feature table has ten rows and lists the same ten.
- The update check builds its URL from `ostapondo/plonk` instead of
  `ostapondo/Plonk`, which is the spelling every other file in the repository
  already used. GitHub resolves either, so no installed copy notices.

### Removed

- `docs/reference/fancyzones-editor.png` — a screenshot of another company's
  interface, kept as design reference while the zone picker was being drawn.
  `docs/` is the site root, so it was being served publicly, from a repository
  that is MIT and has no right to offer that file under it.

## 0.2.0 — 2026-08-08

A theme of Plonk's own, a command palette, and a settings window that stopped
being a list of everything the app can do.

### Added

- A theme of Plonk's own: light, dark, or whatever macOS is using, plus an
  accent colour, under Settings, Appearance. Both reach further than the
  window — the zone overlay and the pointer tools take the accent unless they
  have been given a colour of their own, and the theme applies to every panel
  the app puts on screen. Stored under a new `appearance` key in `config.json`;
  files written before this keep working and start on "system".
- A command palette on ⌘K, listing every shortcut, workspace, zone set and
  settings page by name. It is built from the same lists the rest of the app
  uses, so it cannot fall out of step with what the app can do. A placement
  command hides Plonk first, because otherwise the window it would move is
  Plonk's own.
- Opening Plonk while it is already running now shows its window, the way a
  Dock click does. It used to do nothing at all.

### Changed

- The settings window was redrawn. Eleven flat sidebar entries became five
  destinations that unfold into their pages, the permission chips moved to a
  strip in the title bar that only takes room when something is wrong, and the
  Zones page now opens on the set that is actually on your screen instead of a
  pop-up menu of names. Shortcuts are printed on the rows that own them.

- `zone-sets/` — a gallery of layouts as JSON the app's own `/zones/save` route
  accepts unmodified, so trying one is a single command and no build. Adding
  one is the smallest useful change this repo takes, and
  `scripts/check-zone-sets.mjs` validates the folder in its own CI job.
- `scripts/lint.sh` — checks the rules AGENTS.md states and nothing enforced:
  file length, no emoji, no trailing whitespace, a newline at the end of every
  file. No dependencies; it runs on a plain checkout.
- `scripts/line-limit-baseline` — the files that were already over the
  300-line limit, with the length each had that day. They may shrink, never
  grow. New files come in under the limit outright.
- `scripts/testbench.sh` — throwaway TextEdit windows to demonstrate a window
  fix on, and `state` to print where each one landed as fractions. Nobody has
  to move their real windows to prove a patch works.
- A test suite for `mcp/`: `npm test`, on the Node test runner, no new
  dependencies. Covers CLI argument parsing, the identity holders that keep one
  MCP session's name out of another's, and the tool input schemas.
- `.editorconfig`.
- This file.

### Changed

- `mcp`: `options()` moved out of `cli.ts` into `args.ts`, so it can be tested
  without running the CLI.
- README is shorter, and the reference sections it carried now live in `docs/`.
- CONTRIBUTING leads with the loop that needs no signing certificate, and says
  how long a review takes.

## 0.1.0 — 2026-08-08

The first release that is signed, attested and installable with one command.

### Added

- **Homebrew.** `brew install --cask ostapondo/plonk/plonk`.
- **Voice commands that run in the app.** The dozen most common ones — "snap
  this left", "zone three", "put it back", "keep awake for an hour", "launch my
  review workspace" — are handled on the Mac, offline, with no agent and no
  round trip. Anything less clear-cut still goes to the agent.
- **A Home page** with the three steps a new install needs, and a shortcut
  guide read from the front app's own menus.
- **A landing page** at [ostapondo.github.io/Plonk](https://ostapondo.github.io/Plonk/).

### Changed

- The zone gap is typed rather than dragged for, and excluded apps are picked
  from a list instead of typed.
- Notarization is off the roadmap, and the README says so plainly instead of
  promising a stamp that needs a paid Apple account.

### Fixed

- Around twenty ways the overlays, the grab handler and the new modules stepped
  on each other or on the rest of the desk: a grab that was really a click ate
  the click, `⌘` was read as `⇧`, and a disabled feature still held its tap.

## 0.0.5 — 2026-08-08

### Added

- **Releases are built on GitHub's runners**, signed there, and ship with a
  provenance attestation: `gh attestation verify Plonk-<version>.zip -R
  ostapondo/plonk`. `plonk-mcp` publishes to npm over OIDC with provenance.
  Nothing ships from a laptop, which is what makes either check mean anything.
- An update's checksum is verified against what GitHub published before
  anything is unpacked.

### Fixed

- Signing uses a key that can leave the machine it was made on, so the release
  workflow can hold one.
- The release refuses to overwrite an asset that has already been published.

## 0.0.4 — 2026-08-08

The release most of the app arrived in.

### Added

- **The things a decade of Windows power users expect from a zone**, rebuilt
  for the Mac:
  zones by number (`⌃⌥1`–`⌃⌥9`), put-it-back (`⌃⌥0`), spanning two zones,
  excluded apps, focus by geometry, zone appearance, and windows that return to
  their monitor after a display change.
- **Grab and move** — hold a key and drag a window from anywhere inside it.
- **Pin part of the screen** above everything, live or frozen.
- **Text off the screen** (`⌃⌥T`), on-device.
- **Pointer tools** and a **shortcut guide**.
- **Push-to-talk voice** (`⌃⌥V`), recognized on the Mac.
- **Updates from inside Plonk**, installing a build only when it is signed with
  the same certificate as the running copy — the same test macOS applies, so
  Accessibility and Screen Recording carry over.
- **Streamable HTTP transport** (`plonk-mcp --http`) for clients that cannot
  spawn a process, a **live-state SSE stream** at `/events`, and a
  **back-channel** so Plonk can reach the active agent.
- Setup pages for Cursor, Zed and Cline, and `llms-install.md`.

### Fixed

- Rebuilding no longer drops Accessibility and Screen Recording:
  `scripts/build.sh` refuses to run without a stable signing identity, because
  macOS pins those grants to the code signature.

## 0.0.3 — 2026-08-07

### Added

- **Several agents at once.** Every client registers itself, `get_state` lists
  who is online, and the user picks an active one from the menu bar or the
  settings. An optional strict mode locks changes to that agent; everyone else
  keeps reading state and gets a 409 on anything that moves a window.
- Workspace rename.

## 0.0.2 — 2026-08-07

### Added

- Listed on the MCP Registry, Glama and Smithery.
- The demo animation the README opens with.
- `ROADMAP.md`.

## 0.0.1 — 2026-08-07

First release. The menu bar app, snap zones, workspaces, keep-awake,
screenshots, and `plonk-mcp` on npm.
