#!/bin/sh
# Build the phone / browser version into ../webbuild:
#   1. rebuild the Chinese font subset from every string in the scripts
#   2. export with the "Web" preset (single-threaded, Compatibility renderer)
#   3. gzip the engine and add the unpacking loader (tools/web_post.py)
# Usage: sh tools/build_web.sh [path-to-godot]
set -e
cd "$(dirname "$0")/.."
GODOT="${1:-godot}"
python3 tools/make_font.py
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
rm -rf ../webbuild && mkdir -p ../webbuild
"$GODOT" --headless --path . --export-release "Web" ../webbuild/index.html
python3 tools/web_post.py ../webbuild
mkdir -p ../webpub
python3 tools/web_artifact.py ../webbuild ../webpub/madwater.html
