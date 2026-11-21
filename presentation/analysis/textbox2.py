from pathlib import Path
import numpy as np
from PIL import Image
p = Path(r"D:\Projects\messanger\messenger\presentation\analysis\media\ObjectLibrary_Object8_Stream.png")
a = np.asarray(Image.open(p).convert("RGB"), dtype=np.float32)
lum = a.mean(axis=2)
sub = lum[280:480, 20:540]
mask = sub > 240
ys, xs = np.nonzero(mask)
print("top y:", 280 + ys.min(), "bottom:", 280 + ys.max(), "x:", 20 + xs.min(), 20 + xs.max())
# распределение по строкам
for y in range(280, 480, 5):
    cnt = int((lum[y, 20:540] > 240).sum())
    if cnt: print(y, cnt)
