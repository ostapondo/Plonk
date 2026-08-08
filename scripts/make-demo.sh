#!/bin/sh
# Rebuilds docs/demo.gif from scripts/make-demo.swift.
#
# The animation is drawn rather than recorded, so anyone with this repo can
# regenerate it: no screen capture, no timing to get right by hand, and it does
# not go stale the next time some other app is redesigned.
#
# Needs ffmpeg (brew install ffmpeg).
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
frames=${TMPDIR:-/tmp}/plonk-demo-frames
out=$root/docs/demo.gif
width=${WIDTH:-720}
# What make-demo.swift renders at, and what the GIF is decimated to. They are
# two different numbers: telling ffmpeg the input is 16fps when it is 20 does
# not drop frames, it slows the whole thing down to 0.8x.
source_fps=20
fps=${FPS:-16}

command -v ffmpeg >/dev/null || { echo "make-demo: ffmpeg is not installed"; exit 1; }

rm -rf "$frames"
swift "$root/scripts/make-demo.swift" "$frames"

# Two passes: one to work out a palette that suits these frames, one to apply
# it. A GIF has 256 colours, and the default palette turns the gradients into
# bands.
palette=$frames/palette.png
filters="fps=$fps,scale=$width:-1:flags=lanczos"
ffmpeg -v error -y -framerate "$source_fps" -i "$frames/frame-%04d.png" \
  -vf "$filters,palettegen=stats_mode=diff" "$palette"
ffmpeg -v error -y -framerate "$source_fps" -i "$frames/frame-%04d.png" -i "$palette" \
  -lavfi "$filters [x]; [x][1:v] paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
  -loop 0 "$out"

# The same frames as h.264, for anywhere a GIF is the wrong shape.
ffmpeg -v error -y -framerate "$source_fps" -i "$frames/frame-%04d.png" \
  -vf "scale=1200:-2:flags=lanczos" -c:v libx264 -pix_fmt yuv420p -crf 20 \
  -movflags +faststart "$root/docs/demo.mp4"

rm -rf "$frames"
for file in "$out" "$root/docs/demo.mp4"; do
  ls -lh "$file" | awk '{print "make-demo: wrote " $NF " (" $5 ")"}'
done
