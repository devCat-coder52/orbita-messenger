from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

MEDIA = Path(r"D:\Projects\messanger\messenger\presentation\analysis\media")
OUT = Path(r"D:\Projects\messanger\messenger\presentation\analysis")
FONT = r"C:\Windows\Fonts\segoeui.ttf"

files = sorted(p for p in MEDIA.glob("ObjectLibrary_Object*_Stream.png") if "Thumbnail" not in p.name)
cols, cw, ch = 3, 620, 380
rows = (len(files) + cols - 1) // cols
sheet = Image.new("RGB", (cols * cw + 20, rows * ch + 20), (16, 18, 22))
d = ImageDraw.Draw(sheet)
f = ImageFont.truetype(FONT, 20)
fs = ImageFont.truetype(FONT, 16)
for i, p in enumerate(files):
    im = Image.open(p).convert("RGB")
    w, h = im.size
    im.thumbnail((cw - 30, ch - 70), Image.LANCZOS)
    x = 10 + (i % cols) * cw
    y = 10 + (i // cols) * ch
    sheet.paste(im, (x + (cw - 30 - im.width) // 2, y))
    d.text((x + 10, y + ch - 62), p.name.replace("ObjectLibrary_", "").replace("_Stream.png", ""), font=f, fill=(240, 244, 248))
    d.text((x + 10, y + ch - 34), f"{w}x{h}", font=fs, fill=(140, 200, 240))
sheet.save(OUT / "media_sheet_labeled.png")
print(sheet.size, [p.name for p in files])
