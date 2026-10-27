"""Build fonts/ui.otf: Noto Sans CJK TC Medium cut down to the characters the game's scripts use.

Web builds can't reach the phone's own fonts, so the game ships this subset. Re-run after adding new
Chinese text:  python3 tools/make_font.py
"""
import glob
import os
import string
from fontTools import subset
from fontTools.ttLib import TTCollection

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = "/usr/share/fonts/opentype/noto/NotoSansCJK-Medium.ttc"

chars = set(string.printable) | set("　，。、；：？！「」（）《》…—·×→←↑↓↖↗↘↙／％＋－～・°")
for path in glob.glob(os.path.join(ROOT, "**", "*.gd"), recursive=True):
    chars |= set(open(path, encoding="utf-8").read())
chars = {c for c in chars if c.isprintable() or c == " "}

font = TTCollection(SRC).fonts[3]  # Noto Sans CJK TC Medium
opts = subset.Options()
opts.layout_features = ["*"]
opts.name_IDs = ["*"]
opts.notdef_outline = True
sub = subset.Subsetter(opts)
sub.populate(text="".join(sorted(chars)))
sub.subset(font)
out = os.path.join(ROOT, "fonts", "ui.otf")
font.save(out)
print("%d characters -> %s (%d KB)" % (len(chars), out, os.path.getsize(out) // 1024))
