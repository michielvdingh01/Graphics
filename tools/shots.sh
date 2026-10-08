#!/bin/sh
# Quick benchmark screenshots tiled into one image (needs ImageMagick).
cd "$(dirname "$0")/.." && tools/benchmark.sh --quick 2>&1 | grep "fps\|ERROR"
D=benchmark/results/$(ls -t benchmark/results | head -1)
montage "$D"/*.png -resize 960x540 -tile 2x -geometry +2+2 "$D/sheet.jpg" 2>/dev/null
echo "$D"
