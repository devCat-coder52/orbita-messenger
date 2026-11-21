from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
FONT = r"C:\Windows\Fonts\segoeui.ttf"

names = [
    ("meme_icecream_full_1920.png", "Мороженое и wi-fi"),
    ("meme_timetravel_full_1920.png", "Переместиться в Египет"),
    ("meme_anotherstory_full_1920.png", "Совсем другая история"),
]

cell_w, cell_h = 640, 360
pad = 20
sheet = Image.new("RGB", (3 * cell_w + 4 * pad, cell_h + 90), (12, 16, 22))
d = ImageDraw.Draw(sheet)
f = ImageFont.truetype(FONT, 22)

for i, (name, label) in enumerate(names):
    im = Image.open(ROOT / name).convert("RGB").resize((cell_w, cell_h), Image.LANCZOS)
    x = pad + i * (cell_w + pad)
    sheet.paste(im, (x, pad))
    d.text((x, pad + cell_h + 20), label, font=f, fill=(235, 240, 245))

sheet.save(ROOT / "preview_all.png")
print(sheet.size)
