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
FPS = 12
COLORS = int(sys.argv[1]) if len(sys.argv) > 1 else 256
OUT = HERE / (sys.argv[2] if len(sys.argv) > 2 else "plonk-banner.gif")

imgs = [Image.open(p).convert("RGB").resize((W, H), Image.LANCZOS) for p in FRAMES]
print(f"{len(imgs)} frames at {W}x{H}")

# every 3rd frame is enough to see the whole colour range
sample = imgs[::3]
strip = Image.new("RGB", (W, H * len(sample)))
for i, im in enumerate(sample):
    strip.paste(im, (0, H * i))
pal = strip.quantize(colors=COLORS, method=Image.MEDIANCUT)

frames = [im.quantize(palette=pal, dither=Image.Dither.FLOYDSTEINBERG) for im in imgs]

frames[0].save(
    OUT,
    save_all=True,
    append_images=frames[1:],
    duration=round(1000 / FPS),
    loop=0,
    optimize=True,
    disposal=2,
)
print(f"{OUT.name}: {OUT.stat().st_size / 1024:.0f} KB, {COLORS} colours")
