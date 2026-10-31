#!/usr/bin/env python3
"""The balance of a pack of weapons on one sheet: for every weapon in it how
long it takes to bring down somebody with 100 health at every distance, aimed
and from the hip, standing and walking, worked out from the numbers in
weapons/<name>.tres. No game is started and no GPU is used.

    tools/weapon_sheet.py                every pack in assets/packs.json
    tools/weapon_sheet.py close far      those packs
    tools/weapon_sheet.py --table        only the tables, in the terminal
    tools/weapon_sheet.py --shots        the shots it takes to do 100, aimed
                                         and standing, of every weapon there
                                         is at 5, 10, 20, 40 and 80 m, as JSON:
                                         what the self-test sets the game's
                                         own count next to

A sheet lands in benchmark/sheets/weapons_<pack>.png, next to it the .svg it
was drawn from. A pack is drawn once the data of all its weapons is there,
built into the game or not, so that a weapon can be weighed before it is
modelled.

How it is worked out, as scripts/weapons.gd fires: aimed, the time starts
with bringing the sights up, which is what a rifle that kills in one shot
pays for; from the hip it starts with the first shot. The damage of a hit falls
off between falloff_start and falloff_end; the spread is spread evenly over a
disc, of which the part that falls on a torso (taken as a disc of 0.27 m, as
much as 45 by 60 cm) hits, for every pellet of a load. What is needed is the
average: so many hits that on average they add up to 100. Between two shots
is 60 / rounds_per_minute, and a magazine that runs out costs a reload.
Recoil, bloom and a hand that is not steady are not in it: a weapon that
kicks does worse in the game than here. Heads are not in it either.

What it says of a pack, on the sheet and in the terminal, weighing aimed
against aimed and the hip against the hip:
- for each weapon the bands of distances at which it is the quickest;
- a weapon that is never the quickest;
- a weapon that is within 10% of the quickest at every distance, which leaves
  the others nothing;
- the sidearm of the pack, if it names one, where it is the quickest: it is
  what is drawn when a magazine runs dry, not a weapon of its own.
"""
import json
import math
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "benchmark", "sheets")
HEALTH = 100.0
TORSO = 0.27
DISTANCES = list(range(1, 121))
COLUMNS = [5, 10, 20, 35, 50, 80, 120]
# Walking speed of the player, and the share of moving spread left over the
# sights (scripts/weapons.gd, current_spread_deg()).
WALK = 5.0
AIMED_MOVING = 0.3
STANCES = [("aimed", True, False), ("hip", False, False), ("aimed, walking", True, True), ("hip, walking", False, True)]
COLOURS = ["#1f6fb2", "#d4542a", "#2a9d5b", "#8a4fbf", "#c4961a", "#3b3b3b", "#d13f8f"]
TOO_LONG = 1.5
# Where nobody brings anybody down within this many seconds, nobody is the
# quickest: that is no distance to fight at with these.
USEFUL = 1.0


def defaults():
    """The defaults of WeaponData, from scripts/weapon_data.gd itself."""
    found = {}
    for line in open(os.path.join(ROOT, "scripts", "weapon_data.gd")):
        m = re.match(r"@export var (\w+) := (.+)$", line.strip())
        if m:
            found[m.group(1)] = parse(m.group(2))
    return found


def parse(text):
    text = text.strip()
    if text in ("true", "false"):
        return text == "true"
    try:
        return float(text)
    except ValueError:
        return text.strip('"&')


def weapon(name, base):
    path = os.path.join(ROOT, "weapons", name + ".tres")
    if not os.path.exists(path):
        return None
    data = dict(base)
    data["name"] = name
    for line in open(path):
        m = re.match(r"(\w+) = (.+)$", line.strip())
        if m:
            data[m.group(1)] = parse(m.group(2))
    return data


def spread(w, aimed, moving):
    deg = w["ads_spread_deg"] if aimed else w["hip_spread_deg"]
    if moving:
        deg += w["move_spread_deg"] * min(WALK / 8.0, 1.5) * (AIMED_MOVING if aimed else 1.0)
    return deg


def shots(w, distance, aimed, moving):
    """How many shots it takes on average to do 100 at `distance`, or None if
    that is more than three magazines or out of reach."""
    if distance > w["max_range"]:
        return None
    reach = max(w["falloff_end"] - w["falloff_start"], 1e-6)
    scale = 1.0 + (distance - w["falloff_start"]) / reach * (w["min_damage_scale"] - 1.0)
    scale = min(1.0, max(w["min_damage_scale"], scale))
    cone = distance * math.tan(math.radians(spread(w, aimed, moving)))
    share = 1.0 if cone <= TORSO else (TORSO / cone) ** 2
    per_shot = w["damage"] * scale * w["pellets"] * share
    if per_shot <= 0.0:
        return None
    needed = math.ceil(HEALTH / per_shot - 1e-9)
    if w["bunch"] > 0:
        needed = min(needed, int(w["bunch"]))
    return needed if needed <= w["mag_size"] * 3 else None


def ttk(w, distance, aimed, moving):
    """Seconds from the moment somebody is seen, the weapon at the hip, to the
    last shot that is needed, or None: aimed, that begins with bringing the
    sights up (ads_time)."""
    needed = shots(w, distance, aimed, moving)
    if needed is None:
        return None
    reloads = (needed - 1) // int(w["mag_size"])
    return (w["ads_time"] if aimed else 0.0) + (needed - 1) * 60.0 / w["rounds_per_minute"] + reloads * w["reload_time"]


def verdict(weapons, sidearm):
    """Per weapon and way of holding it the distances it is quickest at, and
    what is wrong with the pack. Aimed is weighed against aimed and the hip
    against the hip; the sidearm is what is drawn when a magazine runs dry,
    and is meant to be the quickest nowhere."""
    quickest = {w["name"]: {} for w in weapons}
    close = {w["name"]: True for w in weapons}
    for title, aimed, moving in STANCES:
        for w in weapons:
            quickest[w["name"]][title] = []
        for d in DISTANCES:
            times = {w["name"]: ttk(w, d, aimed, moving) for w in weapons}
            known = [t for n, t in times.items() if t is not None and n != sidearm]
            if not known:
                continue
            top = min(known)
            if top > USEFUL:
                continue
            for w in weapons:
                t = times[w["name"]]
                if t is not None and t <= top + 1e-9:
                    quickest[w["name"]][title].append(d)
                if t is None or t > max(top * 1.1, top + 0.02):
                    close[w["name"]] = False
    faults = []
    notes = []
    for w in weapons:
        anywhere = any(quickest[w["name"]].values())
        if w["name"] == sidearm:
            if anywhere:
                notes.append("%s, the sidearm, is the quickest at %s" % (w["display_name"], bands(sorted(set(sum(quickest[w["name"]].values(), []))))))
            continue
        if not anywhere:
            faults.append("%s is never the quickest, aimed or from the hip" % w["display_name"])
        if close[w["name"]] and len(weapons) > 1:
            faults.append("%s is within 10%% of the quickest everywhere" % w["display_name"])
    return quickest, faults, notes


def where(quickest, name, sidearm):
    if name == sidearm:
        return "the sidearm"
    parts = ["%s %s" % (title, bands(d)) for title, d in quickest[name].items() if d]
    return "quickest " + "; ".join(parts) if parts else "quickest nowhere"


def bands(distances):
    """[3, 4, 5, 9, 10] as "3-5, 9-10 m"."""
    if not distances:
        return "nowhere"
    runs = []
    start = prev = distances[0]
    for d in distances[1:] + [None]:
        if d is not None and d == prev + 1:
            prev = d
            continue
        runs.append("%d" % start if start == prev else "%d-%d" % (start, prev))
        if d is not None:
            start = prev = d
    return ", ".join(runs) + " m"


def table(weapons):
    rows = ["| | " + " | ".join("%d m" % d for d in COLUMNS) + " |", "|---" * (len(COLUMNS) + 1) + "|"]
    for title, aimed, moving in STANCES[:2]:
        for w in weapons:
            cells = []
            for d in COLUMNS:
                t = ttk(w, d, aimed, moving)
                cells.append("–" if t is None else "%.2f" % t)
            rows.append("| %s, %s | %s |" % (w["display_name"], title, " | ".join(cells)))
    return "\n".join(rows)


def svg(pack, spec, weapons, quickest, faults, notes, sidearm):
    width, M = 1500, 60
    panel_w, panel_h = 660, 380
    gap = 60
    out = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%s" font-family="Arial">' % (width, "{height}"),
           '<rect width="100%" height="100%" fill="#f6f4ee"/>',
           '<text x="%d" y="%d" font-size="30" font-weight="bold" fill="#111">%s</text>' % (M, M, spec.get("title", pack)),
           '<text x="%d" y="%d" font-size="16" fill="#444">%s Time to bring down somebody with 100 health, worked out from the weapon data: no recoil, no heads.</text>' % (M, M + 28, spec.get("about", ""))]
    for i, (title, aimed, moving) in enumerate(STANCES):
        x0 = M + (i % 2) * (panel_w + gap)
        y0 = M + 70 + (i // 2) * (panel_h + 80)
        X = lambda d: x0 + 50 + d / DISTANCES[-1] * (panel_w - 60)
        Y = lambda t: y0 + panel_h - 30 - min(t, TOO_LONG) / TOO_LONG * (panel_h - 50)
        out.append('<text x="%d" y="%d" font-size="18" font-weight="bold" fill="#222">%s</text>' % (x0, y0, title))
        for t in [0.0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5]:
            out.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#ddd"/>' % (X(0), Y(t), X(DISTANCES[-1]), Y(t)))
            out.append('<text x="%.1f" y="%.1f" font-size="12" fill="#666" text-anchor="end">%.2f s</text>' % (X(0) - 6, Y(t) + 4, t))
        for d in [0, 10, 20, 35, 50, 80, 120]:
            out.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#ddd"/>' % (X(d), Y(0), X(d), Y(TOO_LONG)))
            out.append('<text x="%.1f" y="%.1f" font-size="12" fill="#666" text-anchor="middle">%d m</text>' % (X(d), Y(0) + 18, d))
        # The band of 0.25 to 0.4 s that a weapon should reach at its own distance.
        out.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="#2a9d5b" opacity="0.08"/>' % (X(0), Y(0.4), X(DISTANCES[-1]) - X(0), Y(0.25) - Y(0.4)))
        for k, w in enumerate(weapons):
            points = []
            segments = []
            for d in DISTANCES:
                t = ttk(w, d, aimed, moving)
                if t is None or t > TOO_LONG:
                    if points:
                        segments.append(points)
                    points = []
                    continue
                points.append("%.1f,%.1f" % (X(d), Y(t)))
            if points:
                segments.append(points)
            for seg in segments:
                out.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="3" stroke-linejoin="round"/>' % (" ".join(seg), COLOURS[k % len(COLOURS)]))
    y = M + 70 + 2 * (panel_h + 80) + 10
    for k, w in enumerate(weapons):
        out.append('<rect x="%d" y="%d" width="22" height="6" fill="%s"/>' % (M, y - 6, COLOURS[k % len(COLOURS)]))
        out.append('<text x="%d" y="%d" font-size="16" fill="#111"><tspan font-weight="bold">%s</tspan>  ·  %d per hit, %d a minute, %d in a magazine  ·  %s</text>'
                   % (M + 32, y, w["display_name"], w["damage"] * w["pellets"], w["rounds_per_minute"], w["mag_size"], where(quickest, w["name"], sidearm)))
        y += 26
    y += 8
    if faults:
        for fault in faults:
            out.append('<text x="%d" y="%d" font-size="16" fill="#b3261e">✗ %s</text>' % (M, y, fault))
            y += 24
    else:
        out.append('<text x="%d" y="%d" font-size="16" fill="#2a7a3b">✓ every weapon is the quickest somewhere, and none is close to the quickest everywhere</text>' % (M, y))
    for note in notes:
        y += 24
        out.append('<text x="%d" y="%d" font-size="16" fill="#b26a00">! %s</text>' % (M, y, note))
    out.append("</svg>")
    return "\n".join(out).replace("{height}", str(y + 40), 1)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    only_table = "--table" in sys.argv
    packs = json.load(open(os.path.join(ROOT, "assets", "packs.json")))["packs"]
    base = defaults()
    if "--shots" in sys.argv:
        found = {}
        for file in sorted(os.listdir(os.path.join(ROOT, "weapons"))):
            if file.endswith(".tres"):
                w = weapon(file[:-5], base)
                # Barrels that spin are not aimed: holding the aim spins them.
                aimed = not w.get("aim_spins", False)
                found[w["name"]] = {str(d): shots(w, d, aimed, False) for d in (5, 10, 20, 40, 80)}
        print(json.dumps(found))
        return
    os.makedirs(OUT, exist_ok=True)
    for pack, spec in packs.items():
        if args and pack not in args:
            continue
        weapons = [weapon(n, base) for n in spec["weapons"]]
        if any(w is None for w in weapons):
            missing = [n for n, w in zip(spec["weapons"], weapons) if w is None]
            print("%s: no data yet for %s" % (pack, ", ".join(missing)))
            continue
        for w in weapons:
            w.setdefault("display_name", w["name"])
        sidearm = spec.get("sidearm", "")
        quickest, faults, notes = verdict(weapons, sidearm)
        print("\n## %s\n" % spec.get("title", pack))
        print(table(weapons))
        print()
        for w in weapons:
            print("- %s: %s" % (w["display_name"], where(quickest, w["name"], sidearm)))
        for fault in faults:
            print("- FAULT: %s" % fault)
        for note in notes:
            print("- note: %s" % note)
        if only_table:
            continue
        path = os.path.join(OUT, "weapons_%s.svg" % pack)
        open(path, "w").write(svg(pack, spec, weapons, quickest, faults, notes, sidearm))
        subprocess.run(["rsvg-convert", "-o", path[:-4] + ".png", path], check=True)
        print("sheet: %s" % os.path.relpath(path[:-4] + ".png", ROOT))


if __name__ == "__main__":
    main()
