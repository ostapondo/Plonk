#!/bin/sh
# Rebuilds the drawn animations in docs/ from scripts/demo/.
#
#   scripts/make-demo.sh              all three
#   scripts/make-demo.sh zones        just docs/zones.gif
#
# One scene per thing the documentation has to show, named after what it
# writes: demo.swift is the README's hero, agents.swift the picture on
# docs/agents.md, zones.swift the one on docs/zones.md. Each is kit.swift plus
# a timeline — the kit draws the desk, the scene says what happens on it — and
# the two are concatenated here rather than compiled as a module, so a scene
# stays a script anyone can run with `swift` and no build step.
#
# The animations are drawn rather than recorded: no screen capture, no timing
# to get right by hand, and they do not go stale the next time some other app
# is redesigned.
#
# Needs ffmpeg (brew install ffmpeg).
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
scenes=${*:-demo agents zones}

width=${WIDTH:-720}
# What the scenes render at, and what the GIF is decimated to. They are two
# different numbers: telling ffmpeg the input is 14fps when it is 20 does not
# drop frames, it slows the whole thing down to 0.7x.
source_fps=20
fps=${FPS:-14}

command -v ffmpeg >/dev/null || { echo "make-demo: ffmpeg is not installed"; exit 1; }

for scene in $scenes; do
    source=$root/scripts/demo/$scene.swift
    [ -f "$source" ] || { echo "make-demo: no scene called $scene"; exit 1; }

    frames=${TMPDIR:-/tmp}/plonk-demo-$scene
    combined=$frames.swift
    rm -rf "$frames"
    cat "$root/scripts/demo/kit.swift" "$source" > "$combined"
    swift "$combined" "$frames" >/dev/null

    # Two passes: one to work out a palette that suits these frames, one to
    # apply it. A GIF has 256 colours, and the default palette turns the
    # gradients into bands.
    #
    # Undithered, which is the one setting worth explaining. These frames are
    # flat fills and one soft gradient, so a palette chosen for them lands on
    # the flat colours exactly and has bands to hide only in the wallpaper.
    # Dithering scatters pixels there to smooth it, and since every scattered
    # pixel differs from its neighbour it costs about a third of the file for a
    # difference nobody can see at this size.
    palette=$frames/palette.png
    filters="fps=$fps,scale=$width:-1:flags=lanczos"
    ffmpeg -v error -y -framerate "$source_fps" -i "$frames/frame-%04d.png" \
        -vf "$filters,palettegen=stats_mode=diff:max_colors=200" "$palette"
    ffmpeg -v error -y -framerate "$source_fps" -i "$frames/frame-%04d.png" -i "$palette" \
        -lavfi "$filters [x]; [x][1:v] paletteuse=dither=none:diff_mode=rectangle" \
        -loop 0 "$root/docs/$scene.gif"

    # The same frames as h.264, for anywhere a GIF is the wrong shape.
    ffmpeg -v error -y -framerate "$source_fps" -i "$frames/frame-%04d.png" \
        -vf "scale=1200:-2:flags=lanczos" -c:v libx264 -pix_fmt yuv420p -crf 20 \
        -movflags +faststart "$root/docs/$scene.mp4"

    rm -rf "$frames" "$combined"
    for file in "$root/docs/$scene.gif" "$root/docs/$scene.mp4"; do
        ls -lh "$file" | awk '{print "make-demo: wrote " $NF " (" $5 ")"}'
    done
done
