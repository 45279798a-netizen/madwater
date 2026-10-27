"""Turn the exported index.html into an artifact page (body content only; the host adds the skeleton).
Usage: python3 tools/web_artifact.py ../webbuild ../webpub/madwater.html"""
import re
import sys

src, dst = sys.argv[1], sys.argv[2]
html = open(src + "/index.html", encoding="utf-8").read()
head = re.search(r"<head>(.*?)</head>", html, re.S).group(1)
body = re.search(r"<body>(.*?)</body>", html, re.S).group(1)
head = re.sub(r'<meta charset="utf-8">\s*', "", head)
head = re.sub(r'<meta name="viewport"[^>]*>\s*', "", head)
head = head.replace("<title>瘋狂水世界</title>", "")
extra = """<style>
:root { --sea: #0b2a33; --ink: #f4ecd6; color-scheme: dark; }
html, body { height: 100%; background: var(--sea); color: var(--ink); }
#canvas { position: fixed; inset: 0; }
</style>
"""
open(dst, "w", encoding="utf-8").write("<title>瘋狂水世界</title>\n" + head.strip() + "\n" + extra + body.strip() + "\n")
print("wrote", dst)
