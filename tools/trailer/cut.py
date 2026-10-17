#!/usr/bin/env python3
"""Cuts the takes of tools/trailer.sh together into the trailer.

    tools/trailer/cut.py <folder>        cut the takes in it into trailer.mp4
    tools/trailer/cut.py --takes         the takes the cut needs, one a line
    tools/trailer/cut.py --sheet <.avi>  a sheet of the frames of one take

CUT below is the film: which take and which of its scenes, from how many
seconds after that scene's action begins, for how long. The pictures are
taken as they are; the sound of each shot comes along with its pictures,
with a few milliseconds of fade at every cut so that nothing clicks, and the
music goes under all of it. MUSIC says which piece and from where: its first
hit after a quiet stretch falls on the cut from the sniper to the minigun,
and the hits after that come every four to five seconds. The pictures go to
a folder as JPEG files and the sound to a .wav, and
tools/trailer/encode.swift makes the mp4 of them; trailer_sheet.jpg next to it
shows the cut at two pictures a second.
"""
import array
import json
import math
import os
import shutil
import subprocess
import sys
import wave

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from avi import Take  # noqa: E402

FPS = 60
RATE = 48000
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

# (take, scene, seconds into that scene's action, seconds long)
CUT = [
    ("sniper", "action", 0.0, 3.0),
    ("minigun", "action", 0.0, 2.5),
    ("soldiers", "action", 0.4, 1.4),
    ("robots", "action", 0.35, 1.4),
    ("clowns", "action", 0.3, 1.4),
    ("barrels", "action", 0.6, 1.5),
    ("shotgun", "action", 0.8, 1.52),
    ("match", "action", 0.3, 2.6),
    ("maps", "factory", 0.0, 0.45),
    ("maps", "works", 0.0, 0.45),
    ("maps", "depot", 0.0, 0.45),
    ("maps", "powerhouse", 0.0, 0.45),
    ("maps", "dunes", 0.0, 0.43),
    ("title", "action", 0.4, 3.0),
]
# The piece of music, where in it the trailer begins, and how loud it is
# under the sound of the game.
MUSIC = os.path.join(ROOT, "assets", "music", "level1and2.mp3")
MUSIC_FROM = 9.32
MUSIC_GAIN = 0.8
GAME_GAIN = 0.85
# Seconds of fade at every cut, and from and to black at either end.
CLICK = 0.006
FADE_IN = 0.25
FADE_OUT = 0.6


def takes():
    seen = []
    for take, _, _, _ in CUT:
        if take not in seen:
            seen.append(take)
    return seen


def action_frame(avi_path, scene="action"):
    """The index in the film of the frame at which `scene` began. The
    director counts frames drawn, and the first frame of the film is the
    first one drawn."""
    with open(avi_path[:-4] + ".json") as file:
        marks = json.load(file)
    return max(marks["actions"][scene] - 1, 0)


def sheet(avi_path):
    """Every tenth frame of a take from its first action on, with its time."""
    take = Take(avi_path)
    with open(avi_path[:-4] + ".json") as file:
        actions = json.load(file)["actions"]
    first = max(min(actions.values()) - 1, 0)
    folder = avi_path[:-4] + "_sheet"
    shutil.rmtree(folder, ignore_errors=True)
    os.makedirs(folder)
    command = ["magick", "montage", "-font", FONT, "-pointsize", "14"]
    for index in range(first, len(take.pictures), 10):
        path = os.path.join(folder, "%06d.jpg" % index)
        with open(path, "wb") as file:
            file.write(take.picture(index))
        command += ["-label", "%.2f s" % ((index - first) / FPS), path]
    out = avi_path[:-4] + "_sheet.jpg"
    command += ["-tile", "6x", "-geometry", "320x180+3+3", out]
    subprocess.run(command, check=True)
    shutil.rmtree(folder)
    print(out)


def samples(raw):
    """16-bit stereo bytes as an array of floats from -1 to 1."""
    pcm = array.array("h")
    pcm.frombytes(raw)
    return array.array("f", (value / 32768.0 for value in pcm))


def music(seconds, folder):
    """The music under the trailer, as floats: from MUSIC_FROM on, fading out
    over the last FADE_OUT * 2 seconds."""
    decoded = os.path.join(folder, "music.wav")
    subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16@%d" % RATE, "-c", "2", MUSIC, decoded], check=True)
    with wave.open(decoded) as file:
        file.setpos(int(MUSIC_FROM * RATE))
        piece = samples(file.readframes(int(seconds * RATE)))
    os.remove(decoded)
    fade = int(FADE_OUT * 2 * RATE)
    total = len(piece) // 2
    for i in range(max(total - fade, 0), total):
        weight = (total - i) / fade
        piece[2 * i] *= weight
        piece[2 * i + 1] *= weight
    return piece


def cut(folder):
    frames = os.path.join(folder, "frames")
    shutil.rmtree(frames, ignore_errors=True)
    os.makedirs(frames)
    opened = {}
    sound = array.array("f")
    count = 0
    per_frame = RATE // FPS
    for take, scene, offset, length in CUT:
        if take not in opened:
            opened[take] = Take(os.path.join(folder, take + ".avi"))
        film = opened[take]
        first = action_frame(os.path.join(folder, take + ".avi"), scene) + round(offset * FPS)
        many = round(length * FPS)
        if first + many > len(film.pictures):
            sys.exit("%s/%s has %d frames from %.2f s on, the cut asks for %d" % (take, scene, len(film.pictures) - first, offset, many))
        for index in range(first, first + many):
            with open(os.path.join(frames, "%06d.jpg" % count), "wb") as file:
                file.write(film.picture(index))
            count += 1
        piece = samples(film.sound[first * per_frame * 4:(first + many) * per_frame * 4])
        piece.extend([0.0] * (many * per_frame * 2 - len(piece)))
        click = int(CLICK * RATE)
        for i in range(click):
            weight = i / click
            for at in (2 * i, 2 * i + 1, len(piece) - 2 * i - 2, len(piece) - 2 * i - 1):
                piece[at] *= weight
        sound.extend(piece)
        print("%-9s %-10s %5.2f s  from %5.2f s" % (take, scene, length, (count - many) / FPS))
    print("%d frames, %.2f s" % (count, count / FPS))

    under = music(count / FPS, folder)
    mixed = array.array("h", bytes(len(sound) * 2))
    loudest = 0.0
    # The whole of it comes up from silence and goes down into it, as the
    # picture does from black and into it.
    rise = FADE_IN * RATE * 2
    fall = FADE_OUT * RATE * 2
    for i in range(len(sound)):
        value = sound[i] * GAME_GAIN + (under[i] * MUSIC_GAIN if i < len(under) else 0.0)
        value *= min(1.0, i / rise, (len(sound) - i) / fall)
        loudest = max(loudest, abs(value))
        # Soft at the top, so that a blast over a hit does not clip.
        mixed[i] = int(32767 * math.tanh(value))
    print("loudest before the limiter: %.2f" % loudest)
    with wave.open(os.path.join(folder, "trailer.wav"), "wb") as file:
        file.setnchannels(2)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(mixed.tobytes())

    # From black at the start and to black at the end.
    for index, weight in [(i, 1.0 - i / (FADE_IN * FPS)) for i in range(round(FADE_IN * FPS))] + [
        (count - 1 - i, 1.0 - i / (FADE_OUT * FPS)) for i in range(round(FADE_OUT * FPS))
    ]:
        path = os.path.join(frames, "%06d.jpg" % index)
        subprocess.run(["magick", path, "-fill", "black", "-colorize", "%d%%" % round(100 * weight), "-quality", "95", path], check=True)

    # A sheet of the cut, two pictures a second, to look it over at a glance.
    command = ["magick", "montage", "-font", FONT, "-pointsize", "14"]
    for index in range(0, count, FPS // 2):
        command += ["-label", "%.1f s" % (index / FPS), os.path.join(frames, "%06d.jpg" % index)]
    command += ["-tile", "7x", "-geometry", "320x180+3+3", os.path.join(folder, "trailer_sheet.jpg")]
    subprocess.run(command, check=True)

    encoder = os.path.join(folder, "encode")
    source = os.path.join(HERE, "encode.swift")
    if not os.path.exists(encoder) or os.path.getmtime(encoder) < os.path.getmtime(source):
        subprocess.run(["swiftc", "-O", source, "-o", encoder], check=True)
    out = os.path.join(folder, "trailer.mp4")
    subprocess.run([encoder, frames, str(FPS), os.path.join(folder, "trailer.wav"), out], check=True)
    shutil.rmtree(frames)


def main():
    if sys.argv[1:] == ["--takes"]:
        print("\n".join(takes()))
        return
    if len(sys.argv) == 3 and sys.argv[1] == "--sheet":
        sheet(sys.argv[2])
        return
    if len(sys.argv) == 2 and not sys.argv[1].startswith("-"):
        cut(sys.argv[1])
        return
    print(__doc__)
    sys.exit(64)


if __name__ == "__main__":
    main()
