"""Generate 512x512 MM pixel logo PNG for launcher/splash. pip install Pillow"""
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    raise SystemExit("pip install Pillow")

W = 512
CYAN = (0, 245, 212, 255)
MAGENTA = (255, 0, 110, 255)
BG = (13, 2, 33, 255)

img = Image.new("RGBA", (W, W), BG)
cell = W / 32.0
draw = ImageDraw.Draw(img)


def px(gx, gy, c):
    x0, y0 = int(gx * cell), int(gy * cell)
    x1, y1 = int((gx + 1) * cell), int((gy + 1) * cell)
    draw.rectangle([x0, y0, x1, y1], fill=c)


for y in range(2, 14):
    px(2, y, CYAN)
    px(3, y, CYAN)
for x, y in [(4, 4), (5, 5), (6, 6), (7, 5), (8, 4)]:
    px(x, y, CYAN)
for y in range(2, 14):
    px(9, y, CYAN)
    px(10, y, CYAN)

for y in range(2, 14):
    px(12, y, MAGENTA)
    px(13, y, MAGENTA)
for x, y in [(14, 4), (15, 5), (16, 6), (17, 5), (18, 4)]:
    px(x, y, MAGENTA)
for y in range(2, 14):
    px(19, y, MAGENTA)
    px(20, y, MAGENTA)

out = Path(__file__).resolve().parent.parent / "assets" / "images" / "mm_icon_512.png"
out.parent.mkdir(parents=True, exist_ok=True)
img.save(out, "PNG")
print("Wrote", out)
