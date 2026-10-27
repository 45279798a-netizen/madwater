"""Repaint the scanned hawksbill's textures so it looks alive and friendly instead of like a
pale museum specimen: the grey albedo is gradient-mapped to warm amber / olive tones and
softened, and the dull grey eyes become dark glossy eyes with a brown iris.
Usage: python3 tools/paint_turtle.py <turtle_0.png albedo> <turtle_3.png eye>  -> models3d/"""
import os, sys
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
alb = Image.open(sys.argv[1]).convert("RGB")
a = np.asarray(alb.filter(ImageFilter.MedianFilter(5))).astype(float) / 255.0
lum = a @ np.array([0.3, 0.55, 0.15])
lo, hi = np.percentile(lum[lum > 0.02], [2, 98])
t = np.clip((lum - lo) / (hi - lo), 0, 1)
# the scan's own reddish-brown patches (carapace) stay a little redder
warm = np.clip((a[..., 0] - a[..., 2]) * 4.0, 0, 1)
stops = np.array([[0.11, 0.09, 0.05], [0.25, 0.21, 0.11], [0.42, 0.34, 0.17], [0.62, 0.52, 0.29], [0.86, 0.8, 0.6]])
x = t * (len(stops) - 1)
i = np.clip(np.floor(x).astype(int), 0, len(stops) - 2)
f = (x - i)[..., None]
col = stops[i] * (1 - f) + stops[i + 1] * f
col = col * (1 - 0.25 * warm[..., None]) + np.array([0.55, 0.3, 0.13]) * 0.25 * warm[..., None]
col = np.where((lum < 0.015)[..., None], 0.0, col)
img = Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.SMOOTH_MORE)
img.save(os.path.join(ROOT, "models3d", "turtle_paint.png"))
# eyes: black pupil, warm brown iris, no grey
e = np.asarray(Image.open(sys.argv[2]).convert("L")).astype(float) / 255.0
iris = np.array([0.35, 0.2, 0.08])
ec = iris[None, None, :] * np.clip(e * 2.2, 0, 1)[..., None] * 0.8 + 0.02
Image.fromarray((np.clip(ec, 0, 1) * 255).astype(np.uint8)).save(os.path.join(ROOT, "models3d", "turtle_eye.png"))
print("ok")
