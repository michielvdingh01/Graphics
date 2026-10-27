#!/usr/bin/env python3
"""Plays a sound the way the game does, without starting the game.

A take on disk is not what the player hears. The game picks a take at random,
bends its pitch a little and sends it through the World bus, with the reverb
of the space and a clipper, and through the limiter on Master. This renders
that with Godot (tools/render_mix.gd), writes it to .cache/hear/<sound>.wav
and plays it. It plays every sound the way the player's own weapon plays: at
full level and in the middle, not quieter or from a distance as the game
plays a footstep or an enemy's shot, unless --at says from how far.

    tools/hear.py rifle_shot              one shot
    tools/hear.py rifle_shot 620          a second and a half at 620 rounds per minute
    tools/hear.py --quiet smg_shot 900    only writes the file
    tools/hear.py enemy_shot 600 --at=25  the same from 25 m off: quieter, and with what
                                          the distance adds to the reverb
    tools/hear.py rifle_shot --in=room    in another space than the hall of the factory:
                                          hall, room or yard, or a zone of a level,
    tools/hear.py rifle_shot --in=powerhouse/turbine_hall     tuned as the game tunes it
    tools/hear.py reload shotgun          a shot and then the weapon being reloaded,
                                          each step at the moment the game plays it
    tools/hear.py casings rifle           a burst, with the cases landing after it
    tools/hear.py grenade                 the pin, the throw, three bounces and the bang
    tools/hear.py minigun                 the motor coming up to speed, fire until it overheats,
                                          the tail, the steam and the motor running down;
    tools/hear.py minigun b b             the same with variant b of the roar and of the motor
    tools/hear.py rocket                  the rocket launcher firing, the rocket going away and
                                          going off 36 m further on
    tools/hear.py garand                  a whole clip of the M1 Garand, the ping of the clip
                                          flying out, the next clip going in and two more shots;
    tools/hear.py garand b a              the same with variant b of the shot (then of the ping)
    tools/hear.py ambience boiler         twelve seconds of the bed of a kind of space (hall,
                                          room, yard, boiler, turbine), with what sounds in it
                                          now and then and three shots for scale
    tools/hear.py door                    the door of the exit rolling up and its stop
    tools/hear.py whiz                    a robot's burst from 20 m, the rounds going by
    tools/hear.py voice zombie            somebody of that voice seeing the player, being hit
                                          three times and going down: human, zombie, clown, robot
    tools/hear.py music level1and2        the piece at the level of a game, a fight starting
                                          after 4 s and over after 12: its second layer comes
                                          and goes. --layer=<file> tries another file as that layer
    tools/hear.py level_music             where the pieces of a level take turns: the last ten
                                          seconds of each and the first ten of the one after it
    tools/hear.py drive jeep              a ride as its driver hears it, played by the game itself
                                          (tools/hear_drive.gd): get in, start, pull away through
                                          the gears, brake hard to a stop, get out. jeep, truck or tank
    tools/hear.py drive tank crash        flat out into a wall; `wreck` is the engine hit, alight
                                          and going up, `gun` the turret turning and the gun firing
    tools/hear.py drive jeep drive b      the same with variant b of every sound that has one

Only recorded sounds, those with a folder in assets/audio/.
"""
import array
import json
import math
import os
import pathlib
import random
import re
import subprocess
import sys
import wave

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / ".cache/hear"
GODOT = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
START = 0.1  # seconds of silence before the first shot
TAIL = 2.5  # seconds rendered after the last one, for the reverb to die away
FIRE = 1.5  # seconds a burst lasts
SEAM = 10.0  # seconds of music heard on either side of where one piece makes way for the next
SFX = (ROOT / "scripts/sfx.gd").read_text()
MENU = (ROOT / "scripts/menu.gd").read_text()


def constant(name: str, source: str = SFX) -> float:
    """A number the game holds as a constant: what is heard here follows it."""
    return float(re.search(rf"^const {name} := (-?[\d.]+)", source, re.M).group(1))


def pair(name: str) -> tuple:
    found = re.search(rf"^const {name} := Vector2\((-?[\d.]+), (-?[\d.]+)\)", SFX, re.M)
    return float(found.group(1)), float(found.group(2))


SPACES = {
    name: [float(v) for v in row.split(",")]
    for name, row in re.findall(r'&"(\w+)": \[([^\]]+)\]', re.search(r"^const SPACES := \{(.+?)^\}", SFX, re.M | re.S).group(1))
}
BEDS = dict(re.findall(r'"(\w+)": &"(\w+)"', re.search(r"^const BEDS := \{(.+)\}", SFX, re.M).group(1)))
NEAR = constant("NEAR")
# Seconds after the last shot of a clip that its ping is heard.
CLIP_PING = constant("CLIP_PING", (ROOT / "scripts/weapons.gd").read_text())


def enclosed(metres: float) -> list:
    """The reverb of a space with walls and a roof: _enclosed() in scripts/sfx.gd."""
    seconds = constant("DECAY") * metres ** constant("DECAY_POWER")
    room, hall = SPACES["room"], SPACES["hall"]
    size = min(max((10.0 ** (-constant("COMB") / seconds) - 0.7) / 0.28, 0.0), 0.95)
    between = min(max((size - room[0]) / (hall[0] - room[0]), 0.0), 1.0)
    return [size, room[1] + (hall[1] - room[1]) * between, hall[2], hall[3], 0.0, room[5] + (hall[5] - room[5]) * between]


def space(name: str) -> tuple:
    """What `name` sounds like, as (a row of SPACES, the kind of its bed): a
    kind of space, or <level>/<zone>, read from the built level the way
    _survey() in scripts/sfx.gd reads it."""
    if name in SPACES:
        return SPACES[name], name
    if name in BEDS.values():
        return SPACES["hall"], name
    level, _, zone = name.partition("/")
    path = ROOT / "scenes/levels" / f"{level}_level.tscn"
    if not zone or not path.exists():
        raise SystemExit(f"not a space: {name}. One of {', '.join(SPACES)}, or <level>/<zone>")
    zones = {}
    for block in re.split(r"\n(?=\[node )", path.read_text()):
        named = re.search(r'^metadata/zone = "(\w+)"', block, re.M)
        bounds = re.search(r"^metadata/bounds = (.+)$", block, re.M)
        if named and bounds:
            kind = re.search(r'^metadata/space = &"(\w+)"', block, re.M)
            boxes = [[float(v) for v in box.split(",")] for box in re.findall(r"AABB\(([^)]*)\)", bounds.group(1))]
            zones[named.group(1)] = (boxes, kind.group(1) if kind else "")
    if zone not in zones:
        raise SystemExit(f"{level} has no zone {zone}. It has: {', '.join(zones)}")
    boxes, kind = zones[zone]
    slack = constant("BOX_SLACK")
    volume = surface = ground = height = 0.0
    for _, _, _, wide, high, deep in boxes:
        high = max(high - slack, 2.0)
        volume += wide * deep * high
        surface += 2.0 * (wide * deep + (wide + deep) * high)
        ground += wide * deep
        height = max(height, high)
    kind = kind or ("hall" if height >= constant("TALL") else "room")
    bed = next((BEDS[word] for word in BEDS if word in zone), kind)
    if kind == "yard":
        tuning = SPACES["yard"][:]
        tuning[3] = min(max(2000.0 * math.sqrt(ground) / 343.0, 90.0), 260.0)
        return tuning, bed
    return enclosed(volume / surface), bed


def tuned(tuning: list) -> list:
    """The changes to the bus layout that tune both reverbs to a row of SPACES."""
    keys = ("room_size", "damping", "hipass", "predelay_msec", "predelay_feedback", "wet")
    return [dict(zip(keys, tuning), bus=bus, effect=0) for bus in ("World", "Far")]


def far(distance: float) -> float:
    """What a sound from that far off adds to the reverb: _far() in scripts/sfx.gd."""
    if distance <= NEAR:
        return 0.0
    return min(1.0, constant("FAR") / distance) - NEAR / distance


def placed(events: list, distance: float, side: float = 0.0) -> list:
    """The same events as sounds from `distance` metres ahead and `side`
    metres to the right, as play_at() in scripts/sfx.gd places them."""
    out = []
    for event in events:
        at = dict(event, pos=[side, 0.0, -distance], unit_size=NEAR, max_distance=80.0, filter_db=-6.0, max_db=max(3.0, event["db"]))
        out.append(at)
        gain = far(math.hypot(distance, side))
        if gain >= 0.05:
            db = event["db"] + 20.0 * math.log10(gain)
            out.append(dict(at, bus="Far", db=db, max_db=max(3.0, db), attenuation=False, panning=0.5))
    return out


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
    clip = data.get("en_bloc") == "true"
    if clip and (ROOT / "assets/audio" / f"{weapon}_ping").is_dir():
        # The shot is the last of the clip, which flies out with its ping.
        events += played(f"{weapon}_ping", [START + CLIP_PING], -2.0)
    if data.get("loads_singly") == "true":
        events += step("pump", START + 0.14, -7.0)
        shells = int(data.get("mag_size", 6))
        each = time / shells
        for i in range(shells):
            events += step("shell_in", begin + 0.35 + (i + 0.55) * each, -9.0)
        events += step("pump", begin + 0.35 + time + 0.3, -6.0)
    else:
        for name, moment in (("mag_out", 0.14), ("mag_in", 0.72), ("bolt", 0.88)):
            # A clip is not taken out: it flew out with the last round.
            if not (clip and name == "mag_out"):
                events += step(name, begin + moment * time, -9.0)
    return events


def garand(shot: str, ping: str) -> list:
    """The M1 Garand as scripts/weapons.gd plays it: a whole clip of eight
    fired at a steady pace, the clip flying out with its ping just after the
    last bang, the next clip pressed in and the bolt slamming home, and two
    more shots."""
    data = dict(re.findall(r"^(\w+) = (.+)$", (ROOT / "weapons/garand.tres").read_text(), re.M))
    rounds = int(data.get("mag_size", 8))
    time = float(data.get("reload_time", 2.0))
    pace = max(60.0 / float(data.get("rounds_per_minute", 300.0)), 0.32)
    times = [START + i * pace for i in range(rounds)]
    events = played(shot, times)
    events += played(ping, [times[-1] + CLIP_PING], -2.0)
    begin = times[-1] + 0.7
    events += played("garand_mag_in", [begin + 0.72 * time], -9.0) + played("garand_bolt", [begin + 0.88 * time], -9.0)
    after = begin + time + 0.35
    return events + played(shot, [after, after + pace])


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


def minigun(fire: str, spin: str) -> list:
    """The minigun as scripts/weapons.gd plays it, with the numbers of
    weapons/minigun.tres: its motor coming up to speed, firing until it
    overheats, letting go, and the motor running down. The motor and the roar
    are takes that go round; the game raises the pitch of the motor with the
    speed of the barrels, which is played here in short steps."""
    data = dict(re.findall(r"^(\w+) = (.+)$", (ROOT / "weapons/minigun.tres").read_text(), re.M))
    up = float(data.get("spin_up", 0.75))
    down = float(data.get("spin_down", 1.0))
    firing = float(data.get("overheat_after", 4.0))

    def going_round(sound: str, start: float, until: float, db: float, pitch: float = 1.0) -> list:
        take = sorted((ROOT / "assets/audio" / sound).glob("*.wav"))[0]
        with wave.open(str(take)) as opened:
            length = opened.getnframes() / opened.getframerate() / pitch
        events = []
        at = start
        while at < until:
            events.append({"t": at, "file": str(take), "bus": "World", "db": db, "pitch": pitch, "until": min(at + length, until), "fade": 0.02})
            at += length
        return events

    def motor(start: float, seconds: float, rising: bool) -> list:
        steps = 8
        events = []
        for i in range(steps):
            speed = (i + 0.5) / steps if rising else 1.0 - (i + 0.5) / steps
            at = start + seconds * i / steps
            events += going_round(spin, at, at + seconds / steps + 0.02, -16.0 + 12.0 * speed, 0.45 + 0.55 * speed)
        return events

    begin = START + up
    end = begin + firing
    events = motor(START, up, True)
    events += going_round(spin, begin, end, -4.0)
    events += going_round(fire, begin, end, 0.0)
    events += played("minigun_tail", [end], -1.0) + played("minigun_overheat", [end], -2.0)
    return events + motor(end, down, False)


def rocket() -> list:
    """The rocket launcher: the launch at full level, the roar of the rocket
    as it goes, fading over the 0.8 s it takes to fly 36 m at 45 m/s, and the
    blast there, from that far off."""
    flight = sorted((ROOT / "assets/audio/rocket_flight").glob("*.wav"))[0]
    events = played("rocket_launch", [START])
    events.append({"t": START + 0.05, "file": str(flight), "bus": "World", "db": -6.0, "until": START + 0.8, "fade": 0.5})
    return events + placed(played("explosion", [START + 0.8]), 36.0)


def burst(sound: str, rate: float, db: float = 0.0, start: float = START) -> list:
    shots = max(1, int(FIRE * rate / 60.0)) if rate else 1
    return played(sound, [start + i * 60.0 / rate if rate else start for i in range(shots)], db)


def ambience(kind: str) -> list:
    """Twelve seconds in a kind of space: its bed going round, what sounds
    in it now and then from where the game would have it, and three shots of
    the player's own rifle to hear it against."""
    folder = ROOT / "assets/audio" / f"ambience_{kind}"
    bed = sorted(folder.glob("*.wav")) + sorted(folder.glob("*.ogg"))
    if not bed:
        raise SystemExit(f"no bed in assets/audio/ambience_{kind}/")
    take = bed[0]
    if take.suffix == ".ogg":
        # The renderer plays WAVs: unpack it, with the tool that came with
        # the encoder.
        OUT.mkdir(parents=True, exist_ok=True)
        take = OUT / f"ambience_{kind}.bed.wav"
        subprocess.run(["oggdec", "-Q", "-o", str(take), str(bed[0])], check=True)
    with wave.open(str(take)) as reader:
        length = reader.getnframes() / reader.getframerate()
    begin = random.uniform(0.0, max(length - 12.0, 0.0))
    events = [{"t": 0.0, "file": str(take), "bus": "Ambience", "db": 0.0, "pitch": 1.0, "from": begin}]
    if (ROOT / "assets/audio" / f"ambience_{kind}_spot").is_dir():
        reach = pair("SPOT_REACH")
        for at in (2.0, 9.5):
            turn = random.uniform(0.0, math.tau)
            off = random.uniform(*reach)
            events += placed(played(f"ambience_{kind}_spot", [at], constant("SPOT_DB")), off * math.cos(turn), off * math.sin(turn))
    return events + played("rifle_shot", [5.0, 5.6, 6.2])


def door() -> list:
    """The door of the exit, 6 m off: its own sound for as long as it takes
    to go up and the clang the game plays when it is there. The times are
    those of scripts/game.gd."""
    game = (ROOT / "scripts/game.gd").read_text()
    up = constant("DOOR_TIME", game)
    events = placed(played("roller_door", [START]), 6.0)
    for event in events:
        event["until"] = START + up
        event["fade"] = constant("DOOR_STOP")
    return events + placed(played("clang", [START + up], -2.0), 6.0)


def whiz() -> list:
    """Two bursts of a robot 20 m off that miss: its shots, and every round
    going by, to the left and to the right."""
    times = [START + burst * 1.4 + shot * 0.11 for burst in range(2) for shot in range(4)]
    events = placed(played("enemy_shot", times), 20.0)
    reach = constant("PASS_REACH")
    for at in times:
        miss = random.uniform(0.3, reach)
        side = miss * random.choice((-1.0, 1.0))
        events += placed(played("whiz", [at], -9.0 * miss / reach), 0.0, side)
    return events


def voice(who: str) -> list:
    """Somebody 6 m off who sees the player, is hit three times and goes
    down: what each of those is called and how loud is as scripts/enemy.gd
    and scripts/humanoid_rig.gd play them. A robot says what it is about to
    do instead: it charges, calls out that it goes round, and sounds its alarm."""
    if who == "robot":
        said = [("enemy_alert", 0.0, 0.0), ("enemy_charge", 1.2, -3.0), ("heavy_charge", 2.2, -3.0), ("rusher_charge", 3.6, -3.0),
                ("enemy_flank", 4.6, 0.0), ("enemy_alarm", 5.6, 0.0), ("enemy_death", 6.8, 0.0)]
    else:
        said = [(f"{who}_alert", 0.0, 0.0), (f"{who}_hurt", 1.6, -4.0), (f"{who}_hurt", 2.3, -4.0), (f"{who}_hurt", 3.0, -4.0), (f"{who}_death", 3.9, 0.0)]
        if (ROOT / "assets/audio" / f"{who}_panic").is_dir():
            said.append((f"{who}_panic", 6.2, constant("SCREAM_DB", (ROOT / "scripts/humanoid_rig.gd").read_text())))
    events = []
    for sound, at, db in said:
        if not (ROOT / "assets/audio" / sound).is_dir():
            print(f"{sound}: no recording yet, left out")
            continue
        events += placed(played(sound, [START + at], db), 6.0)
    if not events:
        raise SystemExit(f"no recorded voice named {who}")
    return events


def music(piece: str, layer: str) -> list:
    """Twenty seconds of a piece at the level the game plays it in a level,
    with a fight from 4 s to 12 s: the second layer comes in and goes as
    scripts/sfx.gd has it, and the rifle fires to hear it against."""
    db = constant("LEVEL_MUSIC_DB", MENU)
    rise, fall = constant("FIGHT_RISE"), constant("FIGHT_FALL")
    over = pathlib.Path(layer) if layer else found(piece + re.search(r'^const FIGHT_LAYER := "(\w+)"', SFX, re.M).group(1))

    def heat(at: float) -> float:
        return min(max((at - 4.0) / rise, 0.0), 1.0) if at < 12.0 else max(1.0 - (at - 12.0) / fall, 0.0)

    events = [
        {"t": 0.0, "file": excerpt(found(piece), 20.0, lambda at: 1.0), "bus": "Music", "db": db, "pitch": 1.0},
        {"t": 0.0, "file": excerpt(over, 20.0, lambda at: max(heat(at), 0.001)), "bus": "Music", "db": db, "pitch": 1.0},
    ]
    return events + burst("rifle_shot", 620.0, 0.0, 6.0) + burst("rifle_shot", 620.0, 0.0, 9.0)


def level_music() -> tuple:
    """Where the pieces of a level take turns, as scripts/sfx.gd plays them:
    for each piece of LEVEL_MUSIC in scripts/menu.gd its last SEAM seconds
    and straight after them the first SEAM of the next, at the level of a
    game, with a moment of silence before the next seam."""
    pieces = re.findall(r'&"([^"]+)"', re.search(r"^const LEVEL_MUSIC: .*$", MENU, re.M).group(0))
    db = constant("LEVEL_MUSIC_DB", MENU)
    events, at = [], START
    for i, piece in enumerate(pieces):
        after = pieces[(i + 1) % len(pieces)]
        print(f"{at:4.0f} s  the end of {piece}, into {after}")
        for t, name, start in ((at, piece, -SEAM), (at + SEAM, after, 0.0)):
            events.append({"t": t, "file": excerpt(found(name), SEAM, lambda _: 1.0, start), "bus": "Music", "db": db, "pitch": 1.0})
        at += 2 * SEAM + 2.0
    return events, at - 2.0


def found(name: str) -> pathlib.Path:
    """The file of the piece of that name in assets/music/."""
    for kind in (".ogg", ".mp3"):
        if (ROOT / "assets/music" / (name + kind)).exists():
            return ROOT / "assets/music" / (name + kind)
    raise SystemExit(f"no piece named {name} in assets/music/")


def excerpt(source: pathlib.Path, seconds: float, level, start: float = 0.0) -> str:
    """`seconds` of a piece as a WAV, from `start` seconds in, or from that
    far before its end if it is below nought, as loud at each moment as
    `level` says: the renderer plays a file at one level from start to end."""
    OUT.mkdir(parents=True, exist_ok=True)
    whole = OUT / f"{source.stem}.whole.wav"
    subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16@44100", "-c", "2", str(source), str(whole)], check=True)
    with wave.open(str(whole)) as reader:
        reader.setpos(max(reader.getnframes() + int(start * 44100), 0) if start < 0.0 else int(start * 44100))
        frames = array.array("h", reader.readframes(int(seconds * 44100)))
    whole.unlink()
    for i in range(0, len(frames), 2):
        gain = level(i / 2 / 44100.0)
        frames[i] = int(frames[i] * gain)
        frames[i + 1] = int(frames[i + 1] * gain)
    out = OUT / f"{source.stem}.{'excerpt' if start == 0.0 else f'from{start:+.0f}'}.wav"
    with wave.open(str(out), "wb") as writer:
        writer.setnchannels(2)
        writer.setsampwidth(2)
        writer.setframerate(44100)
        writer.writeframes(frames.tobytes())
    return str(out)


def mixed(name: str, events: list, tuning: list = None, length: float = 0.0) -> pathlib.Path:
    events.sort(key=lambda event: event["t"])
    OUT.mkdir(parents=True, exist_ok=True)
    spec = OUT / f"{name}.json"
    out = OUT / f"{name}.wav"
    spec.write_text(json.dumps({
        "layout": str(ROOT / "default_bus_layout.tres"),
        "set": tuned(tuning) if tuning else [],
        "length": length or events[-1]["t"] + TAIL,
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


def drive(kind: str, ride: str, variant: str) -> pathlib.Path:
    """A ride recorded from the game as it plays it: see tools/hear_drive.gd.
    It runs the game's own project, with a home of its own, so that nothing
    of whoever plays here is read or written."""
    OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / f"drive_{kind}_{ride}_{variant}.wav"
    home = ROOT / ".godot/vehicles_home"
    home.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        [GODOT, "--headless", "--path", str(ROOT), "--log-file", str(OUT / "godot.log"), "--script", "res://tools/hear_drive.gd", "--", kind, ride, variant, str(out)],
        env=dict(os.environ, HOME=str(home)), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True,
    )
    if result.returncode != 0 or not out.exists():
        raise SystemExit(result.stdout)
    for line in result.stdout.splitlines():
        if line.startswith("  ") and " s  " in line:
            print(line)
    return out


def main() -> None:
    args = [arg for arg in sys.argv[1:] if not arg.startswith("--")]
    options = dict(arg[2:].partition("=")[::2] for arg in sys.argv[1:] if arg.startswith("--"))
    unknown = set(options) - {"quiet", "at", "in", "layer"}
    if not args or unknown:
        raise SystemExit(__doc__)
    tuning, bed = space(options["in"]) if "in" in options else (None, "")
    distance = float(options.get("at", 0.0))
    length = 0.0
    if args[0] == "reload":
        if len(args) < 2:
            raise SystemExit("say which weapon: tools/hear.py reload shotgun")
        name, events = f"reload_{args[1]}", reload(args[1])
    elif args[0] == "casings" and len(args) > 1:
        name, events = f"casings_{args[1]}", casings(args[1])
    elif args[0] == "grenade":
        name, events = "grenade", grenade()
    elif args[0] == "rocket":
        name, events = "rocket", rocket()
    elif args[0] == "garand":
        shot = "garand_shot" + (f"_{args[1]}" if len(args) > 1 and args[1] != "a" else "")
        ping = "garand_ping" + (f"_{args[2]}" if len(args) > 2 and args[2] != "a" else "")
        name, events = f"garand_{'_'.join(args[1:]) or 'a'}", garand(shot, ping)
    elif args[0] == "minigun":
        fire = "minigun_fire" + (f"_{args[1]}" if len(args) > 1 and args[1] != "a" else "")
        spin = "minigun_spin" + (f"_{args[2]}" if len(args) > 2 and args[2] != "a" else "")
        name, events = f"minigun_{'_'.join(args[1:]) or 'a'}", minigun(fire, spin)
    elif args[0] == "ambience":
        kind = args[1] if len(args) > 1 else bed
        if "in" not in options:
            tuning = space(kind)[0]
        name, events, length = f"ambience_{kind}", ambience(kind), 12.0
    elif args[0] == "door":
        name, events = "door", door()
    elif args[0] == "whiz":
        name, events = "whiz", whiz()
    elif args[0] == "voice" and len(args) > 1:
        name, events = f"voice_{args[1]}", voice(args[1])
    elif args[0] == "level_music":
        name = "level_music"
        events, length = level_music()
    elif args[0] == "drive" and len(args) > 1:
        out = drive(args[1], args[2] if len(args) > 2 else "drive", args[3] if len(args) > 3 else "a")
        print(out.relative_to(ROOT))
        if "quiet" not in options:
            subprocess.run(["afplay", str(out)], check=True)
        return
    elif args[0] == "music" and len(args) > 1:
        name, events, length = f"music_{args[1]}", music(args[1], options.get("layer", "")), 20.0
    else:
        name, events = args[0], burst(args[0], float(args[1]) if len(args) > 1 else 0.0)
    if distance:
        events = placed(events, distance)
    out = mixed(name, events, tuning, length)
    print(out.relative_to(ROOT))
    if "quiet" not in options:
        subprocess.run(["afplay", str(out)], check=True)


if __name__ == "__main__":
    main()
