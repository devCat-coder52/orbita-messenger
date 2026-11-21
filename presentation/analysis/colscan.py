from pathlib import Path

import numpy as np
from PIL import Image

M = Path(r"D:\Projects\messanger\messenger\presentation\analysis\media")

for name in ("Object4", "Object5", "Object8"):
    im = Image.open(M / f"ObjectLibrary_{name}_Stream.png").convert("RGB")
    a = np.asarray(im)
    h, w, _ = a.shape
    print(f"=== {name} {w}x{h}")
    col = a[:, 2, :]
    prev = None
    for y in range(h):
        c = tuple(int(v) for v in col[y])
        if prev is None or max(abs(c[i] - prev[i]) for i in range(3)) > 25:
            print(f"  y={y:4d} {c}")
            prev = c
    # верхние 12 пикселей по x=w//2
    print("  top color:", tuple(int(v) for v in a[2, w // 2]))
    print("  mid color:", tuple(int(v) for v in a[h // 2, w // 2]))
