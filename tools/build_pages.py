"""Make the stand-alone web version (GitHub Pages) from the web export in ../webbuild.

Adds what a page outside Claude needs:
  * PeerJS (tools/vendor/peerjs.min.js) so friends can join by room code (tools/mwnet.js, kind "peer")
  * a web app manifest + service worker + icons, so phones can "Add to Home Screen" and open it
    full screen like an app (iPhone: Safari > Share > Add to Home Screen)
Usage: python3 tools/build_pages.py ../webbuild <out_dir>      (e.g. ../madwater/docs)
"""
import json
import os
import re
import shutil
import sys

here = os.path.dirname(os.path.abspath(__file__))
src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
for name in os.listdir(src):
    shutil.copy2(os.path.join(src, name), os.path.join(out, name))
shutil.copy2(os.path.join(here, "vendor", "peerjs.min.js"), os.path.join(out, "peerjs.min.js"))
for name in ["icon-512.png", "icon-192.png", "apple-touch-icon.png"]:
    shutil.copy2(os.path.join(here, "pages", name), os.path.join(out, name))

manifest = {
    "name": "瘋狂水世界",
    "short_name": "瘋狂水世界",
    "description": "在海上漂流求生，跟朋友一起蓋木筏。",
    "start_url": "./index.html",
    "scope": "./",
    "display": "fullscreen",
    "orientation": "landscape",
    "background_color": "#0b2a33",
    "theme_color": "#0b2a33",
    "lang": "zh-Hant",
    "icons": [
        {"src": "icon-192.png", "sizes": "192x192", "type": "image/png"},
        {"src": "icon-512.png", "sizes": "512x512", "type": "image/png"},
        {"src": "icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable"},
    ],
}
with open(os.path.join(out, "manifest.webmanifest"), "w", encoding="utf-8") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=1)

# A pass-through service worker: enough for phones to offer "install"; the game itself is
# always fetched fresh (cache-busted by tools/web_post.py), so updates show up on reload.
with open(os.path.join(out, "sw.js"), "w", encoding="utf-8") as f:
    f.write("self.addEventListener('install', () => self.skipWaiting());\n"
            "self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));\n"
            "self.addEventListener('fetch', () => {});\n")

p = os.path.join(out, "index.html")
html = open(p, encoding="utf-8").read()
html = re.sub(r'<meta name="viewport"[^>]*>',
              '<meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no, viewport-fit=cover">', html)
head_extra = """
		<link rel="manifest" href="manifest.webmanifest">
		<meta name="theme-color" content="#0b2a33">
		<meta name="mobile-web-app-capable" content="yes">
		<meta name="apple-mobile-web-app-capable" content="yes">
		<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
		<meta name="apple-mobile-web-app-title" content="瘋狂水世界">
		<link rel="apple-touch-icon" href="apple-touch-icon.png">
		<link rel="icon" href="icon-192.png">"""
html = html.replace("<title>瘋狂水世界</title>", "<title>瘋狂水世界</title>" + head_extra, 1)
marker = "<script>\n// window.MWNet"
assert marker in html, "mwnet bridge missing: run tools/build_web.sh first"
html = html.replace(marker, '<script src="peerjs.min.js"></script>\n' + marker, 1)
html = html.replace("</body>", "<script>if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(() => {});</script>\n</body>", 1)
open(p, "w", encoding="utf-8").write(html)
open(os.path.join(out, ".nojekyll"), "w").close()
print("pages ->", out, sorted(os.listdir(out)))
