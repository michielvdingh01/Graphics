#!/usr/bin/env python3
"""Draws what is written and shown on the two bases of the Unmuted match as SVG
and renders it with rsvg-convert into assets/unmuted/:

  python3 tools/unmuted/signs.py

doomscroll.png and hell.png: the words DOOMSCROLL and HELL in red on
nothing, for the letters that glow red on the front of Doomscroll Hell
(materials/doomscroll_sign.tres and doomscroll_hell.tres have them
glow). feed.png: the screen of a phone with a feed on it, posts of colour,
hearts and the bars of text, for the screens on that front. The canal house
of Unmuted carries the sticker of tools/unmuted/stickers.py in its gable.
tools/models/unmuted.gd builds the two.
"""
import pathlib
import random
import subprocess

OUT = pathlib.Path(__file__).resolve().parents[2] / "assets/unmuted"
FONT = "font-family='Impact, Arial Black, sans-serif' font-weight='900'"


def words(text: str, w: int, h: int, size: int) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
  <text x="{w / 2}" y="{h * 0.84}" text-anchor="middle" font-size="{size}" letter-spacing="{size * 0.04:.0f}" fill="#ff1408" {FONT}>{text}</text>
</svg>
"""


def feed() -> str:
    w, h = 512, 1024
    rng = random.Random(7)
    colours = ["#ff3d6e", "#ffb02e", "#3ddcff", "#9b5cff", "#2eff9a", "#ff6a2e", "#ff2ec4"]
    parts = [f'<rect width="{w}" height="{h}" rx="48" fill="#08080b"/>',
             f'<rect x="196" y="22" width="120" height="18" rx="9" fill="#1b1b22"/>']
    y = 64
    while y < h - 120:
        tall = rng.choice([300, 360, 420])
        c1, c2 = rng.sample(colours, 2)
        parts.append(f'<defs><linearGradient id="g{y}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/></linearGradient></defs>')
        parts.append(f'<rect x="28" y="{y}" width="{w - 56}" height="{tall}" rx="22" fill="url(#g{y})"/>')
        # A face of sorts, or a shape, in the middle of the post.
        parts.append(f'<circle cx="{w / 2}" cy="{y + tall * 0.45:.0f}" r="{tall * 0.18:.0f}" fill="white" fill-opacity="0.35"/>')
        # Hearts and counts down the right, the bars of a caption under it.
        for i in range(3):
            cy = y + tall - 150 + i * 46
            parts.append(f'<path d="M{w - 70},{cy} c-12,-14 -34,-4 -22,14 l22,20 l22,-20 c12,-18 -10,-28 -22,-14z" fill="white" fill-opacity="0.9"/>')
        parts.append(f'<rect x="44" y="{y + tall - 64}" width="{rng.randint(180, 300)}" height="16" rx="8" fill="white" fill-opacity="0.85"/>')
        parts.append(f'<rect x="44" y="{y + tall - 38}" width="{rng.randint(120, 240)}" height="12" rx="6" fill="white" fill-opacity="0.6"/>')
        y += tall + 22
    parts.append(f'<rect x="0" y="{h - 92}" width="{w}" height="92" fill="#0e0e13"/>')
    for i in range(5):
        parts.append(f'<circle cx="{64 + i * 96}" cy="{h - 46}" r="17" fill="{"#ffffff" if i == 2 else "#55556a"}"/>')
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">\n' + "\n".join(parts) + "\n</svg>\n"


ART = {
    "doomscroll": lambda: words("DOOMSCROLL", 2048, 330, 300),
    "hell": lambda: words("HELL", 1024, 420, 400),
    "feed": feed,
}


def main() -> None:
    for name, draw in ART.items():
        svg = OUT / (name + ".svg")
        svg.write_text(draw())
        subprocess.run(["rsvg-convert", str(svg), "-o", str(OUT / (name + ".png"))], check=True)
        print(OUT / (name + ".png"))


if __name__ == "__main__":
    main()
