from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import random


ROOT = Path(__file__).resolve().parents[1]
FONT_ROOT = Path("/Users/ostapbelei/.codex/skills/canvas-design/canvas-fonts")
LOGO = ROOT / "logo-400.png"

PAPER = (239, 235, 224)
CARBON = (23, 24, 28)
ROSE = (255, 79, 129)
BLUE = (58, 107, 255)
PLUM = (139, 92, 246)
MINT = (18, 211, 164)
SUN = (255, 197, 49)
INKS = (ROSE, BLUE, PLUM, MINT, SUN)


def font(name: str, size: int):
    return ImageFont.truetype(str(FONT_ROOT / name), size)


def paper(size, seed):
    random.seed(seed)
    image = Image.new("RGB", size, PAPER)
    pixels = image.load()
    for y in range(size[1]):
        for x in range(size[0]):
            grain = random.choice((-3, -2, -1, 0, 0, 0, 1, 2, 3))
            pixels[x, y] = tuple(max(0, min(255, c + grain)) for c in PAPER)
    return image


def paste_logo(image, box):
    logo = Image.open(LOGO).convert("RGBA")
    logo.thumbnail((box[2], box[3]), Image.Resampling.LANCZOS)
    x = box[0] + (box[2] - logo.width) // 2
    y = box[1] + (box[3] - logo.height) // 2
    shadow = Image.new("RGBA", image.size)
    mask = Image.new("L", image.size)
    mask.paste(logo.getchannel("A"), (x, y))
    blurred = mask.filter(ImageFilter.GaussianBlur(20))
    shadow.paste((0, 0, 0, 80), mask=blurred)
    image.paste(shadow, (0, 0), shadow)
    image.paste(logo, (x, y), logo)


def registration(draw, x, y, colour=CARBON):
    draw.line((x - 12, y, x + 12, y), fill=colour, width=2)
    draw.line((x, y - 12, x, y + 12), fill=colour, width=2)
    draw.ellipse((x - 4, y - 4, x + 4, y + 4), outline=colour, width=2)


def module(draw, rect, colour, offset=0):
    x0, y0, x1, y1 = rect
    draw.rectangle((x0 + offset, y0 + offset, x1 + offset, y1 + offset), fill=CARBON)
    draw.rectangle((x0, y0, x1, y1), fill=colour)


def render_hero():
    image = paper((1600, 900), 41)
    draw = ImageDraw.Draw(image)

    draw.rectangle((0, 0, 540, 900), fill=CARBON)
    draw.rectangle((80, 76, 86, 704), fill=ROSE)
    draw.text((116, 73), "PLONK", font=font("BigShoulders-Bold.ttf", 142), fill=PAPER)
    draw.text((120, 226), "ONE PLACE / MANY WAYS", font=font("DMMono-Regular.ttf", 21), fill=(174, 174, 177))
    draw.text((120, 760), "NATIVE  ·  LOCAL  ·  MODULAR", font=font("DMMono-Regular.ttf", 18), fill=PAPER)
    draw.text((120, 800), "08 / MACOS", font=font("DMMono-Regular.ttf", 15), fill=(174, 174, 177))

    modules = [
        ((620, 88, 916, 228), ROSE, 10),
        ((938, 88, 1518, 228), BLUE, 10),
        ((620, 250, 770, 496), MINT, 10),
        ((792, 250, 1120, 496), PAPER, 10),
        ((1142, 250, 1518, 496), SUN, 10),
        ((620, 518, 1010, 812), PLUM, 10),
        ((1032, 518, 1246, 812), ROSE, 10),
        ((1268, 518, 1518, 812), BLUE, 10),
    ]
    for rect, colour, offset in modules:
        module(draw, rect, colour, offset)

    draw.rectangle((792, 250, 1120, 496), fill=CARBON)
    paste_logo(image, (822, 270, 268, 206))
    registration(draw, 620, 840)
    registration(draw, 1518, 840)
    draw.line((620, 840, 1518, 840), fill=CARBON, width=2)
    draw.text((1375, 853), "FIELD 01", font=font("DMMono-Regular.ttf", 14), fill=CARBON)
    image.save(ROOT / "brand-hero.png", optimize=True)


def render_social():
    image = paper((1280, 640), 73)
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, 500, 640), fill=CARBON)
    draw.rectangle((62, 56, 68, 466), fill=ROSE)
    draw.text((98, 51), "PLONK", font=font("BigShoulders-Bold.ttf", 116), fill=PAPER)
    draw.text((100, 176), "A TOOLBOX FOR YOUR MAC.", font=font("DMMono-Regular.ttf", 18), fill=(184, 184, 187))
    draw.text((100, 516), "ONE ICON / MANY WAYS", font=font("DMMono-Regular.ttf", 16), fill=PAPER)

    modules = [
        ((550, 56, 762, 188), ROSE, 8),
        ((780, 56, 1220, 188), BLUE, 8),
        ((550, 206, 696, 426), MINT, 8),
        ((714, 206, 978, 426), PAPER, 8),
        ((996, 206, 1220, 426), SUN, 8),
        ((550, 444, 828, 582), PLUM, 8),
        ((846, 444, 1016, 582), ROSE, 8),
        ((1034, 444, 1220, 582), BLUE, 8),
    ]
    for rect, colour, offset in modules:
        module(draw, rect, colour, offset)
    draw.rectangle((714, 206, 978, 426), fill=CARBON)
    paste_logo(image, (735, 223, 222, 186))
    registration(draw, 550, 608)
    draw.line((550, 608, 1220, 608), fill=CARBON, width=2)
    image.save(ROOT / "social-preview.png", optimize=True)


render_hero()
render_social()
