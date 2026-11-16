"""Render the Vasmim app icon at every Windows size from one 64-unit design.

Usage (needs Pillow):  python tool/icon/make_app_icon.py
Writes windows/runner/resources/app_icon.ico. Pass a folder to also write a
PNG per size and a contact sheet there for inspection.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
ICO = ROOT / 'windows' / 'runner' / 'resources' / 'app_icon.ico'
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else None
FOREST = (47, 74, 58, 255)
CREAM = (247, 242, 232, 255)
NOTES = [  # x, y, w, h, radius, body, header
    (12, 13, 22, 18, 4.0, (255, 226, 122, 255), (240, 190, 60, 255)),
    (34, 34, 19, 17, 4.0, (191, 227, 255, 255), (125, 186, 238, 255)),
    (13, 38, 14, 12, 3.5, (246, 200, 220, 255), (232, 150, 186, 255)),
]

def render(size):
    ss = 8                       # supersampling factor
    k = size * ss / 64.0         # design units -> pixels
    img = Image.new('RGBA', (size * ss, size * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    def box(x, y, w, h):
        return [round(x * k), round(y * k), round((x + w) * k) - 1, round((y + h) * k) - 1]
    d.rounded_rectangle(box(4, 4, 56, 56), radius=round(13 * k), fill=FOREST)
    small = size <= 24
    if not small:                # the connector only reads at 32 px and up
        d.line([round(24 * k), round(24 * k), round(42 * k), round(40 * k)],
               fill=CREAM, width=max(1, round(3 * k)))
    for x, y, w, h, r, body, header in NOTES:
        d.rounded_rectangle(box(x, y, w, h), radius=round(r * k), fill=body)
        if size >= 32:           # a darker header band makes each card read as a note
            band = Image.new('RGBA', img.size, (0, 0, 0, 0))
            bd = ImageDraw.Draw(band)
            bd.rounded_rectangle(box(x, y, w, h), radius=round(r * k), fill=header)
            cut = round((y + h * 0.28) * k)
            bd.rectangle([0, cut, img.size[0], img.size[1]], fill=(0, 0, 0, 0))
            img.alpha_composite(band)
    return img.resize((size, size), Image.LANCZOS)

sizes = [256, 128, 96, 64, 48, 40, 32, 24, 20, 16]
images = {s: render(s) for s in sizes}
images[256].save(ICO, format='ICO',
                 sizes=[(s, s) for s in sizes],
                 append_images=[images[s] for s in sizes[1:]])
if OUT is None:
    print('wrote', ICO)
    sys.exit(0)
OUT.mkdir(parents=True, exist_ok=True)
for s, im in images.items():
    im.save(OUT / f'icon-{s}.png')
# contact sheet, each size shown at 1x and enlarged 4x for inspection
sheet = Image.new('RGBA', (1180, 560), (240, 240, 240, 255))
x = 10
for s in [256, 64, 48, 32, 24, 16]:
    sheet.alpha_composite(images[s], (x, 10))
    big = images[s].resize((s * 4 if s <= 32 else s, s * 4 if s <= 32 else s), Image.NEAREST)
    sheet.alpha_composite(big, (x, 290))
    x += max(s, big.size[0]) + 20
dark = Image.new('RGBA', (180, 60), (32, 32, 32, 255))
for i, s in enumerate([16, 24, 32, 48]):
    dark.alpha_composite(images[s], (8 + i * 42, 6))
sheet.alpha_composite(dark, (980, 10))
sheet.save(OUT / 'sheet.png')
print('wrote', ICO, 'and previews in', OUT)
