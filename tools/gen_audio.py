"""Synthesise the game's sound effects into res://audio/*.wav (44.1 kHz mono, 16-bit).

Everything is procedural: filtered noise for water and wind, damped resonators for wood and
hits, short tone sweeps for UI. Re-run with `python3 tools/gen_audio.py` from the project root.
"""
import os
import numpy as np
from scipy.signal import butter, sosfilt
from scipy.io import wavfile

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")
rng = np.random.default_rng(7)


def t_axis(sec):
    return np.arange(int(SR * sec)) / SR


def noise(sec):
    return rng.standard_normal(int(SR * sec))


def band(x, lo=None, hi=None, order=2):
    if lo and hi:
        sos = butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    elif lo:
        sos = butter(order, lo, btype="high", fs=SR, output="sos")
    else:
        sos = butter(order, hi, btype="low", fs=SR, output="sos")
    return sosfilt(sos, x)


def env(sec, attack, decay_k):
    t = t_axis(sec)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-t * decay_k)


def loopable(x, fade_sec=1.0):
    """Crossfade the tail into the head so the clip loops without a click."""
    n = int(SR * fade_sec)
    head, body, tail = x[:n], x[n:-n], x[-n:]
    w = np.linspace(0, 1, n)
    return np.concatenate([tail * (1 - w) + head * w, body])


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def save(name, x, peak=0.9):
    os.makedirs(OUT, exist_ok=True)
    data = (norm(x, peak) * 32767).astype(np.int16)
    wavfile.write(os.path.join(OUT, name + ".wav"), SR, data)


def ocean_loop():
    sec = 12.0
    t = t_axis(sec)
    surf = band(noise(sec), hi=500)
    swell = 0.55 + 0.45 * np.sin(2 * np.pi * t / 6.0) ** 2
    hiss = band(noise(sec), lo=1200, hi=5000) * (0.15 + 0.25 * np.sin(2 * np.pi * t / 6.0 + 1.2) ** 8)
    lap = np.zeros_like(t)
    for start in np.arange(0.4, sec - 1, 1.9):
        k = int(start * SR)
        e = env(0.8, 0.05, 6) * band(noise(0.8), lo=300, hi=2500)
        lap[k:k + len(e)] += e * 0.35
    return loopable(surf * swell + hiss + lap)


def wind_loop():
    sec = 10.0
    t = t_axis(sec)
    gust = 0.5 + 0.5 * np.sin(2 * np.pi * t / 5.0) * np.sin(2 * np.pi * t / 3.3 + 0.7)
    w = band(noise(sec), lo=300, hi=1400) * (0.4 + 0.6 * gust)
    whistle = band(noise(sec), lo=700, hi=760, order=4) * 3.0 * gust
    return loopable(w + whistle)


def splash(sec=0.7, low=500, high=4000, k=7.0):
    e = env(sec, 0.004, k)
    body = band(noise(sec), lo=low, hi=high) * e
    t = t_axis(sec)
    bubbles = np.zeros_like(t)
    for i in range(6):
        st = rng.uniform(0.05, sec * 0.6)
        f = rng.uniform(500, 1400)
        tt = np.clip(t - st, 0, None)
        bubbles += np.sin(2 * np.pi * (f + 900 * tt) * tt) * np.exp(-tt * 40) * (t > st)
    return body + bubbles * 0.25


def whoosh():
    sec = 0.4
    t = t_axis(sec)
    x = noise(sec)
    out = np.zeros_like(x)
    for i, lo in enumerate(np.linspace(500, 2600, 8)):
        seg = slice(int(i * len(x) / 8), int((i + 1) * len(x) / 8))
        out[seg] = band(x, lo=lo, hi=lo * 1.8)[seg]
    return out * np.sin(np.pi * t / sec) ** 2


def pluck(f0=660, sec=0.18):
    t = t_axis(sec)
    f = f0 * (1 + 0.4 * np.exp(-t * 40))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(sec, 0.002, 22) + 0.3 * np.sin(4 * np.pi * np.cumsum(f) / SR) * env(sec, 0.002, 35)


def knock(f=180, sec=0.25, k=26):
    t = t_axis(sec)
    tone = np.sin(2 * np.pi * f * t) * 0.8 + np.sin(2 * np.pi * f * 2.3 * t) * 0.4
    click = band(noise(sec), lo=1500, hi=6000) * env(sec, 0.0005, 120)
    return tone * env(sec, 0.002, k) + click * 0.6


def wood_crunch():
    sec = 0.55
    x = np.zeros(int(SR * sec))
    for i in range(14):
        st = int(rng.uniform(0, 0.25) * SR)
        e = band(noise(0.08), lo=900, hi=5000) * env(0.08, 0.001, 70) * rng.uniform(0.4, 1)
        x[st:st + len(e)] += e
    thud = knock(f=90, sec=sec, k=10)
    return x + thud * 0.9 + splash(sec, 300, 1800, 9) * 0.35


def craft():
    out = np.zeros(int(SR * 0.6))
    for st in (0.0, 0.28):
        k = knock(f=150, sec=0.3, k=20)
        s = int(st * SR)
        out[s:s + len(k)] += k
    return out


def drink():
    out = np.zeros(int(SR * 0.9))
    for i, st in enumerate((0.05, 0.33, 0.6)):
        t = t_axis(0.22)
        f = 260 - 70 * t / 0.22
        g = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / 0.22) ** 2
        g = band(g + 0.05 * noise(0.22), hi=900)
        s = int(st * SR)
        out[s:s + len(g)] += g
    return out


def eat():
    out = np.zeros(int(SR * 0.6))
    for st in (0.0, 0.2, 0.38):
        e = band(noise(0.1), lo=1200, hi=6000) * env(0.1, 0.002, 45)
        s = int(st * SR)
        out[s:s + len(e)] += e
    return out


def reel():
    out = np.zeros(int(SR * 0.6))
    for i in range(14):
        s = int(i * 0.04 * SR)
        c = band(noise(0.015), lo=2500, hi=7000) * env(0.015, 0.0005, 300)
        out[s:s + len(c)] += c
    return out


def catch():
    t = t_axis(0.6)
    chime = (np.sin(2 * np.pi * 880 * t) + 0.6 * np.sin(2 * np.pi * 1320 * t)) * env(0.6, 0.005, 6)
    s = splash(0.6, 400, 3000, 9)
    return chime * 0.5 + s


def shark_alert():
    out = np.zeros(int(SR * 1.3))
    for st, f in ((0.0, 82.4), (0.55, 87.3)):
        t = t_axis(0.45)
        tone = np.sign(np.sin(2 * np.pi * f * t)) * 0.4 + np.sin(2 * np.pi * f * t)
        tone = band(tone, hi=600) * env(0.45, 0.01, 5)
        s = int(st * SR)
        out[s:s + len(tone)] += tone
    return out


def fail():
    t = t_axis(1.2)
    f = 330 * np.exp(-t * 0.9)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(1.2, 0.01, 2.5)


def fire_loop():
    sec = 4.0
    base = band(noise(sec), lo=200, hi=900) * 0.25
    pops = np.zeros(int(SR * sec))
    for i in range(40):
        s = int(rng.uniform(0, sec - 0.05) * SR)
        p = band(noise(0.03), lo=2000, hi=8000) * env(0.03, 0.0005, 150) * rng.uniform(0.3, 1)
        pops[s:s + len(p)] += p
    return loopable(base + pops, 0.3)


def rain_loop():
    sec = 4.0
    hiss = band(noise(sec), lo=1800, hi=9000) * 0.35
    patter = np.zeros(int(SR * sec))
    for i in range(900):
        s = int(rng.uniform(0, sec - 0.02) * SR)
        d = band(noise(0.012), lo=2500, hi=10000) * env(0.012, 0.0003, 400) * rng.uniform(0.2, 1)
        patter[s:s + len(d)] += d
    rumble = band(noise(sec), lo=60, hi=300) * 0.25
    return loopable(hiss + patter * 0.6 + rumble, 0.5)


def thunder():
    sec = 3.5
    crack = band(noise(0.25), lo=600, hi=5000) * env(0.25, 0.002, 18)
    roll = band(noise(sec), lo=30, hi=220) * env(sec, 0.08, 1.4)
    roll *= 1.0 + 0.6 * np.sin(t_axis(sec) * 2 * np.pi * 1.7)
    out = roll * 1.4
    out[:len(crack)] += crack * 0.8
    return out


if __name__ == "__main__":
    save("rain_loop", rain_loop(), 0.6)
    save("thunder", thunder(), 0.95)
    save("ocean_loop", ocean_loop(), 0.7)
    save("wind_loop", wind_loop(), 0.6)
    save("fire_loop", fire_loop(), 0.5)
    save("splash", splash())
    save("splash_small", splash(0.4, 700, 4500, 12), 0.6)
    save("whoosh", whoosh(), 0.7)
    save("pickup", pluck())
    save("bite", wood_crunch())
    save("craft", craft())
    save("build", knock(f=120, sec=0.35, k=14))
    save("drink", drink(), 0.8)
    save("eat", eat(), 0.7)
    save("reel", reel(), 0.6)
    save("catch", catch())
    save("shark_alert", shark_alert())
    save("fail", fail(), 0.7)
    print("wrote", sorted(os.listdir(OUT)))
