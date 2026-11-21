from pathlib import Path

import numpy as np
from PIL import Image

M = Path(r"D:\Projects\messanger\messenger\presentation\analysis\media")


def analyse(name):
    p = M / f"ObjectLibrary_{name}_Stream.png"
    im = Image.open(p).convert("RGB")
    a = np.asarray(im, dtype=np.float32)
    h, w, _ = a.shape
    std = a.std(axis=(1, 2))
    uniform = std < 12
    # границы переходов однородно/неоднородно
    edges = [y for y in range(1, h) if uniform[y] != uniform[y - 1]]
    print(f"{name}: {w}x{h}, однородные полосы:", edges[:20])

    # bbox ярких пикселей в нижней половине (текст мема)
    lum = a.mean(axis=2)
    mask = lum > 225
    half = mask[h // 2:]
    ys, xs = np.nonzero(half)
    if len(ys):
        print("   яркий текст bbox: y", int(ys.min() + h // 2), "..", int(ys.max() + h // 2),
              " x", int(xs.min()), "..", int(xs.max()))


for n in ("Object4", "Object5", "Object8"):
    analyse(n)
