"""Assemble the rendered frames into a looping GIF.

One palette is built from every frame at once and then reused for all of
them. Quantising each frame on its own would give each a slightly different
256 colours, and the gradients would crawl between frames.
"""
import sys
from pathlib import Path
from PIL import Image

HERE = Path(__file__).parent
FRAMES = sorted((HERE / "frames").glob("f*.png"))
W, H = 640, 340
FRAME_MS = 60          # must be a multiple of 10; GIF delays are centiseconds
COLORS = int(sys.argv[1]) if len(sys.argv) > 1 else 256
OUT = HERE / (sys.argv[2] if len(sys.argv) > 2 else "plonk-banner.gif")

imgs = [Image.open(p).convert("RGB").resize((W, H), Image.LANCZOS) for p in FRAMES]
assert FRAME_MS % 10 == 0, "GIF would round this delay and the loop would drift"
print(f"{len(imgs)} frames at {W}x{H}, {FRAME_MS} ms each = {len(imgs) * FRAME_MS} ms")

# every 3rd frame is enough to see the whole colour range
sample = imgs[::3]
strip = Image.new("RGB", (W, H * len(sample)))
for i, im in enumerate(sample):
    strip.paste(im, (0, H * i))
pal = strip.quantize(colors=COLORS, method=Image.MEDIANCUT)

# No dithering, and no disposal method. Both were measured on this banner:
# Floyd-Steinberg scatters noise across the flat mesh, which defeats LZW and
# costs ~500 KB; disposal=2 forces every frame to be stored whole, which
# defeats frame differencing and costs ~2.2 MB. Only the window moves here,
# so leaving both off is what makes the file 357 KB instead of 3.5 MB. The
# banding it trades away is invisible at 640 px over this palette.
frames = [im.quantize(palette=pal, dither=Image.Dither.NONE) for im in imgs]

frames[0].save(
    OUT,
    save_all=True,
    append_images=frames[1:],
    duration=FRAME_MS,
    loop=0,
    optimize=True,
)
print(f"{OUT.name}: {OUT.stat().st_size / 1024:.0f} KB, {COLORS} colours")
