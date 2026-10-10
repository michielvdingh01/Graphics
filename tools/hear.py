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
    tools/hear.py reload shotgun          a shot and then the weapon being reloaded,
                                          each step at the moment the game plays it
    tools/hear.py casings rifle           a burst, with the cases landing after it
    tools/hear.py grenade                 the pin, the throw, three bounces and the bang

Only recorded sounds, those with a folder in assets/audio/.
"""
import json
import os
import pathlib
import random
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / ".cache/hear"
GODOT = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
START = 0.1  # seconds of silence before the first shot
TAIL = 2.5  # seconds rendered after the last one, for the reverb to die away
FIRE = 1.5  # seconds a burst lasts


def played(sound: str, times: list, db: float = 0.0) -> list:
    """The events of a sound played at each of `times`, as scripts/sfx.gd
    plays it: never the same take twice in a row, and the pitch a little off
    each time, less so for a weapon."""
    takes = sorted((ROOT / "assets/audio" / sound).glob("*.wav"))
    if not takes:
        raise SystemExit(f"no takes in assets/audio/{sound}/")
    spread = 0.03 if sound.endswith("_shot") else 0.06
    events = []
    take = 0
    for at in times:
        if len(takes) > 1:
            take = (take + 1 + random.randrange(len(takes) - 1)) % len(takes)
        events.append({
            "t": at, "file": str(takes[take]), "bus": "World", "db": db,
            "pitch": random.uniform(1.0 - spread, 1.0 + spread),
        })
    return events


def reload(weapon: str) -> list:
    """A shot and the reload after it. The moments and the levels are those
    of scripts/weapons.gd, and a step is the weapon's own sound if it has
    one and else the one all weapons share, as there. A step that is still
    synthesised in the game is left out and named."""
    path = ROOT / "weapons" / f"{weapon}.tres"
    if not path.exists():
        raise SystemExit(f"no weapon named {weapon}")
    data = dict(re.findall(r"^(\w+) = (.+)$", path.read_text(), re.M))
    time = float(data.get("reload_time", 1.8))

    def step(name: str, at: float, db: float) -> list:
        for sound in (f"{weapon}_{name}", name):
            if (ROOT / "assets/audio" / sound).is_dir():
                return played(sound, [at], db)
        print(f"{name}: no recording yet, left out")
        return []

    events = played(f"{weapon}_shot", [START])
    begin = START + 0.9
    if data.get("loads_singly") == "true":
        events += step("pump", START + 0.14, -7.0)
        shells = int(data.get("mag_size", 6))
        each = time / shells
        for i in range(shells):
            events += step("shell_in", begin + 0.35 + (i + 0.55) * each, -9.0)
        events += step("pump", begin + 0.35 + time + 0.3, -6.0)
    else:
        for name, moment in (("mag_out", 0.14), ("mag_in", 0.72), ("bolt", 0.88)):
            events += step(name, begin + moment * time, -9.0)
    return events


def casings(weapon: str) -> list:
    """Five shots and the case of each landing, at the level the game plays it."""
    shell = weapon == "shotgun" and (ROOT / "assets/audio/shell_drop").is_dir()
    times = [START + i * (0.75 if weapon == "shotgun" else 0.25) for i in range(5)]
    events = played(f"{weapon}_shot", times)
    for at in times:
        events += played("shell_drop" if shell else "casing", [at + random.uniform(0.5, 0.65)], -24.0)
    return events


def grenade() -> list:
    """A grenade from the pin to the bang: the levels of scripts/weapons.gd,
    and bounces that get quieter as scripts/grenade.gd has them."""
    events = played("pin", [START], -4.0) + played("throw", [START + 0.22], -6.0)
    for after, db in ((1.0, -4.0), (1.45, -9.0), (1.75, -14.0)):
        events += played("bounce", [START + after], db)
    return events + played("explosion", [START + 0.22 + 2.2])


def render(sound: str, rate: float) -> pathlib.Path:
    if sound == "reload":
        raise SystemExit("say which weapon: tools/hear.py reload shotgun")
    shots = max(1, int(FIRE * rate / 60.0)) if rate else 1
    return mixed(sound, played(sound, [START + i * 60.0 / rate if rate else START for i in range(shots)]))


def mixed(name: str, events: list) -> pathlib.Path:
    events.sort(key=lambda event: event["t"])
    OUT.mkdir(parents=True, exist_ok=True)
    spec = OUT / f"{name}.json"
    out = OUT / f"{name}.wav"
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
    if args[0] == "reload" and len(args) > 1:
        out = mixed(f"reload_{args[1]}", reload(args[1]))
    elif args[0] == "casings" and len(args) > 1:
        out = mixed(f"casings_{args[1]}", casings(args[1]))
    elif args[0] == "grenade":
        out = mixed("grenade", grenade())
    else:
        out = render(args[0], float(args[1]) if len(args) > 1 else 0.0)
    print(out.relative_to(ROOT))
    if "--quiet" not in sys.argv:
        subprocess.run(["afplay", str(out)], check=True)


if __name__ == "__main__":
    main()
