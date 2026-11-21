from pathlib import Path

import numpy as np
from PIL import Image

MEDIA = Path(r"D:\Projects\messanger\messenger\presentation\analysis\media")
LABELS = {
    "ObjectLibrary_Object0_Stream.png": "логотип Orbita (наш фон 4K)",
    "ObjectLibrary_Object1_Stream.png": "первобытные люди у костра",
    "ObjectLibrary_Object2_Stream.png": "мем «Мороженое и wi-fi для фараона»",
    "ObjectLibrary_Object3_Stream.png": "первобытная сцена",
    "ObjectLibrary_Object4_Stream.png": "египетская фреска",
    "ObjectLibrary_Object5_Stream.png": "мем «переместиться в Древний Египет»",
    "ObjectLibrary_Object6_Stream.png": "писец за работой",
    "ObjectLibrary_Object7_Stream.png": "Кирилл и Мефодий (скриншот YouTube)",
    "ObjectLibrary_Object8_Stream.png": "мем «совсем другая история»",
}

rows = []
for name, label in LABELS.items():
    p = MEDIA / name
    im = Image.open(p).convert("RGB")
    w, h = im.size
    arr = np.asarray(im, dtype=np.float32)
    scale = max(1920 / w, 1080 / h)
    lum = 0.2126 * arr[..., 0] + 0.7152 * arr[..., 1] + 0.0722 * arr[..., 2]
    sat = (arr.max(axis=2) - arr.min(axis=2)).mean()
    rb = arr[..., 0].mean() / max(1e-6, arr[..., 2].mean())
    rows.append((label, w, h, scale, lum.mean(), lum.std(), sat, rb))

hdr = f"{'кадр':38s} {'размер':>10s} {'×':>6s} {'ярк':>5s} {'контр':>6s} {'насыщ':>6s} {'R/B':>5s}"
print(hdr)
print("-" * len(hdr))
for label, w, h, scale, lum, std, sat, rb in rows:
    mark = "  ← апскейл" if scale > 1 else ""
    print(f"{label:38s} {w:4d}x{h:<4d} {scale:5.2f} {lum:5.0f} {std:6.1f} {sat:6.0f} {rb:5.2f}{mark}")

scales = [r[3] for r in rows if r[3] > 1]
print(f"\nсредний апскейл по кадрам: {sum(scales)/len(scales):.2f}x, максимум {max(scales):.2f}x")
lums = [r[4] for r in rows]
print(f"разброс яркости: {min(lums):.0f}..{max(lums):.0f} (дельта {max(lums)-min(lums):.0f})")
rbs = [r[7] for r in rows]
print(f"разброс цветового баланса R/B: {min(rbs):.2f}..{max(rbs):.2f}")
