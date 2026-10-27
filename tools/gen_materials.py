"""Generate the tileable material textures into textures/ (run: python3 tools/gen_materials.py).

Each family is a light, mostly grey detail map (the game tints it with the piece's own colour,
so one texture serves every shade of wood) plus a tangent-space normal map (<name>_n.png):

  bark     raft logs, posts, palm trunks: long fibres along V, cracks, a few knots
  planks   boards, chests, boats: fine grain along U with growth lines and the odd knot
  thatch   roofs, palm-leaf parts: overlapping straw strands
  rope     lashings and lines: twisted strands
  metal    still, grill, tools: brushed scratches, rust blooms
  cloth    sails, tarps: weave with stains
  soil     fields: clumps and pebbles
  stone    rocks, island boulders, seabed: mottled with cracks
  sand     beaches, sea floor: fine grain with ripples
  plastic  barrels, bottles, cups: soft scuffs
"""
import os
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "textures")
os.makedirs(OUT, exist_ok=True)


def lattice(n, cx, cy, seed):
    """Tileable value noise, cx × cy cells across an n × n image, smooth in [0, 1]."""
    r = np.random.default_rng(seed).random((cy, cx))
    xs = np.linspace(0, cx, n, endpoint=False)
    ys = np.linspace(0, cy, n, endpoint=False)
    x0 = np.floor(xs).astype(int); x1 = (x0 + 1) % cx; fx = xs - x0
    y0 = np.floor(ys).astype(int); y1 = (y0 + 1) % cy; fy = ys - y0
    fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy)
    a = r[np.ix_(y0, x0)] * (1 - fx) + r[np.ix_(y0, x1)] * fx
    b = r[np.ix_(y1, x0)] * (1 - fx) + r[np.ix_(y1, x1)] * fx
    return a * (1 - fy)[:, None] + b * fy[:, None]


def fbm(n, cx, cy, seed, oct=5):
    out = np.zeros((n, n)); amp = 1.0; tot = 0.0
    for k in range(oct):
        out += lattice(n, cx << k, cy << k, seed + k * 17) * amp
        tot += amp; amp *= 0.5
    return out / tot


def voronoi(n, cells, seed):
    """Tileable F1 / F2 distances for `cells` × `cells` jittered points."""
    rng = np.random.default_rng(seed)
    pts = rng.random((cells, cells, 2))
    ys, xs = np.mgrid[0:n, 0:n] / n * cells
    gx = np.floor(xs).astype(int); gy = np.floor(ys).astype(int)
    f1 = np.full((n, n), 9.0); f2 = np.full((n, n), 9.0); cid = np.zeros((n, n), int)
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            cxx = (gx + ox) % cells; cyy = (gy + oy) % cells
            px = gx + ox + pts[cyy, cxx, 0]; py = gy + oy + pts[cyy, cxx, 1]
            d = np.sqrt((xs - px) ** 2 + (ys - py) ** 2)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            cid = np.where(closer, cyy * cells + cxx, cid)
            f1 = np.where(closer, d, f1)
    return f1, f2, cid


def save(name, albedo, height, strength):
    a = np.clip(albedo, 0, 1)
    if a.ndim == 2:
        a = np.stack([a, a, a], -1)
    Image.fromarray((a * 255).astype(np.uint8)).save(os.path.join(OUT, name + ".png"))
    # wrap-around gradient keeps the normal map tileable
    gx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 0.5
    gy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 0.5
    nx = -gx * strength; ny = gy * strength; nz = np.ones_like(height)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    rgb = np.stack([nx / l, ny / l, nz / l], -1) * 0.5 + 0.5
    Image.fromarray((rgb * 255).astype(np.uint8)).save(os.path.join(OUT, name + "_n.png"))


def warm(g, tint=(1.0, 0.97, 0.92)):
    return np.stack([g * tint[0], g * tint[1], g * tint[2]], -1)


N = 512
ys, xs = np.mgrid[0:N, 0:N] / N

# ---- bark: fibres run along V (down the image), cracks between them
fib = fbm(N, 24, 2, 1, 4)                     # stretched: many columns, few rows
crack = np.abs(np.sin((xs * 22 + fbm(N, 4, 4, 2) * 2.5) * np.pi))
crack = np.clip(1 - crack * 6, 0, 1)
knot_f1, _, _ = voronoi(N, 3, 3)
knots = np.clip(1 - knot_f1 * 5.5, 0, 1) ** 2
g = 0.72 + 0.22 * fib - 0.35 * crack - 0.25 * knots + 0.08 * fbm(N, 8, 8, 4)
save("bark", warm(g), fib * 0.6 - crack * 0.9 - knots * 0.5, 6.0)

# ---- planks: grain along U, growth rings, knots
wav = fbm(N, 2, 6, 11, 4)
grain = np.sin((ys * 46 + wav * 5.0) * np.pi * 2) * 0.5 + 0.5
fine = fbm(N, 4, 64, 12, 3)
kf1, _, kc = voronoi(N, 5, 13)
keep = np.random.default_rng(14).random(25)[kc] < 0.22      # only a few cells grow a knot
kn = np.clip(1 - kf1 * 9, 0, 1) * keep
ring = np.sin(kf1 * 70) * 0.5 + 0.5
g = 0.76 + 0.14 * grain + 0.14 * (fine - 0.5) - 0.25 * kn * ring - 0.15 * kn
save("planks", warm(g), 0.3 * grain + 0.4 * fine - 0.6 * kn, 3.5)

# ---- thatch: overlapping straw strands in rows
rows = 10
row_v = (ys * rows) % 1.0
strand = fbm(N, 96, 3, 21, 3)
tip = np.clip(row_v * 1.3, 0, 1)                # each row darkens toward where the next overlaps
g = 0.62 + 0.38 * strand * (0.55 + 0.45 * tip) - 0.22 * (row_v > 0.9)
save("thatch", warm(g, (1.0, 0.95, 0.8)), strand * tip - 0.6 * (row_v > 0.9), 5.0)

# ---- rope: twisted strands (diagonal), fuzz
tw = np.sin((xs * 3 + ys * 12) * np.pi * 2) * 0.5 + 0.5
fuzz = fbm(N, 32, 32, 31, 3)
g = 0.68 + 0.26 * tw + 0.12 * (fuzz - 0.5)
save("rope", warm(g, (1.0, 0.96, 0.88)), tw * 0.8 + fuzz * 0.3, 5.0)

# ---- metal: brushed lines, scratches, rust blooms
brush = fbm(N, 2, 128, 41, 2)
scr_f1, scr_f2, _ = voronoi(N, 14, 42)
scratch = np.clip(1 - (scr_f2 - scr_f1) * 30, 0, 1) * 0.6
rust = np.clip((fbm(N, 6, 6, 43) - 0.64) * 4.0, 0, 1) * 0.8
base = 0.78 + 0.1 * brush + 0.12 * scratch
alb = np.stack([base, base, base], -1)
alb = alb * (1 - rust[..., None]) + np.array([0.62, 0.34, 0.18]) * rust[..., None]
save("metal", alb, brush * 0.2 + rust * 0.4 - scratch * 0.3, 2.5)

# ---- cloth: weave + stains
wx = np.sin(xs * np.pi * 2 * 96) * 0.5 + 0.5
wy = np.sin(ys * np.pi * 2 * 96) * 0.5 + 0.5
weave = np.where(((np.floor(xs * 96) + np.floor(ys * 96)) % 2) == 0, wx, wy)
stain = np.clip((fbm(N, 4, 4, 51) - 0.55) * 3, 0, 1)
g = 0.86 + 0.1 * weave - 0.18 * stain + 0.05 * fbm(N, 16, 16, 52)
save("cloth", warm(g, (1.0, 0.98, 0.94)), weave * 0.6 - stain * 0.2, 2.0)

# ---- soil: clumps + pebbles
f1, f2, cid = voronoi(N, 18, 61)
clump = np.clip((f2 - f1) * 2.5, 0, 1) ** 0.5
peb_f1, _, pc = voronoi(N, 40, 62)
peb = np.clip(1 - peb_f1 * 9, 0, 1) * (np.random.default_rng(64).random(1600)[pc] < 0.35)
crumbs = fbm(N, 16, 16, 63, 5)
g = 0.62 + 0.14 * clump + 0.25 * peb + 0.3 * (crumbs - 0.5)
save("soil", warm(g, (1.0, 0.94, 0.88)), clump * 0.5 + peb * 0.8 + crumbs * 0.6, 6.0)

# ---- stone: mottled + cracks
f1, f2, cid = voronoi(N, 5, 71)
crack_mask = np.clip((fbm(N, 4, 4, 74) - 0.45) * 5, 0, 1)    # cracks come and go
cr = np.clip(1 - (f2 - f1) * 24, 0, 1) * crack_mask
mott = fbm(N, 6, 6, 72, 6)
speck = (np.random.default_rng(75).random((N, N)) > 0.985) * 0.25
tone = np.random.default_rng(73).random(25)[cid]
g = 0.6 + 0.34 * mott + 0.06 * tone - 0.3 * cr - speck
save("stone", warm(g, (0.98, 0.98, 1.0)), mott * 1.2 - cr + tone * 0.1, 5.0)

# ---- sand: fine grain + ripples
rip = np.sin((ys * 18 + fbm(N, 3, 3, 81) * 3) * np.pi * 2) * 0.5 + 0.5
gr = np.random.default_rng(82).random((N, N))
g = 0.84 + 0.08 * rip + 0.1 * (gr - 0.5) + 0.06 * (fbm(N, 8, 8, 83) - 0.5)
save("sand", warm(g, (1.0, 0.98, 0.93)), rip * 0.6 + gr * 0.15, 3.0)

# ---- grass: short blades, clumps of darker and lighter growth
blades = fbm(N, 128, 32, 101, 3)
clumps = fbm(N, 6, 6, 102, 4)
g = 0.6 + 0.3 * blades * (0.6 + 0.4 * clumps) + 0.1 * (clumps - 0.5)
save("grass", warm(g, (0.95, 1.0, 0.9)), blades * 0.8 + clumps * 0.4, 4.0)

# ---- plastic: soft scuffs
sc = fbm(N, 10, 10, 91, 4)
g = 0.9 + 0.08 * (sc - 0.5) - 0.12 * np.clip((fbm(N, 5, 5, 92) - 0.62) * 4, 0, 1)
save("plastic", warm(g, (1, 1, 1)), sc * 0.3, 1.5)

print(sorted(os.listdir(OUT)))
