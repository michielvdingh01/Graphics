#!/usr/bin/env python3
"""Draws the stickers of the Unmuted match as SVG and renders them to PNG with
rsvg-convert: assets/unmuted/stickers/<name>.svg and <name>.png.

  python3 tools/unmuted/stickers.py

unmuted: the logo of Unmuted (assets/unmuted/logo.svg, white) on a black pill,
cut out with a white edge as a sticker is. The PNG is 1024 by 512 with
transparency round the edge; scripts/sticker.gd lays it on as a decal.
"""
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/unmuted/stickers"
LOGO = ROOT / "assets/unmuted/logo.svg"


def logo_paths(fill: str) -> str:
    text = LOGO.read_text()
    return "\n".join(p.replace('fill="white"', 'fill="%s"' % fill) for p in re.findall(r"<path[^>]*/>", text))


def unmuted() -> str:
    # The pill, 1000 by 480 inside a canvas of 1024 by 512, with an edge of
    # white 22 wide; the logo (328 by 65) fills most of its width.
    w, h, edge = 1024, 512, 22
    scale = 2.35
    lw, lh = 328 * scale, 65 * scale
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
  <rect x="12" y="16" width="{w - 24}" height="{h - 32}" rx="{(h - 32) / 2}" fill="white"/>
  <rect x="{12 + edge}" y="{16 + edge}" width="{w - 24 - 2 * edge}" height="{h - 32 - 2 * edge}" rx="{(h - 32) / 2 - edge}" fill="#0b0b0c"/>
  <g transform="translate({(w - lw) / 2:.1f},{(h - lh) / 2:.1f}) scale({scale})">
{logo_paths("white")}
  </g>
</svg>
"""


STICKERS = {"unmuted": unmuted}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, draw in STICKERS.items():
        svg = OUT / (name + ".svg")
        svg.write_text(draw())
        subprocess.run(["rsvg-convert", str(svg), "-o", str(OUT / (name + ".png"))], check=True)
        print(OUT / (name + ".png"))


if __name__ == "__main__":
    main()
