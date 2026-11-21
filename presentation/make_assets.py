"""Подготовка аватарки Orbita и иконки приложения для презентации."""

import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ASSETS = Path(__file__).resolve().parent / "assets"
ASSETS.mkdir(exist_ok=True)

SRC = ROOT / "messanger_backend" / "assets" / "orbita.png"

img = Image.open(SRC).convert("RGBA")
img.resize((1024, 1024), Image.LANCZOS).save(ASSETS / "orbita.png")
print(f"orbita.png: {img.size} -> 1024x1024")

# Основная иконка приложения и её прозрачная версия для тёмных слайдов.
ICON = ROOT / "messanger_app" / "assets" / "icon" / "app_icon.png"
if ICON.exists():
    shutil.copy(ICON, ASSETS / "app_icon.png")
    icon = Image.open(ICON).convert("RGBA")
    px = icon.load()
    bg = (44, 62, 80)
    for y in range(icon.height):
        for x in range(icon.width):
            r, g, b, a = px[x, y]
            if a and abs(r - bg[0]) < 10 and abs(g - bg[1]) < 10 and abs(b - bg[2]) < 10:
                px[x, y] = (0, 0, 0, 0)
    icon.save(ASSETS / "app_icon_mark.png")
    print("app_icon.png + app_icon_mark.png готовы")


# Котик для анонса: подгоняем фон под фирменный тёмно-синий.
cat_src = ASSETS / "cat_anons.png"
if cat_src.exists():
    bg, navy = (22, 35, 51), (44, 62, 80)
    cat = Image.open(cat_src).convert("RGB")
    px = cat.load()
    for y in range(cat.height):
        for x in range(cat.width):
            r, g, b = px[x, y]
            if abs(r - bg[0]) <= 4 and abs(g - bg[1]) <= 4 and abs(b - bg[2]) <= 4:
                px[x, y] = navy
    cat.save(ASSETS / "cat_anons_navy.png")
    print("cat_anons_navy.png: фон приведён к #2C3E50")

