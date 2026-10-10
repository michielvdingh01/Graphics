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
            pitch, the thump under a shot. It can say lowpass and highpass
            (Hz, 24 dB per octave), length (seconds), gain (dB against the
            recording, each at full scale), delay (ms after the recording
            starts) and invert. Those last two decide whether the bass of a
            layer adds to that of the recording or cancels it, so measure
            before changing them
    eq      filters over the mix, each [kind, Hz, dB]: "low" and "high" are
            shelves, "bell" a peak an octave and a half wide
    glue    [drive, punch] of one more soft clip, over the mix: what makes
            the layers one sound

A pack is downloaded once into .cache/sounds/ and checked against the checksum
in the manifest; only the files a sound names are unpacked. Needs macOS
(afconvert, bsdtar) and Godot for Ogg files.
"""
import array
import hashlib
import json
import math
import os
import pathlib
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
HEADERS = {"User-Agent": "GraphicsFPS-asset-fetch/0.1"}

RATE = 44100
PEAK = 29000  # what the synthesised placeholders in scripts/sfx.gd peak at
BLOCK = RATE // 500  # the loudness of a file is followed in steps of 2 ms
GAP = 0.3  # seconds of quiet that separate two takes
LEAD = int(0.002 * RATE)  # kept before the start of a take
FADE = 0.25  # seconds over which a take that was cut off dies away
PUNCH = 0.04  # seconds over which the push of "punch" wears off
BUTTERWORTH = (0.5412, 1.3066)  # the two stages of a 24 dB per octave filter


def unpack(name: str, pack: dict, wanted: str) -> pathlib.Path:
    """The folder a pack is unpacked in, with the files that match `wanted` in
    it: the pack is downloaded if need be, and only those are unpacked."""
    folder = CACHE / name
    files = folder / "files"
    if any(files.glob(wanted)):
        return files
    archive = folder / urllib.parse.unquote(pack["url"].rsplit("/", 1)[1])
    if not archive.exists():
        folder.mkdir(parents=True, exist_ok=True)
        print(f"downloading {archive.name}")
        partial = archive.with_name(archive.name + ".part")
        with urllib.request.urlopen(urllib.request.Request(pack["url"], headers=HEADERS)) as response:
            with open(partial, "wb") as out:
                shutil.copyfileobj(response, out)
        partial.rename(archive)
    digest = hashlib.sha256()
    with open(archive, "rb") as data:
        for chunk in iter(lambda: data.read(1 << 20), b""):
            digest.update(chunk)
    if digest.hexdigest() != pack["sha256"]:
        raise SystemExit(f"checksum mismatch for {archive}")
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


def spans(channel: array.array, split: bool) -> list:
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
    gap = int(GAP * RATE / BLOCK)
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
        for first, last in spans(channels[0], spec.get("split", False)):
            takes.append([[float(sample) for sample in channel[first:last]] for channel in channels])
    if not takes:
        raise SystemExit(f"found no sound in {spec['files']}")
    return takes


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
    stereo = sound.get("stereo", False)
    recorded = []
    for take in excerpts(sound, packs, scratch, stereo):
        recorded.append(clipped(prepared(take, sound, 0.1), sound.get("drive", 1.0), sound.get("punch", 1.0)))
    layers = []
    for spec in sound.get("layers", []):
        under = []
        for take in excerpts(spec, packs, scratch, False):
            take = faded(prepared(take, spec, 0.25), spec.get("length", 0.0))
            peak = top(take)
            under.append([[sample / peak for sample in channel] for channel in take])
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
        if "glue" in sound:
            take = clipped(take, *sound["glue"])
        elif top(take) > 1.0:
            # Layers and filters add up to more than the recording was.
            peak = top(take)
            take = [[sample / peak for sample in channel] for channel in take]
        takes.append(faded(take, sound.get("length", 0.0)))

    out = OUT / sound["id"]
    out.mkdir(parents=True, exist_ok=True)
    # A take that is rewritten keeps its .import file, and with it its uid.
    keep = {f"{sound['id']}_{i + 1}.wav" for i in range(len(takes))}
    for stale in out.glob(f"{sound['id']}_*.wav*"):
        if stale.name.removesuffix(".import") not in keep:
            stale.unlink()
    for i, take in enumerate(takes):
        frames = array.array("h", bytes(2 * len(take) * len(take[0])))
        for c, channel in enumerate(take):
            frames[c::len(take)] = array.array("h", [int(sample * PEAK) for sample in channel])
        with wave.open(str(out / f"{sound['id']}_{i + 1}.wav"), "wb") as writer:
            writer.setnchannels(len(take))
            writer.setsampwidth(2)
            writer.setframerate(RATE)
            writer.writeframes(frames.tobytes())
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
        elif any((OUT / sound["id"]).glob("*.wav")):
            continue
        with tempfile.TemporaryDirectory() as scratch:
            build(sound, manifest["packs"], pathlib.Path(scratch))
        built = True
    if built:
        subprocess.run([GODOT, "--headless", "--path", str(ROOT), "--import"], check=True, stdout=subprocess.DEVNULL)


if __name__ == "__main__":
    main()
