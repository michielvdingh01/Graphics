#!/usr/bin/env python3
"""Plays a sound the way the game does, without starting the game.

A take on disk is not what the player hears. The game picks a take at random,
bends its pitch a little and sends it through the World bus, with the reverb
of the hall and a clipper, and through the limiter on Master. This renders
that with Godot (tools/render_mix.gd), writes it to .cache/hear/<sound>.wav
and plays it. It plays every sound the way the player's own weapon plays: at
full level and in the middle, not quieter or from a distance as the game
plays a footstep or an enemy's shot.

    tools/hear.py rifle_shot              one shot
    tools/hear.py rifle_shot 620          a second and a half at 620 rounds per minute
    tools/hear.py --quiet smg_shot 900    only writes the file

Only recorded sounds, those with a folder in assets/audio/.
"""
import json
import os
import pathlib
import random
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / ".cache/hear"
GODOT = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
START = 0.1  # seconds of silence before the first shot
TAIL = 2.5  # seconds rendered after the last one, for the reverb to die away
FIRE = 1.5  # seconds a burst lasts


def render(sound: str, rate: float) -> pathlib.Path:
    takes = sorted((ROOT / "assets/audio" / sound).glob("*.wav"))
    if not takes:
        raise SystemExit(f"no takes in assets/audio/{sound}/")
    shots = max(1, int(FIRE * rate / 60.0)) if rate else 1
    # As scripts/sfx.gd does: never the same take twice in a row, and the
    # pitch a little off each time, less so for a weapon.
    spread = 0.03 if sound.endswith("_shot") else 0.06
    events = []
    take = 0
    for i in range(shots):
        if len(takes) > 1:
            take = (take + 1 + random.randrange(len(takes) - 1)) % len(takes)
        events.append({
            "t": START + i * 60.0 / rate if rate else START,
            "file": str(takes[take]), "bus": "World",
            "pitch": random.uniform(1.0 - spread, 1.0 + spread),
        })
    OUT.mkdir(parents=True, exist_ok=True)
    spec = OUT / f"{sound}.json"
    out = OUT / f"{sound}.wav"
    spec.write_text(json.dumps({
        "layout": str(ROOT / "default_bus_layout.tres"),
        "length": events[-1]["t"] + TAIL,
        "events": events,
    }, indent="\t"))
    # Run in an empty project of its own: without one Godot takes itself for
    # the editor and rewrites the editor's settings, and in the game's own
    # the title screen would be in the way.
    (OUT / "project.godot").write_text("config_version=5\n")
    result = subprocess.run(
        [GODOT, "--headless", "--path", str(OUT), "--log-file", str(OUT / "godot.log"), "--script", str(ROOT / "tools/render_mix.gd"), "--", str(spec), str(out)],
        cwd=OUT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True,
    )
    if result.returncode != 0:
        raise SystemExit(result.stdout)
    return out


def main() -> None:
    args = [arg for arg in sys.argv[1:] if arg != "--quiet"]
    if not args:
        raise SystemExit(__doc__)
    out = render(args[0], float(args[1]) if len(args) > 1 else 0.0)
    print(out.relative_to(ROOT))
    if "--quiet" not in sys.argv:
        subprocess.run(["afplay", str(out)], check=True)


if __name__ == "__main__":
    main()
