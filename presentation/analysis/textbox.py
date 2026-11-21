from pathlib import Path

import numpy as np
from PIL import Image

p = Path(r"D:\Projects\messanger\messenger\presentation\analysis\media\ObjectLibrary_Object8_Stream.png")
a = np.asarray(Image.open(p).convert("RGB"), dtype=np.float32)
lum = a.mean(axis=2)
mask = lum > 235
mask[: int(a.shape[0] * 0.6)] = False
ys, xs = np.nonzero(mask)
print("bright text top:", ys.min(), "bottom:", ys.max(), "left:", xs.min(), "right:", xs.max())
print("height:", a.shape[0], "0.72*H:", 0.72 * a.shape[0])
