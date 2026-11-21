"""Пересборка трёх мемов из проекта в 1080p.

Исходники вытащены из Orbita.vproj: подписи на них «запечены» в низком
разрешении, поэтому текст перерисовывается заново крупным чистым шрифтом,
а картинка апскейлится с мягким шафом.

На выходе на каждый мем:
  *_card_1920.png  — 1920x1080, прозрачный фон, карточка с тенью
  *_full_1920.png  — 1920x1080, тёмный брендовый фон, готовая плашка в кадр
  *_raw_1080.png   — сам мем в высоту 1080, если нужно заполнить кадр
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent
MEDIA = ROOT.parent / "analysis" / "media"
OUT = ROOT

ARIAL_BLACK = r"C:\Windows\Fonts\ariblk.ttf"
SEGOE_SEMIBOLD = r"C:\Windows\Fonts\seguisb.ttf"

CARD_W = 1200


def load(name):
    return Image.open(MEDIA / f"ObjectLibrary_{name}_Stream.png").convert("RGB")


def upscale(im, size):
    out = im.resize(size, Image.LANCZOS)
    return out.filter(ImageFilter.UnsharpMask(radius=2.0, percent=85, threshold=2))


def fit_width(draw, lines, path, max_w, start=120):
    size = start
    while size > 10:
        font = ImageFont.truetype(path, size)
        if max(draw.textlength(line, font=font) for line in lines) <= max_w:
            return font
        size -= 2
    return ImageFont.truetype(path, 10)


def draw_block(draw, lines, font, line_h, color, cx, top, spacing=1.0):
    y = top
    for line in lines:
        w = draw.textlength(line, font=font)
        draw.text((cx - w / 2, y), line, font=font, fill=color)
        y += line_h * spacing
    return y


def card_m1():
    src = load("Object4")          # 728x695, полоса-подпись 0..181
    scale = CARD_W / src.width
    band_h = round(182 * scale)
    photo = src.crop((0, 182, src.width, src.height))
    photo = upscale(photo, (CARD_W, round(photo.height * scale)))

    card = Image.new("RGB", (CARD_W, band_h + photo.height), (74, 114, 121))
    d = ImageDraw.Draw(card)
    for y in range(band_h):
        k = y / max(1, band_h)
        d.line([(0, y), (CARD_W, y)], fill=(int(74 - 8 * k), int(114 - 8 * k), int(121 - 8 * k)))

    lines = ["Мороженое и wi-fi для", "моего любимого фараона!"]
    font = fit_width(d, lines, SEGOE_SEMIBOLD, CARD_W * 0.90, 120)
    line_h = font.size * 1.18
    block_h = line_h * len(lines)
    draw_block(d, lines, font, line_h, (255, 255, 255), CARD_W / 2, (band_h - block_h) / 2)

    card.paste(photo, (0, band_h))
    ImageDraw.Draw(card).line([(0, band_h), (CARD_W, band_h)], fill=(255, 255, 255), width=4)
    return card


def card_m2():
    src = load("Object5")          # 604x552, белая полоса 0..166
    lines = [
        "КТО-ТО: ТЫ НЕ МОЖЕШЬ ПРОСТО ПЕРЕМЕСТИТЬСЯ",
        "ВО ВРЕМЕНИ В ДРЕВНИЙ ЕГИПЕТ И СОЗДАТЬ МЕМЫ",
    ]
    probe = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    font = fit_width(probe, lines, ARIAL_BLACK, CARD_W * 0.95, 110)
    line_h = font.size * 1.08
    ya_font = ImageFont.truetype(ARIAL_BLACK, int(font.size * 0.95))
    pad = int(font.size * 0.55)
    band_h = int(pad + line_h * 2 + font.size * 0.15 + ya_font.size * 1.35 + font.size * 0.95)

    scale = CARD_W / src.width
    photo = src.crop((0, 167, src.width, src.height))
    photo = upscale(photo, (CARD_W, round(photo.height * scale)))

    card = Image.new("RGB", (CARD_W, band_h + photo.height), (255, 255, 255))
    card.paste(photo, (0, band_h))
    ImageDraw.Draw(card).line([(0, band_h), (CARD_W, band_h)], fill=(205, 205, 205), width=3)
    d = ImageDraw.Draw(card)
    y = draw_block(d, lines, font, line_h, (0, 0, 0), CARD_W / 2, pad, spacing=1.0)
    d.text((CARD_W * 0.035, y + font.size * 0.02), "Я:", font=ya_font, fill=(0, 0, 0))
    return card


def card_m3():
    src = load("Object8")          # 640x480, подпись внизу поверх фото, текст с y=365
    scale = CARD_W / src.width
    card = upscale(src, (CARD_W, round(src.height * scale)))
    d = ImageDraw.Draw(card)

    band_top = int(card.height * (352 / 480))   # выше старой подписи, ниже подбородка
    d.rectangle([0, band_top, CARD_W, card.height], fill=(0, 0, 0))

    lines = ["А ВПРОЧЕМ, ЭТО УЖЕ", "СОВСЕМ ДРУГАЯ ИСТОРИЯ..."]
    font = fit_width(d, lines, ARIAL_BLACK, CARD_W * 0.90, 110)
    line_h = font.size * 1.1
    block_h = line_h * len(lines)
    draw_block(d, lines, font, line_h, (255, 255, 255), CARD_W / 2,
               band_top + ((card.height - band_top) - block_h) / 2)
    return card


def dark_background(w, h):
    top = (11, 16, 23)
    bottom = (22, 35, 47)
    bg = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(bg)
    for y in range(h):
        k = y / (h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * k) for i in range(3)))
    return bg


def place(card, canvas_w, canvas_h, target_h, with_shadow=True):
    scale = target_h / card.height
    c = card.resize((round(card.width * scale), target_h), Image.LANCZOS)
    layer = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    x = (canvas_w - c.width) // 2
    y = (canvas_h - c.height) // 2
    if with_shadow:
        sh = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
        sd = ImageDraw.Draw(sh)
        sd.rectangle([x + 6, y + 26, x + c.width - 6, y + c.height + 20], fill=(0, 0, 0, 160))
        sh = sh.filter(ImageFilter.GaussianBlur(24))
        layer = Image.alpha_composite(layer, sh)
    layer.paste(c.convert("RGBA"), (x, y))
    return layer


def main():
    builders = {"meme_icecream": card_m1, "meme_timetravel": card_m2, "meme_anotherstory": card_m3}
    for name, fn in builders.items():
        card = fn()
        place(card, 1920, 1080, 900).save(OUT / f"{name}_card_1920.png")
        full = dark_background(1920, 1080)
        layer = place(card, 1920, 1080, 960)
        full = Image.alpha_composite(full.convert("RGBA"), layer).convert("RGB")
        full.save(OUT / f"{name}_full_1920.png")
        raw = card.resize((round(card.width * 1080 / card.height), 1080), Image.LANCZOS)
        raw.save(OUT / f"{name}_raw_1080.png")
        print(f"{name}: карточка {card.width}x{card.height}")


if __name__ == "__main__":
    main()
