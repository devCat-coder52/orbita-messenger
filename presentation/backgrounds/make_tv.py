"""5 секунд «старый телевизор» из фона с логотипом: честная аналоговая помеха.

В отличие от первой версии, шум не мелкий цифровой, а крупный, смазанный по
строке — как «снег» на антенне. Плюс вертикальный уход кадра, дрожание строк,
двоение сигнала, полосы, провалы сигнала и потеря цвета.

Источник: bg_logo_center_4k.png (3840x2160) -> 1920x1080.
"""

import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import imageio_ffmpeg

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "bg_logo_center_4k.png"
SOFT = "--soft" in __import__("sys").argv
OUT = ROOT / ("orbita_tv_soft_5s.mp4" if SOFT else "orbita_tv_5s.mp4")

W, H, FPS, DUR = 1920, 1080, 25, 5.0
N = int(FPS * DUR)


def smoothstep(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3 - 2 * x)


BASE = np.asarray(Image.open(SRC).convert("RGB").resize((W, H), Image.LANCZOS), dtype=np.float32)

yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
NX = (xx - W / 2) / (W / 2)
NY = (yy - H / 2) / (H / 2)
R2 = NX * NX + NY * NY

vig = np.clip(1.16 - 0.66 * (R2 ** 1.1), 0.24, 1.0)[..., None]

corner = Image.new("L", (W, H), 0)
ImageDraw.Draw(corner).rounded_rectangle([12, 12, W - 13, H - 13], radius=96, fill=255)
CORNER = np.asarray(corner.filter(ImageFilter.GaussianBlur(8)), dtype=np.float32)[..., None] / 255.0

# строки развёртки: 1 пиксель через 1
lines = np.ones((H, 1), dtype=np.float32)
lines[::2] = 0.66
LINES = lines[..., None]

# мягкая «гребёнка» по всему кадру
band_mask = np.exp(-((np.arange(H) - H / 2) / (H * 0.55)) ** 2).astype(np.float32)
BAND = band_mask[:, None, None]

rng = np.random.default_rng(37)

# провалы сигнала: (начало, длина в кадрах, сила)
DROPS = [(1.90, 2, 0.55)] if SOFT else [(1.90, 2, 0.75), (3.62, 1, 0.55), (4.70, 2, 0.35)]


def distort(frame, t):
    s = 1.0 + 0.02 * t
    f = (1.0 + 0.10 * R2) / s
    sx = (W / 2 + NX * f * (W / 2)).astype(np.int32)
    sy = (H / 2 + NY * f * (H / 2)).astype(np.int32)
    # дрожание строк: медленная волна + рваное покачивание
    wobble = (1.8 * np.sin(2 * np.pi * (yy[:, 0] / H * 2.2 + t * 0.45))
              + 0.8 * np.sin(2 * np.pi * (yy[:, 0] / H * 7.0 - t * 1.9)))
    sx = sx + wobble.astype(np.int32)[:, None]
    np.clip(sx, 0, W - 1, out=sx)
    np.clip(sy, 0, H - 1, out=sy)
    return frame[sy, sx]


def vertical_roll(frame, t):
    """Уход кадра по вертикали: маленький дрейф + провал синхронизации."""
    off = 5.0 * t
    if 2.55 < t < 3.05:
        off += (90.0 if SOFT else 150.0) * np.sin(np.pi * (t - 2.55) / 0.5)
    k = int(off) % H
    if k == 0:
        return frame
    out = np.empty_like(frame)
    out[k:] = frame[:H - k]
    out[:k] = frame[H - k:]
    return out


def ghost(frame, dx):
    out = frame.copy()
    out[..., 0] += 0.10 * np.roll(frame[..., 0], dx, axis=1)
    out[..., 1] += 0.08 * np.roll(frame[..., 1], dx + 2, axis=1)
    out[..., 2] += 0.06 * np.roll(frame[..., 2], dx + 4, axis=1)
    return out


def chroma(frame, shift):
    out = frame.copy()
    out[..., 0] = np.roll(frame[..., 0], shift, axis=1)
    out[..., 2] = np.roll(frame[..., 2], -shift, axis=1)
    return out


def snow(t, strength, rng):
    """Крупный «снег»: низкое разрешение, апскейл блоками, смаз по строке."""
    h, w = H // 6, W // 6
    n = rng.normal(0, 1, (h, w)).astype(np.float32)
    n = np.clip(n, -2.2, 2.2)
    big = np.repeat(np.repeat(n, 6, axis=0), 6, axis=1)
    sm = big * 0.5
    for k in (5, 11, 19, 31):
        sm += 0.22 * np.roll(big, k, axis=1)
        sm += 0.12 * np.roll(big, -k, axis=1)
    return sm[..., None] * strength


def dropouts(t, rng):
    """Белые штрихи-выпадения сигнала."""
    layer = np.zeros((H, W, 1), dtype=np.float32)
    for _ in range(rng.integers(2, 6)):
        y = int(rng.integers(0, H))
        x0 = int(rng.integers(0, W - 200))
        ln = int(rng.integers(40, 260))
        val = float(rng.uniform(60, 140))
        layer[y:y + 2, x0:x0 + ln] += val
    return layer


def power_on(frame, t):
    if t >= 0.38:
        return frame
    e = float(smoothstep(t / 0.32)) ** 0.75
    h = max(3, int(H * e))
    img = Image.fromarray(np.clip(frame, 0, 255).astype(np.uint8)).resize((W, h), Image.BILINEAR)
    canvas = Image.new("RGB", (W, H), (0, 0, 0))
    canvas.paste(img, (0, (H - h) // 2))
    out = np.asarray(canvas, dtype=np.float32)
    if e < 0.65:
        y = H // 2
        glow = int(100 * (1 - e))
        out[max(0, y - 3):y + 4] = np.clip(out[max(0, y - 3):y + 4] + 150, 0, 255)
        out[max(0, y - glow):y + glow] *= 1.0 + 0.35 * (1 - e)
    if t < 0.09:
        out = out * 0.12 + 250 * (1 - t / 0.09) * 0.88
    return out


def main():
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    cmd = [
        ffmpeg, "-y", "-v", "error",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS),
        "-i", "-",
        "-an", "-c:v", "libx264", "-preset", "slow", "-crf", "22",
        "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(OUT),
    ]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)

    local = np.random.default_rng(5)
    prev = None
    for i in range(N):
        t = i / FPS

        frame = distort(BASE, t)
        frame = vertical_roll(frame, t)
        frame = ghost(frame, 20 if SOFT else 26)
        frame = chroma(frame, 6)

        # цвет уходит: слабый сигнал почти чёрно-белый
        desat = 0.35 + 0.25 * (1 + np.sin(t * 2.1)) / 2
        lum = frame.mean(axis=2, keepdims=True)
        frame = lum + (frame - lum) * desat

        # гребёнка и строки
        frame *= 1.0 + 0.10 * np.exp(-(((np.arange(H)[:, None] - (t * 420) % H) / 170) ** 2))[..., None]
        frame *= LINES

        # «снег»: сильнее в тёмных местах и в провалах сигнала
        dark = 1.0 - np.clip(frame.mean(axis=2, keepdims=True) / 255.0, 0, 1)
        amount = (12.0 + 12.0 * dark) if SOFT else (26.0 + 22.0 * dark)
        for start, _, strength in DROPS:
            if start <= t <= start + 0.09:
                amount = amount * (1 + strength * 3)
        frame = frame + snow(t, 1.0, local) * amount

        for start, _, strength in DROPS:
            if start <= t <= start + 0.09:
                wipe = snow(t, 1.0, local) * 90 + 40
                frame = frame * (1 - strength) + wipe * strength

        frame = frame + dropouts(t, local)

        # дрожание и чересстрочность
        flick = 1.0 + 0.045 * np.sin(2 * np.pi * 6.1 * t) + local.normal(0, 0.02)
        frame *= flick
        if i % 2:
            frame = np.roll(frame, 1, axis=0)

        # цветокор: холодный, приподнятые чёрные
        frame = (frame - 128.0) * 0.95 + 128.0 + 10.0
        frame *= np.array([0.94, 1.0, 1.07], dtype=np.float32)

        if prev is not None:
            frame = frame * 0.9 + prev * 0.1
        prev = frame

        frame = power_on(frame, t)
        frame *= CORNER
        frame *= vig

        np.clip(frame, 0, 255, out=frame)
        img = Image.fromarray(frame.astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.5))
        arr = np.asarray(img, dtype=np.float32)
        arr += local.normal(0, 2.5, (H, W, 1)).astype(np.float32)
        np.clip(arr, 0, 255, out=arr)

        proc.stdin.write(arr.astype(np.uint8).tobytes())
        if i % 25 == 0:
            print(f"frame {i}/{N}")

    proc.stdin.close()
    proc.wait()
    print("done:", OUT, f"{OUT.stat().st_size/1024/1024:.1f} MB")


if __name__ == "__main__":
    main()
