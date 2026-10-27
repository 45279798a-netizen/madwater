"""App icon for the home-screen version: a little raft with a sail on a sunset sea.
Usage: python3 tools/make_icon.py <out_dir>  -> icon-512.png, icon-192.png, apple-touch-icon.png"""
import os, sys, math
from PIL import Image, ImageDraw, ImageFilter

out = sys.argv[1]
S = 1024
img = Image.new("RGB", (S, S))
d = ImageDraw.Draw(img)
for y in range(S):                      # sky -> sea gradient
    t = y / S
    if t < 0.58:
        k = t / 0.58
        c = (int(255 - 60 * k), int(176 - 40 * k), int(92 + 60 * k))
    else:
        k = (t - 0.58) / 0.42
        c = (int(20 + 10 * (1 - k)), int(110 - 60 * k), int(140 - 50 * k))
    d.line([(0, y), (S, y)], fill=c)
sun = Image.new("L", (S, S), 0)
ImageDraw.Draw(sun).ellipse((560, 250, 840, 530), fill=255)
img.paste((255, 236, 170), (0, 0), sun.filter(ImageFilter.GaussianBlur(6)))
for i in range(7):                       # waves
    y = 640 + i * 52
    pts = [(x, y + 10 * math.sin(x / 55.0 + i)) for x in range(0, S + 20, 20)]
    d.line(pts, fill=(140, 210, 220) if i % 2 == 0 else (60, 150, 175), width=8)
# raft planks
for i in range(6):
    x0 = 250 + i * 88
    d.rounded_rectangle((x0, 640, x0 + 80, 720), radius=26, fill=(176, 122, 74), outline=(110, 72, 40), width=6)
d.rectangle((240, 668, 790, 684), fill=(222, 200, 150))
# mast and sail
d.rectangle((505, 300, 527, 650), fill=(110, 72, 40))
d.polygon([(527, 320), (527, 600), (760, 600)], fill=(244, 236, 214), outline=(200, 186, 160))
d.polygon([(505, 360), (505, 600), (330, 600)], fill=(255, 159, 28))
# shark fin
d.polygon([(130, 760), (190, 650), (235, 760)], fill=(52, 70, 82))
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, S, S), radius=200, fill=255)
img.putalpha(mask)
for name, size in [("icon-512.png", 512), ("icon-192.png", 192)]:
    img.resize((size, size), Image.LANCZOS).save(os.path.join(out, name))
img.convert("RGB").resize((180, 180), Image.LANCZOS).save(os.path.join(out, "apple-touch-icon.png"))
print("icons ->", out)
