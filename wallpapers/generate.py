# Generates wallpapers/catppuccin-floaty.jpg (3840x2160). Run from the repo root:
#     pip install pillow numpy && python3 wallpapers/generate.py
import numpy as np
from PIL import Image, ImageFilter

W, H = 3840, 2160
w, h = W // 4, H // 4
yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
xx /= w; yy /= h

def hexrgb(s): return np.array([int(s[i:i+2], 16) for i in (0, 2, 4)], np.float32) / 255
base = hexrgb("1e1e2e"); mantle = hexrgb("11111b")
mauve = hexrgb("cba6f7"); blue = hexrgb("89b4fa"); teal = hexrgb("94e2d5")
pink = hexrgb("f5c2e7"); lav = hexrgb("b4befe")

img = np.ones((h, w, 3), np.float32) * base
img = img * (1 - 0.35 * yy[..., None]) + mantle * (0.35 * yy[..., None])

def blend(a, color):
    global img
    img = img * (1 - a[..., None]) + color * a[..., None]

def glow(cx, cy, rx, ry, color, strength):
    d = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
    blend(strength * np.exp(-d), color)

glow(0.18, 0.22, 0.30, 0.38, mauve, 0.30)
glow(0.82, 0.30, 0.28, 0.36, blue,  0.26)
glow(0.62, 0.92, 0.36, 0.30, teal,  0.16)
glow(0.40, 0.55, 0.22, 0.26, lav,   0.08)
glow(0.95, 0.85, 0.18, 0.22, pink,  0.10)

fade = np.clip(np.sin(np.pi * np.clip(xx, 0, 1)), 0, 1) ** 1.5
def ribbon(y0, amp, freq, phase, width, color, strength):
    center = y0 + amp * np.sin(2 * np.pi * (freq * xx + phase)) + 0.4 * amp * np.sin(2 * np.pi * (2.3 * freq * xx + 1.7 * phase))
    d = (yy - center) / width
    blend(strength * np.exp(-d * d) * fade, color)

ribbon(0.62, 0.06, 0.9, 0.10, 0.010, lav,   0.22)
ribbon(0.66, 0.07, 0.8, 0.35, 0.018, blue,  0.14)
ribbon(0.70, 0.05, 1.1, 0.60, 0.006, mauve, 0.20)
ribbon(0.58, 0.04, 1.3, 0.85, 0.004, teal,  0.16)

d = ((xx - 0.5) / 0.75) ** 2 + ((yy - 0.5) / 0.75) ** 2
img *= (1 - 0.28 * np.clip(d, 0, 1))[..., None]

small = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))
big = small.resize((W, H), Image.BICUBIC).filter(ImageFilter.GaussianBlur(2))
arr = np.asarray(big).astype(np.float32) + np.random.default_rng(7).normal(0, 1.6, (H, W, 3))
Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save("wallpapers/catppuccin-floaty.jpg", quality=92, subsampling=0)
# preview: big.resize((1280, 720)).save("preview.png")
