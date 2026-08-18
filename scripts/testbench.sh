#!/bin/sh
# Throwaway windows to demonstrate a window fix on, so nobody has to move their
# real ones to prove a patch works.
#
# Window bugs live on hardware the maintainer does not have, so the useful part
# of a report is rarely the patch — it is the before and after. This gives both
# sides the same desk to talk about: N TextEdit windows with known titles, and
# a way to print where they actually landed.
#
#   ./scripts/testbench.sh up [n]   open n windows (default 4)
#   ./scripts/testbench.sh state    print where each one is now
#   ./scripts/testbench.sh down     close them and delete the files
#
# TextEdit, because a second window of one app cannot be conjured — it has to
# be given a file to open — and because these are files nobody minds losing.
set -eu

DIR="${TMPDIR:-/tmp}/plonk-testbench"
PREFIX=plonk-bench
API=http://127.0.0.1:43917
TOKEN_FILE="$HOME/Library/Application Support/Plonk/token"

usage() {
    sed -n '2,12p' "$0" | cut -c 3-
    exit "${1:-0}"
}

token() {
    [ -r "$TOKEN_FILE" ] || return 1
    cat "$TOKEN_FILE"
}

up() {
    count=${1:-4}
    case "$count" in
        ''|*[!0-9]*) printf 'testbench: window count must be a number, got "%s"\n' "$count" >&2; exit 1 ;;
    esac
    [ "$count" -ge 1 ] && [ "$count" -le 9 ] || {
        printf 'testbench: between 1 and 9 windows, so they map onto the zone keys\n' >&2
        exit 1
    }

    mkdir -p "$DIR"
    i=1
    while [ "$i" -le "$count" ]; do
        file="$DIR/$PREFIX-$i.txt"
        printf 'Plonk test window %s.\nSafe to close; this file is a scratch file.\n' "$i" > "$file"
        # One at a time: TextEdit places windows as they open, and opening them
        # in a batch cascades them on top of each other.
        open -a TextEdit "$file"
        i=$((i + 1))
    done

    printf 'Opened %s windows titled %s-1.txt … %s-%s.txt\n' "$count" "$PREFIX" "$PREFIX" "$count"
    printf 'Arrange them, then: ./scripts/testbench.sh state\n'
    printf 'When you are done:  ./scripts/testbench.sh down\n'
}

# Prints one line per bench window: title, screen, and the frame in the same
# fractions apply_layout takes, which is the form worth pasting into a pull
# request — pixels mean nothing without knowing the monitor.
state() {
    tok=$(token) || {
        printf 'testbench: no API token at %s — is Plonk.app running?\n' "$TOKEN_FILE" >&2
        exit 1
    }
    body=$(curl -sf -H "X-Plonk-Token: $tok" "$API/state") || {
        printf 'testbench: %s did not answer. Launch Plonk.app first.\n' "$API" >&2
        exit 1
    }

    # python3 rather than node: the Command Line Tools that Swift already needs
    # bring it, so this works for someone who never touches mcp/.
    printf '%s\n' "$body" | PREFIX="$PREFIX" python3 -c '
import json, os, sys

state = json.load(sys.stdin)
prefix = os.environ["PREFIX"]
mine = [w for w in state["windows"] if w["title"].startswith(prefix)]

if not mine:
    print("No bench windows open. ./scripts/testbench.sh up")
    sys.exit(0)

for s in state["screens"]:
    print("screen %d  %dx%d" % (s["index"], round(s["visible"]["w"]), round(s["visible"]["h"])))

for w in sorted(mine, key=lambda w: w["title"]):
    f = w.get("fraction")
    if f:
        at = "x %.3f  y %.3f  w %.3f  h %.3f" % (f["x"], f["y"], f["w"], f["h"])
    else:
        at = "%d,%d %dx%d" % (
            round(w["frame"]["x"]), round(w["frame"]["y"]),
            round(w["frame"]["w"]), round(w["frame"]["h"]),
        )
    print("  %-22s screen %d  %s" % (w["title"], w["screen"], at))
'
}

down() {
    # Only documents this script opened, and never saving: a bench file is
    # scratch, and a save dialog would leave the desk worse than it found it.
    osascript -e "tell application \"TextEdit\"
        repeat with d in (every document whose name starts with \"$PREFIX\")
            close d saving no
        end repeat
    end tell" >/dev/null 2>&1 || true
    rm -rf "$DIR"
    printf 'Bench windows closed and %s removed.\n' "$DIR"
}

case "${1:-}" in
    up) shift; up "$@" ;;
    state) state ;;
    down) down ;;
    ''|-h|--help|help) usage 0 ;;
    *) printf 'testbench: unknown command "%s"\n\n' "$1" >&2; usage 1 ;;
esac
