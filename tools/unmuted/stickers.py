#!/usr/bin/env python3
"""Draws the stickers of the Unmuted match as SVG and renders them to PNG with
rsvg-convert: assets/unmuted/stickers/<name>.svg and <name>.png.

  python3 tools/unmuted/stickers.py

ballerina, tung and bombardiro: the slop memes, see tools/unmuted/memes.py.

unmuted: the logo of Unmuted (assets/unmuted/logo.svg, white) on a black pill,
cut out with a white edge as a sticker is. The PNG is 1024 by 512 with
transparency round the edge; scripts/sticker.gd lays it on as a decal.

It also renders the logo alone, white on nothing, 1312 wide, to
assets/unmuted/logo.png: what the look unmuted of tools/characters/looks.py
prints on the shirts.

And a banknote of its own, no real one: green paper, a dollar sign in a
ring at either end and IN ICP WE TRUST between, 512 by 220, to
assets/unmuted/bill.png. The ICP drops them as he walks (scripts/icp_body.gd).
"""
import pathlib
import re
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import memes  # noqa: E402

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


# The slop memes of the Slop Soldiers are drawn in tools/unmuted/memes.py,
# each on 1024 by 1024.
STICKERS = {"unmuted": unmuted, **memes.MEMES}


def bill() -> str:
    w, h = 512, 220
    ink = "#1f4a2c"
    font = "font-family='Georgia, serif' font-weight='bold'"
    rings = "".join(f"""
  <circle cx="{x}" cy="{h / 2}" r="62" fill="#b9d0a6" stroke="{ink}" stroke-width="7"/>
  <text x="{x}" y="{h / 2 + 30}" text-anchor="middle" font-size="88" fill="{ink}" {font}>$</text>""" for x in (84, w - 84))
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
  <rect x="0" y="0" width="{w}" height="{h}" fill="#d3dfc3"/>
  <rect x="10" y="10" width="{w - 20}" height="{h - 20}" fill="#c7d8b4" stroke="{ink}" stroke-width="8"/>
  <rect x="22" y="22" width="{w - 44}" height="{h - 44}" fill="none" stroke="{ink}" stroke-width="2"/>{rings}
  <text x="{w / 2}" y="{h / 2 - 22}" text-anchor="middle" font-size="26" fill="{ink}" {font}>IN ICP</text>
  <text x="{w / 2}" y="{h / 2 + 12}" text-anchor="middle" font-size="26" fill="{ink}" {font}>WE TRUST</text>
  <text x="{w / 2}" y="{h / 2 + 62}" text-anchor="middle" font-size="44" fill="{ink}" {font}>100</text>
</svg>
"""


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, draw in STICKERS.items():
        svg = OUT / (name + ".svg")
        svg.write_text(draw())
        subprocess.run(["rsvg-convert", str(svg), "-o", str(OUT / (name + ".png"))], check=True)
        print(OUT / (name + ".png"))
    subprocess.run(["rsvg-convert", "-w", "1312", str(LOGO), "-o", str(LOGO.with_suffix(".png"))], check=True)
    note = ROOT / "assets/unmuted/bill.svg"
    note.write_text(bill())
    subprocess.run(["rsvg-convert", str(note), "-o", str(note.with_suffix(".png"))], check=True)
    print(note.with_suffix(".png"))
    print(LOGO.with_suffix(".png"))


if __name__ == "__main__":
    main()
