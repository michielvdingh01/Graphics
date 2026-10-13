#!/usr/bin/env python3
"""Stands soldiers in different uniforms side by side in the factory hall and
makes one sheet to tell them apart by: tools/characters/uniform_sheet.py [id ...]

Without ids it shows soldier_01 as it came next to soldier_01 in every
uniform of UNIFORMS (looks.py). A uniform that soldier_01 has not been built
in is tried on for the pictures and taken off again: such a try-out is in no
manifest and leaves nothing behind. With ids it shows those characters, and
the first is the one the others are held against.

The figures are looked at from 5, 20 and 40 metres, once under the lamp at
the west end of the hall and once in the shade against its east wall, the
one dark place in it that four people abreast can be seen in from 40 metres
away. The pictures are taken the way the game is played: on the full screen
of the laptop with MetalFX, at the scale a player starts with. For every
picture the sheet has the figures cut out and enlarged, and next to that the
same cut at the size it has on screen.

It also measures, on the pictures: how bright and what colour every figure
is on screen, how far that is from the first figure and how far from what is
behind it. What is behind a figure is known exactly, because every picture is
taken a second time without the figures. Distances are in CIELAB, in which 2
is the least that can be seen side by side and 10 is plain at a glance.

It takes two runs on the GPU, through tools/benchmark.sh, of half a minute
each. The sheet lands in assets/characters/sheets/uniforms.jpg and the
numbers next to it in uniforms.json; --name=<name> calls them something else.
"""
import json
import math
import pathlib
import re
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
CHARACTERS = ROOT / "assets/characters"
FONT = "/System/Library/Fonts/Supplemental/Arial.ttf"
SCREEN = (3456, 2160)
SETTINGS = ["--res=%dx%d" % SCREEN, "--upscaler=metalfx", "--quality=3", "--scale=auto"]
# The benchmark looks through a camera as Godot makes one: 75 degrees from top to bottom.
HALF_VIEW = math.tan(math.radians(37.5))
EYE = 1.7
# Metres between two figures, and from the outer ones to the edge of the cut.
APART = 0.7
MARGIN = 0.75
TALL = 2.15
# What of a figure is measured, in metres above the floor: boots, trousers,
# jacket and vest, up to under the shoulders. In the dark corner a strip of
# sun from a window lies across the wall above that, and across the head and
# shoulders of whoever stands at the north end of the row.
MEASURED = (0.12, 1.3)
# Where a row stands, which way it looks, and from where it is looked at:
# metres from the middle of the row, and the direction from there to the
# camera. Directions are in degrees from east towards south. See PLAN.md,
# "Twee uniformen", for how these two places were found: in this hall four
# figures abreast can be seen whole from 40 metres in very few of them.
PLACES = (
    ("in the light of the hall", (-19.6, -3.95), 0.0, ((5.0, 355.4), (20.0, 355.4), (39.5, 354.31))),
    ("in a dark corner", (19.5, 7.7), 180.0, ((5.0, 193.0), (20.0, 193.0), (39.9, 193.04))),
)
DISTANCES = tuple(distance for distance, _ in PLACES[0][3])
ARM = ('game.get_child(game.get_child_count()-{back}).get_node("%GeneralSkeleton").set_bone_global_pose('
       'game.get_child(game.get_child_count()-{back}).get_node("%GeneralSkeleton").find_bone("{bone}"), Transform3D(Basis(Vector3(0,0,1), {turn}) * '
       'game.get_child(game.get_child_count()-{back}).get_node("%GeneralSkeleton").get_bone_global_pose(game.get_child(game.get_child_count()-{back}).get_node("%GeneralSkeleton").find_bone("{bone}")).basis, '
       'game.get_child(game.get_child_count()-{back}).get_node("%GeneralSkeleton").get_bone_global_pose(game.get_child(game.get_child_count()-{back}).get_node("%GeneralSkeleton").find_bone("{bone}")).origin))')


def layout(ids: list) -> tuple:
    """Where everybody stands and where the camera is: the spawn and the view
    arguments of the benchmark, and for every view where the figures are."""
    spawns, views, shots = [], [], []
    for place, (x, z), facing, cameras in PLACES:
        ahead = (math.cos(math.radians(facing)), math.sin(math.radians(facing)))
        # To the left of somebody who looks at the camera is to the right in the picture.
        across = (-ahead[1], ahead[0])
        stand = []
        for index, name in enumerate(ids):
            aside = (index - (len(ids) - 1) / 2.0) * APART
            stand.append((x - across[0] * aside, z - across[1] * aside))
            spawns.append("res://assets/characters/%s/%s.glb@%.3f,0,%.3f,%.2f,1" % (name, name, stand[-1][0], stand[-1][1], math.degrees(math.atan2(ahead[0], ahead[1]))))
        for distance, angle in cameras:
            toward = (math.cos(math.radians(angle)), math.sin(math.radians(angle)))
            yaw = math.degrees(math.atan2(toward[0], toward[1]))
            pitch = -math.degrees(math.atan2(EYE - TALL * 0.45, distance))
            eye = (x + toward[0] * distance, EYE, z + toward[1] * distance)
            views.append("%.3f,%.2f,%.3f,%.2f,%.2f" % (eye[0], eye[1], eye[2], yaw, pitch))
            shots.append({"place": place, "distance": distance, "eye": eye, "yaw": yaw, "pitch": pitch, "stand": stand})
    return spawns, views, shots


def on_screen(shot: dict, point: tuple) -> tuple:
    """Where a point of the level lies in a picture, in pixels."""
    yaw, pitch = math.radians(shot["yaw"]), math.radians(shot["pitch"])
    offset = [point[index] - shot["eye"][index] for index in range(3)]
    # Into the camera's own axes: first undo its turn, then its tilt.
    x = offset[0] * math.cos(yaw) - offset[2] * math.sin(yaw)
    z = offset[0] * math.sin(yaw) + offset[2] * math.cos(yaw)
    y = offset[1] * math.cos(pitch) + z * math.sin(pitch)
    z = -offset[1] * math.sin(pitch) + z * math.cos(pitch)
    wide, high = shot["size"]
    scale = high / 2.0 / HALF_VIEW
    return wide / 2.0 + x / -z * scale, high / 2.0 - y / -z * scale


def box(shot: dict, stand: tuple, half: float, low: float = -0.05, high: float = TALL - 0.2) -> tuple:
    """The part of a picture a figure that stands there is in: left, top, right, bottom."""
    toward = (math.sin(math.radians(shot["yaw"])), math.cos(math.radians(shot["yaw"])))
    across = (-toward[1], toward[0])
    corners = [on_screen(shot, (stand[0] + across[0] * side, height, stand[1] + across[1] * side)) for side in (-half, half) for height in (low, high)]
    return (int(min(corner[0] for corner in corners)), int(min(corner[1] for corner in corners)),
            int(math.ceil(max(corner[0] for corner in corners))), int(math.ceil(max(corner[1] for corner in corners))))


def take(spawns: list, views: list, pose: bool) -> pathlib.Path:
    """One run of the benchmark; returns the folder its pictures are in."""
    command = [str(ROOT / "tools/benchmark.sh"), "--quick"] + SETTINGS + ["--at=" + ";".join(views)]
    if spawns:
        command.append("--spawn=" + ";".join(spawns))
        if pose:
            # A character stands as it was made, with its arms out. Nobody
            # stands like that in the game: let them hang.
            for back in range(1, len(spawns) + 1):
                for bone, turn in (("LeftUpperArm", -1.4), ("RightUpperArm", 1.4)):
                    command.append("--eval=" + ARM.format(back=back, bone=bone, turn=turn))
    done = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, stdin=subprocess.DEVNULL)
    saved = re.search(r"^Saved to (.+)$", done.stdout, re.M)
    if done.returncode != 0 or not saved:
        sys.exit("uniform_sheet: the benchmark did not come through\n" + "\n".join(done.stdout.splitlines()[-15:]))
    return pathlib.Path(saved.group(1).strip())


def magick(*arguments: str) -> None:
    done = subprocess.run(["magick"] + list(arguments), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    if done.returncode != 0:
        sys.exit("uniform_sheet: magick failed\n" + done.stdout[-600:])


def pixels(picture: pathlib.Path, part: tuple) -> list:
    """The pixels of a part of a picture, as (r, g, b) from 0 to 255, row by row."""
    width, height = part[2] - part[0], part[3] - part[1]
    raw = subprocess.run(["magick", str(picture), "-crop", "%dx%d+%d+%d" % (width, height, part[0], part[1]), "+repage", "-depth", "8", "rgb:-"], stdout=subprocess.PIPE).stdout
    return [(raw[index], raw[index + 1], raw[index + 2]) for index in range(0, width * height * 3, 3)]


def lab(colour: tuple) -> tuple:
    """A colour on screen, 0 to 255, as CIELAB: how light, and how far towards red and towards yellow."""
    linear = [(value / 255.0 / 12.92) if value <= 10.31 else ((value / 255.0 + 0.055) / 1.055) ** 2.4 for value in colour]
    x = (0.4124 * linear[0] + 0.3576 * linear[1] + 0.1805 * linear[2]) / 0.9505
    y = 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    z = (0.0193 * linear[0] + 0.1192 * linear[1] + 0.9505 * linear[2]) / 1.089
    fx, fy, fz = (value ** (1.0 / 3.0) if value > 0.008856 else 7.787 * value + 16.0 / 116.0 for value in (x, y, z))
    return 116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz)


def apart(first: tuple, second: tuple) -> float:
    return math.sqrt(sum((a - b) ** 2 for a, b in zip(lab(first), lab(second))))


def mean(colours: list) -> tuple:
    return tuple(sum(colour[channel] for colour in colours) / max(len(colours), 1) for channel in range(3))


def measure(shot: dict, with_figures: pathlib.Path, without: pathlib.Path) -> list:
    """For every figure in a picture: its mean colour and that of what it stands in front of."""
    parts = [box(shot, stand, APART * 0.47, *MEASURED) for stand in shot["stand"]]
    there = [pixels(with_figures, part) for part in parts]
    behind = [pixels(without, part) for part in parts]
    # A figure is where the picture differs from the one without it. The
    # four are the same figure, so they share the outline of the one that
    # stands out most: one that all but vanishes would otherwise be judged
    # by the few pixels of it that do show.
    outlines = [[max(abs(a[channel] - b[channel]) for channel in range(3)) > 14 for a, b in zip(with_it, bare)] for with_it, bare in zip(there, behind)]
    clearest = max(range(len(parts)), key=lambda index: sum(outlines[index]))
    wide, high = parts[clearest][2] - parts[clearest][0], parts[clearest][3] - parts[clearest][1]
    found = []
    for part, with_it, bare in zip(parts, there, behind):
        own_wide, own_high = part[2] - part[0], part[3] - part[1]
        own = [row * own_wide + column for row in range(own_high) for column in range(own_wide)
               if outlines[clearest][min(row * high // own_high, high - 1) * wide + min(column * wide // own_wide, wide - 1)]]
        figure, wall = mean([with_it[index] for index in own]), mean([bare[index] for index in own])
        found.append({"pixels": len(own), "colour": [round(value, 1) for value in figure], "behind": [round(value, 1) for value in wall],
                      "lightness": round(lab(figure)[0], 1), "lightness_behind": round(lab(wall)[0], 1), "from_behind": round(apart(figure, wall), 1)})
    for entry in found:
        entry["from_first"] = round(apart(tuple(entry["colour"]), tuple(found[0]["colour"])), 1)
    return found


def try_on(uniforms: list) -> list:
    """Makes soldier_01 in every uniform it does not exist in yet, and
    returns what it made, for take_off()."""
    made = []
    for uniform in uniforms:
        name = "soldier_01_" + uniform
        if (CHARACTERS / name / (name + ".glb")).exists():
            continue
        made.append(name)
        done = subprocess.run([str(ROOT / "tools/import_character.sh"), str(CHARACTERS / "soldier_01/soldier_01.glb"), name, "--route=repaint", "--look=" + uniform, "--no-manifest", "--no-sheet"],
                              cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, stdin=subprocess.DEVNULL)
        if done.returncode != 0:
            take_off(made)
            sys.exit("uniform_sheet: could not try the uniform %s on\n%s" % (uniform, done.stdout[-600:]))
    return made


def take_off(made: list) -> None:
    """Removes the try-outs again, with what Godot imported of them."""
    for name in made:
        for file in list((CHARACTERS / name).glob(name + ".glb*")) + list((ROOT / ".godot/imported").glob(name + ".glb-*")):
            file.unlink()
        (CHARACTERS / name).rmdir()


def main() -> None:
    name = next((argument.split("=", 1)[1] for argument in sys.argv[1:] if argument.startswith("--name=")), "uniforms")
    ids = [argument for argument in sys.argv[1:] if not argument.startswith("--")]
    made = []
    if not ids:
        looks = (ROOT / "tools/characters/looks.py").read_text()
        table = looks[looks.index("UNIFORMS = {"):]
        uniforms = re.findall(r'^    "(\w+)": \{', table[:table.index("\n}")], re.M)
        ids = ["soldier_01"] + ["soldier_01_" + uniform for uniform in uniforms]
        made = try_on(uniforms)
    for each in ids:
        if not (CHARACTERS / each / (each + ".glb")).exists():
            take_off(made)
            sys.exit("uniform_sheet: there is no character %s" % each)
    labels = ["as it came"] + [each[len(ids[0]) + 1:] if each.startswith(ids[0] + "_") else each for each in ids[1:]]
    spawns, views, shots = layout(ids)
    try:
        with_figures = take(spawns, views, True)
        without = take([], views, False)
    finally:
        take_off(made)

    # The window of a run is not the shape of the screen, and the picture is as wide as the window.
    size = tuple(int(value) for value in subprocess.run(["magick", "identify", "-format", "%w %h", str(with_figures / "Shot1.png")], stdout=subprocess.PIPE, text=True).stdout.split())
    numbers = []
    with tempfile.TemporaryDirectory() as scratch:
        scratch = pathlib.Path(scratch)
        cells = []
        wide = 0
        for index, shot in enumerate(shots):
            shot["size"] = size
            picture = with_figures / ("Shot%d.png" % (index + 1))
            results = measure(shot, picture, without / ("Shot%d.png" % (index + 1)))
            numbers.append({"place": shot["place"], "metres": shot["distance"], "figures": dict(zip(ids, results))})
            # The cut: the row of figures with some of the hall around it.
            boxes = [box(shot, stand, APART * 0.5) for stand in shot["stand"]]
            edge = int(MARGIN / APART * (boxes[0][2] - boxes[0][0]))
            left, right = min(each[0] for each in boxes) - edge, max(each[2] for each in boxes) + edge
            top, bottom = min(each[1] for each in boxes) - edge // 2, max(each[3] for each in boxes) + edge // 3
            cut = "%dx%d+%d+%d" % (right - left, bottom - top, left, top)
            # The nearest picture of a place goes on the sheet as it is, the others as wide as that one.
            if index % len(DISTANCES) == 0:
                wide = right - left
            times = wide / float(right - left)
            large, small, cell = scratch / ("large%d.png" % index), scratch / ("small%d.png" % index), scratch / ("cell%d.png" % index)
            magick(str(picture), "-crop", cut, "+repage", "-filter", "Catrom", "-resize", "%dx" % wide, str(large))
            magick(str(picture), "-crop", cut, "+repage", str(small))
            high = int(round((bottom - top) * times))
            title = "%s, from %g m%s" % (shot["place"], shot["distance"], "" if times < 1.05 else "   (enlarged %.0f times)" % times)
            arguments = ["-size", "%dx%d" % (wide + 40, 204 + high + 60 + high // 3), "xc:#1b1c1e", "-font", FONT,
                         "-gravity", "NorthWest", "-fill", "#ffffff", "-pointsize", "36", "-annotate", "+20+16", title, "-gravity", "North"]
            # Over every figure what it is, and what was measured of it.
            for label, entry, each in zip(labels, results, boxes):
                aside = int(((each[0] + each[2]) / 2.0 - left) * times - wide / 2.0)
                arguments += ["-fill", "#e6e6e6", "-pointsize", "28", "-annotate", "%+d+72" % aside, label,
                              "-fill", "#a8a8a8", "-pointsize", "20", "-annotate", "%+d+110" % aside, "lightness %.0f" % entry["lightness"],
                              "-annotate", "%+d+136" % aside, "behind it %.0f" % entry["lightness_behind"]]
                if entry is not results[0]:
                    arguments += ["-annotate", "%+d+162" % aside, "%.0f from the first" % entry["from_first"]]
            arguments += ["-gravity", "NorthWest", str(large), "-geometry", "+20+204", "-composite"]
            if times >= 1.05:
                arguments += [str(small), "-geometry", "+20+%d" % (204 + high + 40), "-composite", "-fill", "#a8a8a8", "-pointsize", "22",
                              "-annotate", "+%d+%d" % (20 + (right - left) + 18, 204 + high + 40 + (bottom - top) // 2 - 12), "the same, at the size it has on the screen"]
            magick(*(arguments + [str(cell)]))
            cells.append(str(cell))
        rows = []
        for row in range(len(PLACES)):
            rows.append(str(scratch / ("row%d.png" % row)))
            magick(*(["-background", "#1b1c1e"] + cells[row * len(DISTANCES):(row + 1) * len(DISTANCES)] + ["+append", rows[-1]]))
        # A line above it all that says what this is, and one below on how to read the numbers.
        head = "%s in %d uniforms, in the factory hall as the game shows it: %d by %d, MetalFX, quality Ultra, the scale a player starts with" % (ids[0], len(ids), SCREEN[0], SCREEN[1])
        foot = ("Lightness is that of the figure on screen, from the boots to under the shoulders, against that of what it stands in front of: 0 is black, 100 white. "
                "The last number is how far its colour is from the first figure's, in CIELAB: 2 can just be seen side by side, 10 is plain at a glance.")
        for text, size, colour, file in ((head, "40", "#ffffff", "head.png"), (foot, "24", "#a8a8a8", "foot.png")):
            magick("-size", "%dx%d" % (len(DISTANCES) * (wide + 40), int(size) * 2 + 16), "xc:#1b1c1e", "-font", FONT, "-fill", colour, "-pointsize", size, "-gravity", "West", "-annotate", "+20+0", text, str(scratch / file))
        sheet = CHARACTERS / "sheets" / (name + ".jpg")
        magick(*(["-background", "#1b1c1e", str(scratch / "head.png")] + rows + [str(scratch / "foot.png"), "-append", "-quality", "90", str(sheet)]))
    (CHARACTERS / "sheets" / (name + ".json")).write_text(json.dumps({"characters": ids, "screen": SCREEN, "pictures": numbers}, indent="\t") + "\n")

    print("%-28s %5s  %s" % ("", "", "  ".join("%-22s" % label[:22] for label in labels)))
    for entry in numbers:
        figures = [entry["figures"][each] for each in ids]
        print("%-26s %4.1f m  %s" % (entry["place"], entry["metres"], "  ".join("%-22s" % ("L %4.1f wall %4.1f" % (figure["lightness"], figure["lightness_behind"])) for figure in figures)))
        print("%-28s %5s  %s" % ("", "", "  ".join("%-22s" % ("1st %4.1f wall %4.1f" % (figure["from_first"], figure["from_behind"])) for figure in figures)))
    print("uniform_sheet: look at %s; the pictures are in %s and %s" % (sheet.relative_to(ROOT), with_figures.relative_to(ROOT), without.relative_to(ROOT)))


if __name__ == "__main__":
    main()
