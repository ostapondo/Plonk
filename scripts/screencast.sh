#!/bin/sh
# Sets up — and afterwards encodes — a real screen recording of an agent
# driving Plonk.
#
# The README's demo.gif is drawn, on purpose: it never goes stale and anyone
# can regenerate it. This is the other asset, the one a drawing cannot be: real
# windows of real apps moving because an agent said so. Worth recording once
# per release-worth of changes, and it wants the same starting desk every time,
# which is what this script builds.
#
#   scripts/screencast.sh stage    # the demo zone set, then a believable mess
#   scripts/screencast.sh grid     # just the zone set, no windows touched
#   scripts/screencast.sh cut f.mov  # → docs/agent-demo.gif and .mp4
#
# stage MOVES YOUR OWN WINDOWS. It asks first unless PLONK_YES=1.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
api=${PLONK_API:-http://127.0.0.1:43917}
command=${1:-stage}

post() {
  curl -sS -X POST "$api$1" -H 'Content-Type: application/json' -d "$2" >/dev/null
}

require_app() {
  curl -sS -m 2 "$api/ping" >/dev/null 2>&1 || {
    echo "screencast: Plonk is not running (no answer on $api)."
    echo "            Open Plonk.app, grant Accessibility, and try again."
    exit 1
  }
}

# The eight zones the drawn demo uses, so both assets show the same desk:
# three columns of 25 / 45 / 30 %, with rows that are not halves of anything.
# Fractions of the screen's visible area, origin top-left. Every edge is a
# multiple of 0.05, which is the grid the zone editor snaps to — so this is a
# set you could have drawn by hand, and the demo does not show one you could
# not. They tile exactly: the space between windows is the zone gap on the
# Zones page, which is real.
zone_set='{
  "name": "Demo Grid",
  "screen": 0,
  "zones": [
    {"x":0.00,"y":0.00,"w":0.25,"h":0.55},
    {"x":0.00,"y":0.55,"w":0.25,"h":0.45},
    {"x":0.25,"y":0.00,"w":0.45,"h":0.70},
    {"x":0.25,"y":0.70,"w":0.25,"h":0.30},
    {"x":0.50,"y":0.70,"w":0.20,"h":0.30},
    {"x":0.70,"y":0.00,"w":0.30,"h":0.35},
    {"x":0.70,"y":0.35,"w":0.30,"h":0.30},
    {"x":0.70,"y":0.65,"w":0.30,"h":0.35}
  ]
}'

# Eight apps most Macs already have. Override with a colon-separated list:
#   PLONK_DEMO_APPS="Safari:Ghostty:Cursor" scripts/screencast.sh stage
apps=${PLONK_DEMO_APPS:-Safari:Terminal:Notes:Reminders:Calendar:Music:Messages:Mail}

# Where each of them starts: overlapping, cascaded, a couple running off the
# edge. The mess is the argument, so it is worth building deliberately.
messy='[
  {"app":"%1","frame":{"x":0.06,"y":0.30,"w":0.46,"h":0.50}},
  {"app":"%2","frame":{"x":0.30,"y":0.13,"w":0.44,"h":0.52}},
  {"app":"%3","frame":{"x":0.19,"y":0.36,"w":0.40,"h":0.48}},
  {"app":"%4","frame":{"x":0.49,"y":0.21,"w":0.42,"h":0.46}},
  {"app":"%5","frame":{"x":0.11,"y":0.09,"w":0.36,"h":0.42}},
  {"app":"%6","frame":{"x":0.56,"y":0.44,"w":0.40,"h":0.46}},
  {"app":"%7","frame":{"x":0.33,"y":0.29,"w":0.38,"h":0.44}},
  {"app":"%8","frame":{"x":0.41,"y":0.50,"w":0.44,"h":0.44}}
]'

case "$command" in
grid)
  require_app
  post /zones/save "$zone_set"
  echo "screencast: saved \"Demo Grid\" and assigned it to screen 0"
  ;;

stage)
  require_app
  if [ "${PLONK_YES:-0}" != "1" ]; then
    printf 'This opens eight apps and throws their windows into a pile. Continue? [y/N] '
    read -r answer
    case "$answer" in y | Y | yes) ;; *) echo "screencast: nothing done"; exit 0 ;; esac
  fi

  post /zones/save "$zone_set"

  index=0
  items=$messy
  # Substitute each app name into its slot, and open it on the way past.
  old_ifs=$IFS
  IFS=:
  for app in $apps; do
    index=$((index + 1))
    [ "$index" -le 8 ] || break
    open -a "$app" >/dev/null 2>&1 || echo "screencast: no app called \"$app\", skipping"
    items=$(printf '%s' "$items" | sed "s|%$index|$app|")
  done
  IFS=$old_ifs

  echo "screencast: waiting for windows"
  sleep 4
  post /layout "{\"items\": $items}"

  cat <<'SHEET'

screencast: the desk is staged. The run sheet:

  1. Zones page → turn the gap up to about 12, numbers on. Pointer page →
     "Ring every click", so a click is visible in the recording.
     To open on the grid being drawn, delete "Demo Grid" first and cut it live
     in the editor: ⇧-click at 25% and 70% for the columns, then plain clicks
     for the rows. Seven clicks, about five seconds.
  2. ⇧⌘5 → record the whole screen. Give it a second of the mess before
     touching anything.
  3. Drag one window into a zone by hand — that is the beat that proves the
     zones are real and not a rendering.
  4. Press ⌃⌥3 to send the next one.
  5. Switch to the agent and send:

       tidy the rest into the grid — logs and chat on the right

  6. Let the windows land, hold two seconds on the finished desk, stop.
  7. scripts/screencast.sh cut ~/Desktop/<recording>.mov

Keep it under twenty seconds. Nobody watches the second half.
SHEET
  ;;

cut)
  source=${2:-}
  [ -n "$source" ] && [ -f "$source" ] || { echo "screencast: cut needs a .mov to encode"; exit 1; }
  command -v ffmpeg >/dev/null || { echo "screencast: ffmpeg is not installed"; exit 1; }

  width=${WIDTH:-960}
  fps=${FPS:-15}
  out=$root/docs/agent-demo.gif
  palette=${TMPDIR:-/tmp}/plonk-screencast-palette.png
  filters="fps=$fps,scale=$width:-1:flags=lanczos"

  # Same two passes as the drawn demo: a palette fitted to these frames, then
  # applied. A GIF has 256 colours, and the default palette bands every
  # gradient a real desktop has.
  ffmpeg -v error -y -i "$source" -vf "$filters,palettegen=stats_mode=diff" "$palette"
  ffmpeg -v error -y -i "$source" -i "$palette" \
    -lavfi "$filters [x]; [x][1:v] paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
    -loop 0 "$out"
  ffmpeg -v error -y -i "$source" -vf "scale=1440:-2:flags=lanczos" \
    -c:v libx264 -pix_fmt yuv420p -crf 22 -an -movflags +faststart "$root/docs/agent-demo.mp4"

  rm -f "$palette"
  for file in "$out" "$root/docs/agent-demo.mp4"; do
    ls -lh "$file" | awk '{print "screencast: wrote " $NF " (" $5 ")"}'
  done
  echo "screencast: over 5 MB is too big for a README — lower WIDTH or FPS and cut again"
  ;;

*)
  echo "usage: screencast.sh [stage|grid|cut <file.mov>]"
  exit 1
  ;;
esac
