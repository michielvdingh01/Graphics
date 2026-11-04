#!/usr/bin/env python3
"""Makes the music that plays where somebody dances the TikTok Dance of the
Unmuted match: a short loop of our own, written straight to
assets/audio/dance_beat/dance_beat_1.wav and dance_beat_b/dance_beat_b_1.wav,
which scripts/dancer.gd plays round and round from where the dancer stands.

  python3 tools/unmuted/beat.py

a: four on the floor at 120 beats a minute, four bars (eight seconds): a
kick on every beat, a clap on two and four, a hi-hat between, a bass that
walks A, F, C, G and a plucked hook over it.
b: the same four bars at 140 in half time: a kick and a long low boom on one,
a snare on three, hi-hats in triplets and the hook an octave down.

Everything that rings on past the end of the loop comes round at its start,
so that it goes round without a seam. Mono, 44.1 kHz, 16 bit.
"""
import array
import math
import pathlib
import random
import wave

RATE = 44100
OUT = pathlib.Path(__file__).resolve().parents[2] / "assets/audio"
PEAK = 29000


def note(name: str) -> float:
    """The frequency of a note such as A2 or C#4."""
    steps = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2.0 ** ((steps[pitch] + 12 * (octave - 4)) / 12.0)


class Loop:
    def __init__(self, seconds: float):
        self.size = int(seconds * RATE)
        self.data = [0.0] * self.size

    def add(self, at: float, samples: list, gain: float) -> None:
        start = int(at * RATE)
        for i, value in enumerate(samples):
            self.data[(start + i) % self.size] += value * gain

    def write(self, path: pathlib.Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        top = max(abs(v) for v in self.data) or 1.0
        # A soft clip, as a mix bus does, then up to the peak every take has.
        soft = [math.tanh(1.4 * v / top) for v in self.data]
        top = max(abs(v) for v in soft) or 1.0
        pcm = array.array("h", (int(v / top * PEAK) for v in soft))
        with wave.open(str(path), "wb") as out:
            out.setnchannels(1)
            out.setsampwidth(2)
            out.setframerate(RATE)
            out.writeframes(pcm.tobytes())
        print(path)


def kick(length=0.35, top=150.0, bottom=45.0) -> list:
    out, phase = [], 0.0
    for i in range(int(length * RATE)):
        t = i / RATE
        freq = bottom + (top - bottom) * math.exp(-t * 30.0)
        phase += 2 * math.pi * freq / RATE
        out.append(math.sin(phase) * math.exp(-t * 7.0) + (0.4 * math.exp(-t * 300.0) if i < 200 else 0.0))
    return out


def boom(length=1.4, freq=45.0) -> list:
    out, phase = [], 0.0
    for i in range(int(length * RATE)):
        t = i / RATE
        phase += 2 * math.pi * (freq + 60.0 * math.exp(-t * 25.0)) / RATE
        out.append(math.tanh(2.0 * math.sin(phase)) * math.exp(-t * 2.2))
    return out


def noise_hit(length: float, decay: float, bright: float, seed: int) -> list:
    """Noise that dies away; `bright` 0..1 is how much of the low end is taken out."""
    rng = random.Random(seed)
    out, low = [], 0.0
    for i in range(int(length * RATE)):
        t = i / RATE
        white = rng.uniform(-1, 1)
        low += (white - low) * 0.15
        out.append((white - bright * low) * math.exp(-t * decay))
    return out


def clap(seed: int) -> list:
    # Three quick slaps and a tail, as hands that do not quite meet at once.
    body = noise_hit(0.25, 18.0, 0.8, seed)
    out = [0.0] * len(body)
    for start, gain in ((0, 0.7), (int(0.011 * RATE), 0.8), (int(0.022 * RATE), 1.0)):
        for i in range(len(body) - start):
            out[start + i] += body[i] * gain * (1.0 if start == int(0.022 * RATE) else math.exp(-i / RATE * 120.0))
    return out


def bass(freq: float, length: float) -> list:
    out, phase = [], 0.0
    for i in range(int(length * RATE)):
        t = i / RATE
        phase = (phase + freq / RATE) % 1.0
        saw = 2.0 * phase - 1.0
        sub = math.sin(2 * math.pi * phase)
        out.append((0.45 * saw + 0.8 * sub) * min(1.0, t * 200.0) * math.exp(-t * 1.5))
    # A crude lowpass: the saw's edge taken off.
    smooth, value = [], 0.0
    for v in out:
        value += (v - value) * 0.12
        smooth.append(value)
    return smooth


def pluck(freq: float, length: float, seed: int) -> list:
    """A plucked string: Karplus-Strong, bright at first and rounder as it rings."""
    rng = random.Random(seed)
    period = max(2, int(RATE / freq))
    line = [rng.uniform(-1, 1) for _ in range(period)]
    out = []
    for i in range(int(length * RATE)):
        value = line[i % period]
        line[i % period] = 0.497 * (value + line[(i + 1) % period])
        out.append(value)
    return out


def variant_a() -> Loop:
    bpm = 120.0
    beat = 60.0 / bpm
    loop = Loop(beat * 16)
    roots = ["A1", "F1", "C2", "G1"]
    hook = ["A4", "C5", "E5", "C5", "D5", "C5", "A4", "G4"]
    k, c = kick(), [clap(s) for s in range(4)]
    for bar in range(4):
        for b in range(4):
            at = (bar * 4 + b) * beat
            loop.add(at, k, 1.0)
            if b in (1, 3):
                loop.add(at, c[(bar + b) % 4], 0.55)
            loop.add(at + beat / 2, noise_hit(0.06, 70.0, 1.0, bar * 4 + b), 0.18)
            # The bass on the off-beats, as house has it.
            loop.add(at + beat / 2, bass(note(roots[bar]), beat * 0.45), 0.55)
        for i, name in enumerate(hook):
            if (bar == 3 and i >= 6):
                continue
            loop.add(bar * 4 * beat + i * beat / 2, pluck(note(name), beat * 0.9, bar * 10 + i), 0.32)
    return loop


def variant_b() -> Loop:
    bpm = 140.0
    beat = 60.0 / bpm
    loop = Loop(beat * 16)
    hook = ["A3", "C4", "E4", "G4", "E4", "C4", "D4", "C4"]
    k, b808 = kick(0.3, 170.0, 55.0), boom()
    for bar in range(4):
        start = bar * 4 * beat
        loop.add(start, k, 0.8)
        loop.add(start, b808, 0.9)
        loop.add(start + 2.5 * beat, k, 0.6)
        loop.add(start + 2 * beat, noise_hit(0.22, 16.0, 0.6, bar), 0.6)
        for step in range(12):
            loop.add(start + step * beat / 3, noise_hit(0.04, 90.0, 1.0, 100 + bar * 12 + step), 0.14 if step % 3 else 0.22)
        for i, name in enumerate(hook):
            loop.add(start + i * beat / 2, pluck(note(name), beat * 0.9, 50 + bar * 10 + i), 0.36)
    return loop


def main() -> None:
    variant_a().write(OUT / "dance_beat" / "dance_beat_1.wav")
    variant_b().write(OUT / "dance_beat_b" / "dance_beat_b_1.wav")


if __name__ == "__main__":
    main()
