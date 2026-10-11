#!/usr/bin/env python3
"""Cuts and mixes the sound samples listed in assets/manifest.json (type "sound").

A sound names where it comes from, a pack under "packs" in the manifest or
"recording" for a file of our own in assets/recordings/, and the file or files
to cut its takes from. The takes land in assets/audio/<id>/ as <id>_1.wav,
<id>_2.wav and so on: 16-bit, 44.1 kHz, starting where the sound starts, faded
at the end and all brought to the same peak. scripts/sfx.gd plays whatever is
there, so a new take needs no code.

    tools/build_sounds.py            builds every sound that has no takes yet
    tools/build_sounds.py id ...     rebuilds these
    tools/build_sounds.py --all      rebuilds all of them

What an entry can say besides its source:
    files   a path inside the pack or the recordings folder, or a list of
            them; * matches
    split   the file holds several takes with silence between them
    gap     seconds of silence that separate two of them, 0.3 without it:
            less for a file in which one thing follows close on another
    pick    which of the takes found to keep, counted from 1 in the order
            they were found: for a file that holds different things
    trim    [from, to]: only that part of a take, in seconds from its start:
            a moment out of something that goes on
    pitch   play a take this many times as fast, and so higher and shorter;
            under 1 it is lower and longer, as of something bigger
    glide   [from, to]: the same, changing from the one speed to the other
            over the take. Falling, it is something that comes past; rising,
            something that winds up
    reverse play a take backwards: what died away now swells
    ring    [Hz, depth 0..1]: multiply a take by a tone of that pitch, which
            takes the throat out of a voice and leaves a machine
    comb    [ms, feedback 0..1]: let a take ring in a pipe that long, for a
            voice that comes out of a tin
    scatter [seconds, least, most, lowest dB]: instead of the recordings
            themselves, takes that are that long and made of them, one after
            another with between `least` and `most` seconds from the start of
            the one to the start of the next, each between `lowest` and 0 dB:
            a rattle out of single knocks
    attack  seconds over which a take comes in
    tight   begin a take at its bang, not where it rises out of the noise:
            for a shot, which otherwise comes late by however long the
            mechanism rattles before it
    takes   how many to make. Without it, as many as were found; fewer keeps
            the first ones. More repeats the recordings over other takes of
            their layers, which only differ in the low end: of use where
            there are layers and next to no recordings
    length  cut a take off after this many seconds
    stereo  keep both channels; without it a take is the left channel only,
            because the two microphones of a recording are not in step and
            lose level when summed
    punch   push the first instants of a take this many times harder into a
            soft clip. A recorded shot is one spike with next to nothing
            after it; this gives it the body a shot has in a game, and leaves
            the tail as it was
    drive   the same for the whole take: denser and so louder throughout
    layers  what is mixed under the recording to give it weight, each an
            object. It names a recording with source, files, split and tight
            like the sound itself, of which the left channel is used, or it
            has "sweep": [from Hz, to Hz, seconds] for a sine that drops in
            pitch, the thump under a shot, or "rumble": [seconds, from Hz,
            to Hz] for noise that dies away over that long while its treble
            goes first, the way a bang rolls on over open ground. A rumble
            is different left and right and in every take. "air": [seconds,
            Hz] is noise that does not die away, with nothing above that
            pitch: the air in a room, and with a highpass steam. A third
            number, up to 1, lets it come and go in gusts: wind; "hum":
            [seconds, Hz, Hz ...] is those tones together, each drifting a
            little, for what turns or runs on the mains. Or it has
            "burst": [seconds, from Hz, to Hz, fall]: noise that is there at
            once and white, and turns brown within `fall` seconds as it dies
            away, which is what a shot does that lands in something soft
            and wet. An echo needs
            nothing new: it is the recording again as a layer, later,
            quieter and duller. A layer can say lowpass and highpass
            (Hz, 24 dB per octave), length (seconds), gain (dB against the
            recording, each at full scale), delay (ms after the recording
            starts) and invert. Those last two decide whether the bass of a
            layer adds to that of the recording or cancels it, so measure
            before changing them
    eq      filters over the mix, each [kind, Hz, dB]: "low" and "high" are
            shelves, "bell" a peak an octave and a half wide
    glue    [drive, punch] of one more soft clip, over the mix: what makes
            the layers one sound
    bed     seconds: the sound is not something that happens but what a space
            sounds like, and comes out as one take of that length that goes
            round without a seam. The recording and every layer is repeated
            to fill it, each crossfaded into itself; recordings of different
            lengths then never meet the same way twice. A layer with "once"
            is not repeated. It is written in stereo, a recording running
            ahead on the right of where it is on the left, which the ear
            takes for width
    rate    the sample rate the takes are written at, 22050 for half the
            size: for a sound with nothing in it above 10 kHz
    ogg     write the takes as Ogg Vorbis of this quality, 0 to 10, a tenth
            of the size at 3: for a bed, which is long and has no edge that
            the coding could blur. Needs oggenc (brew install vorbis-tools)
    rms     how loud the take is to be, in dB below full scale averaged over
            its length, instead of with its peak at full scale: a bed is as
            loud in its file as it is in the game

A pack is downloaded once into .cache/sounds/ and checked against the checksum
in the manifest; only the files a sound names are unpacked. A pack may also be
one sound file instead of an archive. Needs macOS
(afconvert, bsdtar) and Godot for reading Ogg files.
"""
import array
import hashlib
import json
import math
import os
import pathlib
import random
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request
import wave

ROOT = pathlib.Path(__file__).resolve().parent.parent
CACHE = ROOT / ".cache/sounds"
OUT = ROOT / "assets/audio"
RECORDINGS = ROOT / "assets/recordings"
GODOT = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
OGGENC = os.environ.get("OGGENC", "oggenc")
HEADERS = {"User-Agent": "GraphicsFPS-asset-fetch/0.1"}

RATE = 44100
PEAK = 29000  # what the synthesised placeholders in scripts/sfx.gd peak at
BLOCK = RATE // 500  # the loudness of a file is followed in steps of 2 ms
GAP = 0.3  # seconds of quiet that separate two takes
LEAD = int(0.002 * RATE)  # kept before the start of a take
FADE = 0.25  # seconds over which a take that was cut off dies away
PUNCH = 0.04  # seconds over which the push of "punch" wears off
BUTTERWORTH = (0.5412, 1.3066)  # the two stages of a 24 dB per octave filter
SEAM = 0.5  # seconds over which a loop is crossfaded into itself, at most
WIDE = 0.37  # how far round its loop the right channel of a bed runs ahead


def unpack(name: str, pack: dict, wanted: str) -> pathlib.Path:
    """The folder a pack is unpacked in, with the files that match `wanted` in
    it: the pack is downloaded if need be, and only those are unpacked. A
    pack that is offered as loose files names them all, "url" and "sha256"
    each a list."""
    folder = CACHE / name
    files = folder / "files"
    if any(files.glob(wanted)):
        return files
    urls = pack["url"] if isinstance(pack["url"], list) else [pack["url"]]
    sums = pack["sha256"] if isinstance(pack["sha256"], list) else [pack["sha256"]]
    for url, checksum in zip(urls, sums):
        archive = folder / urllib.parse.unquote(url.rsplit("/", 1)[1])
        if not archive.exists():
            folder.mkdir(parents=True, exist_ok=True)
            print(f"downloading {archive.name}")
            partial = archive.with_name(archive.name + ".part")
            with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS)) as response:
                with open(partial, "wb") as out:
                    shutil.copyfileobj(response, out)
            partial.rename(archive)
        digest = hashlib.sha256()
        with open(archive, "rb") as data:
            for chunk in iter(lambda: data.read(1 << 20), b""):
                digest.update(chunk)
        if digest.hexdigest() != checksum:
            raise SystemExit(f"checksum mismatch for {archive}")
        if archive.suffix.lower() in (".wav", ".ogg", ".mp3", ".flac"):
            files.mkdir(parents=True, exist_ok=True)
            shutil.copy(archive, files / archive.name)
            continue
        # bsdtar reads both zip and 7z, and refuses to write outside the folder.
        with tempfile.TemporaryDirectory(dir=folder) as partial:
            subprocess.run(["bsdtar", "-xf", str(archive), "-C", partial, wanted], check=True)
            # Some archives hold read-only folders, which could then never be removed.
            subprocess.run(["chmod", "-R", "u+rwX", partial], check=True)
            shutil.copytree(partial, files, dirs_exist_ok=True)
    return files


def load(sources: list, scratch: pathlib.Path) -> list:
    """Each file as its channels, 16-bit samples at RATE."""
    scratch = pathlib.Path(tempfile.mkdtemp(dir=scratch))
    decoded = {}
    for i, source in enumerate(sources):
        if source.suffix.lower() == ".ogg":
            decoded[i] = scratch / f"{i}.ogg.wav"
    if decoded:
        pairs = [str(path) for i, target in decoded.items() for path in (sources[i], target)]
        # Run from the scratch folder, so Godot does not load the project.
        subprocess.run(
            [GODOT, "--headless", "--script", str(ROOT / "tools/decode_ogg.gd"), "--", *pairs],
            check=True, cwd=scratch, stdout=subprocess.DEVNULL,
        )
    result = []
    for i, source in enumerate(sources):
        target = scratch / f"{i}.wav"
        subprocess.run(["afconvert", "-f", "WAVE", "-d", f"LEI16@{RATE}", str(decoded.get(i, source)), str(target)], check=True)
        result.append(read_wav(target))
    return result


def read_wav(path: pathlib.Path) -> list:
    """The channels of a 16-bit WAV file. Not read with the wave module: for a
    source that names its speakers, such as an .m4a, afconvert writes the
    extended kind of header, which that module refuses."""
    data = path.read_bytes()
    channels, pcm = 1, b""
    at = 12
    while at + 8 <= len(data):
        size = int.from_bytes(data[at + 4:at + 8], "little")
        body = data[at + 8:at + 8 + size]
        if data[at:at + 4] == b"fmt ":
            channels = int.from_bytes(body[2:4], "little")
        elif data[at:at + 4] == b"data":
            pcm = body
        at += 8 + size + size % 2
    samples = array.array("h")
    samples.frombytes(pcm[:len(pcm) - len(pcm) % (2 * channels)])
    return [samples[c::channels] for c in range(channels)]


def spans(channel: array.array, split: bool, apart: float = GAP) -> list:
    """Where the takes are in a channel, as (first sample, one past the last)."""
    levels = [max(max(channel[i:i + BLOCK]), -min(channel[i:i + BLOCK])) for i in range(0, len(channel), BLOCK)]
    peak = max(levels)
    if peak == 0:
        return []
    if split:
        # A take stands out from the noise between takes: it starts on rising
        # well above it and is over once it has sunk back into it.
        noise = sorted(levels)[len(levels) // 10]
        off = min(max(noise * 2.0, peak * 0.003), peak * 0.1)
        on = max(off * 4.0, peak * 0.1)
    else:
        off = on = peak * 0.003
    gap = int(apart * RATE / BLOCK)
    found = []
    start = None
    quiet = 0
    for i, level in enumerate(levels):
        if start is None:
            if level >= on:
                start = i
                while start > 0 and levels[start - 1] > off:
                    start -= 1
                quiet = 0
        else:
            quiet = quiet + 1 if level < off else 0
            if quiet >= gap:
                found.append((start, i + 1 - quiet))
                start = None
    if start is not None:
        found.append((start, len(levels) - quiet))
    if found and not split:
        found = [(found[0][0], found[-1][1])]
    return [(max(0, a * BLOCK - LEAD), min(len(channel), b * BLOCK)) for a, b in found]


def excerpts(spec: dict, packs: dict, scratch: pathlib.Path, stereo: bool) -> list:
    """The takes a sound or a layer names, each as its channels."""
    if "sweep" in spec:
        return [[sweep(*spec["sweep"])]]
    if "rumble" in spec:
        return [rumble(*spec["rumble"], seed) for seed in range(4)]
    if "air" in spec:
        return [air(*spec["air"], seed=seed) for seed in range(4)]
    if "hum" in spec:
        return [hum(spec["hum"][0], spec["hum"][1:], seed) for seed in range(4)]
    if "burst" in spec:
        return [[burst(*spec["burst"], seed)] for seed in range(5)]
    source = spec["source"]
    patterns = spec["files"] if isinstance(spec["files"], list) else [spec["files"]]
    sources = []
    for pattern in patterns:
        folder = RECORDINGS if source == "recording" else unpack(source, packs[source], pattern)
        found = sorted(folder.glob(pattern))
        if not found:
            raise SystemExit(f"nothing matches {pattern} in {folder}")
        sources += found
    takes = []
    for channels in load(sources, scratch):
        if not stereo:
            channels = channels[:1]
        for first, last in spans(channels[0], spec.get("split", False), spec.get("gap", GAP)):
            takes.append([[float(sample) for sample in channel[first:last]] for channel in channels])
    if "pick" in spec:
        if max(spec["pick"]) > len(takes):
            raise SystemExit(f"{spec['files']} holds {len(takes)} takes, not the {max(spec['pick'])} that are picked from")
        takes = [takes[number - 1] for number in spec["pick"]]
    if not takes:
        raise SystemExit(f"found no sound in {spec['files']}")
    if "trim" in spec:
        first, last = (int(seconds * RATE) for seconds in spec["trim"])
        takes = [[channel[first:last] for channel in take] for take in takes]
    if "pitch" in spec:
        takes = [[pitched(channel, spec["pitch"]) for channel in take] for take in takes]
    if "glide" in spec:
        takes = [[glided(channel, *spec["glide"]) for channel in take] for take in takes]
    if spec.get("reverse"):
        takes = [[channel[::-1] for channel in take] for take in takes]
    if "ring" in spec:
        takes = [[rung(channel, *spec["ring"]) for channel in take] for take in takes]
    if "comb" in spec:
        takes = [[combed(channel, *spec["comb"]) for channel in take] for take in takes]
    if "scatter" in spec:
        takes = [scattered(takes, *spec["scatter"], seed) for seed in range(4)]
    if "attack" in spec:
        rise = int(spec["attack"] * RATE)
        takes = [[[sample * min(1.0, i / rise) for i, sample in enumerate(channel)] for channel in take] for take in takes]
    return takes


def glided(samples: list, start: float, end: float) -> list:
    """A channel played `start` times as fast at first and `end` times at last."""
    last = len(samples) - 1
    count = int(last / ((start + end) / 2.0))
    out = []
    at = 0.0
    for i in range(count):
        whole = int(at)
        if whole >= last:
            break
        out.append(samples[whole] + (samples[whole + 1] - samples[whole]) * (at - whole))
        at += start + (end - start) * i / count
    return out


def rung(samples: list, hz: float, depth: float = 1.0) -> list:
    """A channel multiplied by a tone."""
    turn = math.tau * hz / RATE
    return [sample * (1.0 - depth + depth * math.sin(turn * i)) for i, sample in enumerate(samples)]


def combed(samples: list, ms: float, feedback: float) -> list:
    """A channel ringing in a pipe: each sample comes back `ms` later."""
    back = max(1, int(ms / 1000.0 * RATE))
    out = samples + [0.0] * int(back * math.log(0.01) / math.log(max(feedback, 0.01)))
    for i in range(back, len(out)):
        out[i] += feedback * out[i - back]
    return out


def scattered(takes: list, seconds: float, least: float, most: float, lowest: float, seed: int) -> list:
    """A take of `seconds` made of `takes`, one after another."""
    chance = random.Random(seed)
    out = [[0.0] * int(seconds * RATE) for _ in takes[0]]
    at = 0.0
    before = -1
    while at < seconds:
        pick = chance.randrange(len(takes))
        if pick == before and len(takes) > 1:
            pick = (pick + 1) % len(takes)
        before = pick
        gain = 10.0 ** (chance.uniform(lowest, 0.0) / 20.0) / top(takes[pick])
        first = int(at * RATE)
        for channel, source in zip(out, takes[pick]):
            for i, sample in enumerate(source[:len(channel) - first]):
                channel[first + i] += sample * gain
        at += chance.uniform(least, most)
    return out


def air(seconds: float, pitch: float, sway: float = 0.0, seed: int = 0) -> list:
    """Noise in two channels that goes on as it began, with nothing in it
    above `pitch`. With `sway` it comes and goes: louder and brighter in a
    gust, both sides together, and back where it began at the end."""
    count = int(seconds * RATE)
    chance = random.Random(1000 + seed)
    # Whole turns over the length, so that the end runs on into the start.
    gusts = [(turns, chance.uniform(0.0, math.tau)) for turns in (1, 2, 3, 5)]
    out = []
    for side in range(2):
        noise = random.Random(1000 + seed * 2 + side)
        one = two = 0.0
        channel = []
        for i in range(count):
            blow = sum(math.sin(math.tau * turns * i / count + lean) / (n + 1) for n, (turns, lean) in enumerate(gusts)) / 2.08
            pull = 1.0 - math.exp(-math.tau * pitch * (1.0 + 0.6 * sway * blow) / RATE)
            one += pull * (noise.uniform(-1.0, 1.0) - one)
            two += pull * (one - two)
            channel.append(two * (1.0 + sway * blow))
        out.append(channel)
    return out


def hum(seconds: float, pitches: list, seed: int) -> list:
    """Tones together in two channels, the first loudest, each wandering a
    little in pitch and in level so that it is a machine and not a tuning fork."""
    count = int(seconds * RATE)
    chance = random.Random(2000 + seed)
    out = [[0.0] * count for _ in range(2)]
    for n, pitch in enumerate(pitches):
        for channel in out:
            phase = chance.uniform(0.0, math.tau)
            drift = chance.uniform(0.07, 0.19)
            swell = chance.uniform(0.11, 0.31)
            lean = chance.uniform(0.0, math.tau)
            turn = math.tau * pitch / RATE
            for i in range(count):
                t = i / RATE
                phase += turn * (1.0 + 0.003 * math.sin(math.tau * drift * t + lean))
                channel[i] += math.sin(phase) * (0.75 + 0.25 * math.sin(math.tau * swell * t + lean)) / (n + 1)
    return out


def seamless(channel: list, seam: int) -> list:
    """A channel that goes round: its last `seam` samples are taken off and
    faded into its first, so that its end runs on into its start."""
    kept = len(channel) - seam
    out = channel[:kept]
    for i in range(seam):
        turn = 0.5 * math.pi * i / seam
        out[i] = channel[i] * math.sin(turn) + channel[kept + i] * math.cos(turn)
    return out


def tiled(take: list, count: int, wide: bool) -> list:
    """A take repeated to `count` samples in two channels, crossfaded into
    itself at every round. If it is to be `wide`, the right runs ahead of the
    left: two microphones on one machine hear nearly the same, and the same
    on both sides is a sound in the middle of the head."""
    seam = min(int(SEAM * RATE), len(take[0]) // 4)
    out = []
    for side in range(2):
        loop = seamless(take[min(side, len(take) - 1)], seam)
        ahead = int(WIDE * len(loop)) if side and wide else 0
        out.append([loop[(ahead + i) % len(loop)] for i in range(count)])
    return out


def made(spec: dict) -> bool:
    """True for what is generated here instead of recorded."""
    return any(kind in spec for kind in ("sweep", "rumble", "air", "hum", "burst"))


def pitched(samples: list, speed: float) -> list:
    """A channel played `speed` times as fast."""
    last = len(samples) - 1
    out = []
    for i in range(int(last / speed)):
        at = i * speed
        whole = int(at)
        out.append(samples[whole] + (samples[min(whole + 1, last)] - samples[whole]) * (at - whole))
    return out


def sweep(start: float, end: float, seconds: float) -> list:
    """A sine that drops from one pitch to another while it dies away."""
    count = int(seconds * RATE)
    attack, release = 0.002 * RATE, 0.2 * count
    phase = 0.0
    out = []
    for i in range(count):
        phase += math.tau * (end + (start - end) * math.exp(-i / (count / 5.0))) / RATE
        level = math.exp(-i / (count / 3.0)) * min(1.0, (count - i) / release)
        if i < attack:
            level *= 0.5 - 0.5 * math.cos(math.pi * i / attack)
        out.append(math.sin(phase) * level)
    return out


def rumble(seconds: float, start: float, end: float, seed: int) -> list:
    """Noise in two channels that dies away by 60 dB over `seconds`, low-passed
    at a pitch that falls from `start` to `end` as it does."""
    count = int(seconds * RATE)
    attack, release = 0.03 * RATE, 0.15 * count
    out = []
    for side in range(2):
        noise = random.Random(seed * 2 + side)
        one = two = 0.0
        channel = []
        for i in range(count):
            pitch = end + (start - end) * math.exp(-i / (count / 5.0))
            pull = 1.0 - math.exp(-math.tau * pitch / RATE)
            one += pull * (noise.uniform(-1.0, 1.0) - one)
            two += pull * (one - two)
            level = math.exp(-6.9 * i / count) * min(1.0, (count - i) / release)
            if i < attack:
                level *= 0.5 - 0.5 * math.cos(math.pi * i / attack)
            channel.append(two * level)
        out.append(channel)
    return out


def burst(seconds: float, start: float, end: float, fall: float, seed: int) -> list:
    """Noise that begins at once and white and dies away by 60 dB over
    `seconds`, while a low-pass of 6 dB per octave comes down over it from
    `start` to `end` within `fall` seconds: what is left then is brown. A
    low-pass takes level away with the treble; most of that is given back,
    or the brown end would be a whisper after the white."""
    count = int(seconds * RATE)
    attack, release = 0.001 * RATE, 0.15 * count
    noise = random.Random(1000 + seed)
    low = 0.0
    out = []
    for i in range(count):
        pitch = end + (start - end) * math.exp(-3.0 * i / (fall * RATE))
        pull = 1.0 - math.exp(-math.tau * pitch / RATE)
        low += pull * (noise.uniform(-1.0, 1.0) - low)
        level = math.exp(-6.9 * i / count) * min(1.0, i / attack, (count - i) / release)
        out.append(low * level * (pull / (2.0 - pull)) ** -0.45)
    return out


def biquad(kind: str, hz: float, db: float = 0.0, q: float = 0.7071) -> tuple:
    """One filter stage, after the Audio EQ Cookbook: b0, b1, b2, a1, a2."""
    turn = math.tau * hz / RATE
    cos, sin = math.cos(turn), math.sin(turn)
    alpha = sin / (2.0 * q)
    amp = 10.0 ** (db / 40.0)
    if kind == "lowpass":
        b = ((1.0 - cos) / 2.0, 1.0 - cos, (1.0 - cos) / 2.0)
        a = (1.0 + alpha, -2.0 * cos, 1.0 - alpha)
    elif kind == "highpass":
        b = ((1.0 + cos) / 2.0, -(1.0 + cos), (1.0 + cos) / 2.0)
        a = (1.0 + alpha, -2.0 * cos, 1.0 - alpha)
    elif kind == "bell":
        b = (1.0 + alpha * amp, -2.0 * cos, 1.0 - alpha * amp)
        a = (1.0 + alpha / amp, -2.0 * cos, 1.0 - alpha / amp)
    elif kind in ("low", "high"):
        # The same shelf mirrored: a high shelf is a low one seen from the top.
        side = 1.0 if kind == "low" else -1.0
        beta = 2.0 * math.sqrt(amp) * alpha
        b = (
            amp * ((amp + 1.0) - side * (amp - 1.0) * cos + beta),
            side * 2.0 * amp * ((amp - 1.0) - side * (amp + 1.0) * cos),
            amp * ((amp + 1.0) - side * (amp - 1.0) * cos - beta),
        )
        a = (
            (amp + 1.0) + side * (amp - 1.0) * cos + beta,
            side * -2.0 * ((amp - 1.0) + side * (amp + 1.0) * cos),
            (amp + 1.0) + side * (amp - 1.0) * cos - beta,
        )
    else:
        raise SystemExit(f"not a filter: {kind}")
    return (b[0] / a[0], b[1] / a[0], b[2] / a[0], a[1] / a[0], a[2] / a[0])


def filtered(samples: list, stage: tuple) -> list:
    b0, b1, b2, a1, a2 = stage
    x1 = x2 = y1 = y2 = 0.0
    out = []
    for x in samples:
        y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, x, y1, y
        out.append(y)
    return out


def top(take: list) -> float:
    return max(1e-9, max(max(max(channel), -min(channel)) for channel in take))


def prepared(take: list, spec: dict, onset: float) -> list:
    """A take filtered as its spec says and, if it is tight, begun at the
    bang. `onset` is how far below the peak the bang counts as begun."""
    for kind in ("lowpass", "highpass"):
        if kind in spec:
            for q in BUTTERWORTH:
                take = [filtered(channel, biquad(kind, spec[kind], 0.0, q)) for channel in take]
    if spec.get("tight"):
        loud = onset * top(take)
        first = min(next(i for i, sample in enumerate(channel + [loud]) if abs(sample) >= loud) for channel in take)
        take = [channel[max(0, first - LEAD):] for channel in take]
    return take


def faded(take: list, length: float) -> list:
    """A take cut off after `length` seconds if it is longer, faded in and out."""
    fade = 0.005
    count = len(take[0])
    if length and count > length * RATE:
        count = int(length * RATE)
        fade = min(FADE, 0.3 * length)
    fade_in, fade_out = LEAD // 2, int(fade * RATE)
    return [
        [channel[i] * min(1.0, (i + 1) / fade_in, (count - i) / fade_out) for i in range(count)]
        for channel in take
    ]


def clipped(take: list, drive: float, punch: float) -> list:
    """A take with its peak at 1, pushed into the soft clip."""
    peak = top(take)
    ceiling = math.tanh(drive * punch)
    return [
        [
            math.tanh(sample / peak * drive * (1.0 + (punch - 1.0) * math.exp(-i / (PUNCH * RATE)))) / ceiling
            for i, sample in enumerate(channel)
        ]
        for channel in take
    ]


def mix(take: list, under: list, spec: dict) -> None:
    """Adds a layer to a take, which grows if the layer outlasts it."""
    gain = 10.0 ** (spec.get("gain", 0.0) / 20.0) * (-1.0 if spec.get("invert") else 1.0)
    delay = int(spec.get("delay", 0.0) / 1000.0 * RATE)
    if delay < 0:
        raise SystemExit("a layer cannot start before the recording: its delay is negative")
    for c, channel in enumerate(take):
        added = under[min(c, len(under) - 1)]
        channel.extend([0.0] * (delay + len(added) - len(channel)))
        for i, sample in enumerate(added):
            channel[delay + i] += sample * gain


def build(sound: dict, packs: dict, scratch: pathlib.Path) -> None:
    bed = int(sound.get("bed", 0.0) * RATE)
    # A bed is mixed half a second longer than it is, for its own seam.
    whole = bed + int(SEAM * RATE)
    stereo = sound.get("stereo", False) or bed > 0
    recorded = []
    for take in excerpts(sound, packs, scratch, stereo):
        take = clipped(prepared(take, sound, 0.1), sound.get("drive", 1.0), sound.get("punch", 1.0))
        recorded.append(tiled(take, whole, not made(sound)) if bed else take)
    if bed:
        recorded = recorded[:1]
    layers = []
    for spec in sound.get("layers", []):
        under = []
        for take in excerpts(spec, packs, scratch, bed > 0):
            take = faded(prepared(take, spec, 0.25), spec.get("length", 0.0))
            peak = top(take)
            take = [[sample / peak for sample in channel] for channel in take]
            under.append(tiled(take, whole, not made(spec)) if bed and not spec.get("once") else take)
        layers.append((spec, under))
    takes = []
    for i in range(sound.get("takes", len(recorded))):
        take = [channel[:] for channel in recorded[i % len(recorded)]]
        # Past the last recorded take they come round again, each time with
        # the next take of every layer, so that no two mixes are the same.
        for spec, under in layers:
            mix(take, under[(i % len(recorded) + i // len(recorded)) % len(under)], spec)
        for kind, hz, db in sound.get("eq", []):
            take = [filtered(channel, biquad(kind, hz, db, 0.9 if kind == "bell" else 0.7071)) for channel in take]
        if bed:
            take = [seamless(channel[:whole], whole - bed) for channel in take]
        if "glue" in sound:
            take = clipped(take, *sound["glue"])
        elif top(take) > 1.0 or "rms" in sound:
            # Layers and filters add up to more than the recording was.
            peak = top(take)
            take = [[sample / peak for sample in channel] for channel in take]
        if "rms" in sound:
            mean = math.sqrt(sum(sample * sample for channel in take for sample in channel) / sum(len(channel) for channel in take))
            gain = min(10.0 ** (sound["rms"] / 20.0) * 32768.0 / PEAK / mean, 1.0)
            take = [[sample * gain for sample in channel] for channel in take]
        takes.append(take if bed else faded(take, sound.get("length", 0.0)))

    out = OUT / sound["id"]
    out.mkdir(parents=True, exist_ok=True)
    kind = ".ogg" if "ogg" in sound else ".wav"
    # A take that is rewritten keeps its .import file, and with it its uid.
    keep = {f"{sound['id']}_{i + 1}{kind}" for i in range(len(takes))}
    for stale in out.glob(f"{sound['id']}_*"):
        if stale.name.removesuffix(".import") not in keep:
            stale.unlink()
    rate = sound.get("rate", RATE)
    if RATE % rate:
        raise SystemExit(f"{sound['id']}: a rate has to go into {RATE} a whole number of times")
    for i, take in enumerate(takes):
        if rate != RATE:
            # Nothing may be left above half the new rate: it would come
            # back as a tone that was never there.
            # A bed is filtered as it will be heard, going round: its end
            # is run through the filter before its start.
            lead = min(4096, len(take[0])) if bed else 0
            take = [channel[len(channel) - lead:] + channel for channel in take]
            for q in BUTTERWORTH + BUTTERWORTH:
                take = [filtered(channel, biquad("lowpass", 0.42 * rate, 0.0, q)) for channel in take]
            take = [channel[lead::RATE // rate] for channel in take]
        frames = array.array("h", bytes(2 * len(take) * len(take[0])))
        for c, channel in enumerate(take):
            frames[c::len(take)] = array.array("h", [int(sample * PEAK) for sample in channel])
        path = out / f"{sound['id']}_{i + 1}.wav"
        with wave.open(str(path), "wb") as writer:
            writer.setnchannels(len(take))
            writer.setsampwidth(2)
            writer.setframerate(rate)
            writer.writeframes(frames.tobytes())
        if kind == ".ogg":
            subprocess.run([OGGENC, "--quiet", "-q", str(sound["ogg"]), "-o", str(path.with_suffix(".ogg")), str(path)], check=True)
            path.unlink()
    lengths = " ".join(f"{len(take[0]) / RATE:.2f}" for take in takes)
    print(f"{sound['id']:16s} {len(takes):2d} takes  {lengths}")


def main() -> None:
    manifest = json.loads((ROOT / "assets/manifest.json").read_text())
    sounds = [asset for asset in manifest["assets"] if asset["type"] == "sound"]
    wanted = sys.argv[1:]
    unknown = set(wanted) - {"--all"} - {sound["id"] for sound in sounds}
    if unknown:
        raise SystemExit(f"not a sound in the manifest: {', '.join(sorted(unknown))}")
    built = False
    for sound in sounds:
        if wanted:
            if "--all" not in wanted and sound["id"] not in wanted:
                continue
        elif any((OUT / sound["id"]).glob("*.wav")) or any((OUT / sound["id"]).glob("*.ogg")):
            continue
        with tempfile.TemporaryDirectory() as scratch:
            build(sound, manifest["packs"], pathlib.Path(scratch))
        built = True
    if built:
        subprocess.run([GODOT, "--headless", "--path", str(ROOT), "--import"], check=True, stdout=subprocess.DEVNULL)


if __name__ == "__main__":
    main()
