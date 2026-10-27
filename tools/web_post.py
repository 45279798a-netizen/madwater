"""Post-process the Godot web export so it can be hosted where single files must stay under 15 MB.

index.wasm (≈40 MB) is gzipped to engine.wasm (≈10 MB) and index.pck is renamed game-data.wasm
(artifact hosting only serves certain extensions). A small script in index.html intercepts the
engine's fetches, downloads engine.wasm with a progress readout and unzips it in the browser
(DecompressionStream). Usage:
    python3 tools/web_post.py ../webbuild
"""
import gzip
import json
import os
import re
import sys
import time

out = sys.argv[1]
wasm = os.path.join(out, "index.wasm")
if os.path.exists(wasm):
    with open(wasm, "rb") as f, gzip.open(os.path.join(out, "engine.wasm"), "wb", compresslevel=9) as g:
        g.write(f.read())
    os.remove(wasm)
pck = os.path.join(out, "index.pck")
if os.path.exists(pck):
    os.replace(pck, os.path.join(out, "game-data.wasm"))
html_path = os.path.join(out, "index.html")
html = open(html_path, encoding="utf-8").read()

SHIM = r"""<script>
// Fetch index.wasm from the gzipped index.wasm.bin and unpack it here (hosting caps files at 15 MB).
(function () {
	const realFetch = window.fetch.bind(window);
	const note = document.createElement('div');
	note.id = 'mw-load';
	note.textContent = '載入中…';
	document.addEventListener('DOMContentLoaded', () => document.body.appendChild(note));
	window.fetch = async function (input, init) {
		const url = typeof input === 'string' ? input : input.url;
		if (/index\.pck(\?|$)/.test(url)) {
			return realFetch(url.replace(/index\.pck(\?.*)?$/, 'game-data.wasm?v=__BUILD__'), init);
		}
		if (!/index\.wasm(\?|$)/.test(url)) {
			return realFetch(input, init);
		}
		const r = await realFetch(url.replace(/index\.wasm(\?.*)?$/, 'engine.wasm?v=__BUILD__'), init);
		if (!r.ok) {
			return r;
		}
		const total = Number(r.headers.get('Content-Length')) || __GZ_SIZE__;
		const reader = r.body.getReader();
		const parts = [];
		let got = 0;
		for (;;) {
			const { done, value } = await reader.read();
			if (done) break;
			parts.push(value);
			got += value.length;
			note.textContent = '下載遊戲中… ' + Math.min(99, Math.round(got / total * 100)) + '%';
		}
		const blob = new Blob(parts);
		const head = new Uint8Array(await blob.slice(0, 2).arrayBuffer());
		note.textContent = '解壓縮中…';
		let body = blob.stream();
		if (head[0] === 0x1f && head[1] === 0x8b) {
			body = body.pipeThrough(new DecompressionStream('gzip'));
		}
		const buf = await new Response(body).arrayBuffer();
		note.textContent = '啟動中…';
		setTimeout(() => note.remove(), 4000);
		return new Response(buf, { status: 200, headers: { 'Content-Type': 'application/wasm', 'Content-Length': String(buf.byteLength) } });
	};
})();
</script>
<style>
#mw-load { position: fixed; left: 0; right: 0; bottom: 18%; text-align: center; color: #f4ecd6;
	font: 16px/1.4 system-ui, sans-serif; z-index: 5; text-shadow: 0 1px 3px #000; pointer-events: none; }
body { background-color: #0b2a33; }
#status { background-color: #0b2a33 !important; }
</style>
"""
gz_size = os.path.getsize(os.path.join(out, "engine.wasm"))
# co-op bridge (window.MWNet) for scripts/net.gd
NET = "<script>\n" + open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "mwnet.js"), encoding="utf-8").read() + "</script>\n"
if "mw-load" not in html:
    html = html.replace('<script src="index.js"></script>', SHIM.replace("__GZ_SIZE__", str(gz_size)).replace("__BUILD__", str(int(time.time()))) + NET + '<script src="index.js"></script>')
html = html.replace('<html lang="en">', '<html lang="zh-Hant">')
html = html.replace('"ensureCrossOriginIsolationHeaders":true', '"ensureCrossOriginIsolationHeaders":false')
open(html_path, "w", encoding="utf-8").write(html)
for name in sorted(os.listdir(out)):
    print("%-34s %8.1f KB" % (name, os.path.getsize(os.path.join(out, name)) / 1024))
