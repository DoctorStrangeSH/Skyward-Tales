#!/usr/bin/env python3
"""Skyward Tales music on real instruments (stage 20, 9 ноября 2026).

    python3 tools/audio/orchestra.py [--only title,meadow,...] [--keep-wav]

The old chiptune tracks (tools/audio/build_audio.py) are replaced by an
orchestral score played through the GeneralUser GS SoundFont (S. Christian
Collins, free for use in games, see tools/audio/README.md) with the
TinySoundFont synth (MIT). Both are fetched from GitHub into
tools/audio/.cache on first run (not kept in git); the small renderer
tools/audio/sf_render.c is compiled there with gcc.

Everything is written here as notes: melodies by hand (one shared
"Skyward" theme plus a tune per land), accompaniment from chord charts.
Output: 44.1 kHz stereo Ogg Vorbis loops with a convolution reverb, the
reverb tail folded onto the head so the loop has no seam.
"""
from __future__ import annotations

import argparse
import pathlib
import random
import subprocess
import sys
import tempfile

import numpy as np
from scipy import signal

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "audio"
CACHE = ROOT / "tools" / "audio" / ".cache"
SR = 44100
BANK_REPO = ("https://github.com/mrbumpy409/GeneralUser-GS.git", "GeneralUser-GS.sf2")
TSF_REPO = "https://github.com/schellingb/TinySoundFont.git"

# General MIDI programs of the bank (bank 0) we use.
GM = {
    "piano": 0, "celesta": 8, "glock": 9, "musicbox": 10, "vibes": 11, "marimba": 12, "bells": 14,
    "nylon": 24, "acbass": 32, "violin": 40, "viola": 41, "cello": 42, "contrabass": 43,
    "tremolo": 44, "pizz": 45, "harp": 46, "timpani": 47, "strings": 48, "slowstrings": 49,
    "choir": 52, "oohs": 53, "orchhit": 55, "trumpet": 56, "trombone": 57, "tuba": 58, "horn": 60,
    "brass": 61, "oboe": 68, "ehorn": 69, "bassoon": 70, "clarinet": 71, "piccolo": 72, "flute": 73,
    "recorder": 74, "panflute": 75, "whistle": 78, "ocarina": 79, "warmpad": 89, "spacevoice": 91,
    "glass": 92, "halo": 94, "fiddle": 110, "kalimba": 108, "accordion": 21, "taiko": 116,
    "woodblock": 115, "revcymbal": 119, "atmosphere": 99, "crystal": 98,
}
DRUMS_ORCH = (128, 48)
DRUMS_STD = (128, 0)
# GM drum keys.
KICK, SNARE, SIDE, CRASH, RIDE, SHAKER, TAMB, TRIANGLE, OPEN_TRI, BD2, CLAP, LOW_TOM, MID_TOM, HI_TOM, SUS_CYM = \
    36, 38, 37, 49, 51, 82, 54, 81, 81, 35, 39, 45, 47, 50, 55

NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


# --- setup -------------------------------------------------------------------

def ensure_tools() -> tuple[pathlib.Path, pathlib.Path]:
    """The SoundFont and the compiled renderer (fetched/built once)."""
    CACHE.mkdir(parents=True, exist_ok=True)
    bank_dir = CACHE / "gugs"
    if not (bank_dir / BANK_REPO[1]).exists():
        subprocess.run(["git", "clone", "-q", "--depth", "1", BANK_REPO[0], str(bank_dir)], check=True)
    tsf_dir = CACHE / "tsf"
    if not (tsf_dir / "tsf.h").exists():
        subprocess.run(["git", "clone", "-q", "--depth", "1", TSF_REPO, str(tsf_dir)], check=True)
    exe = CACHE / "sf_render"
    src = ROOT / "tools" / "audio" / "sf_render.c"
    if not exe.exists() or exe.stat().st_mtime < src.stat().st_mtime:
        subprocess.run(["gcc", "-O2", "-I", str(tsf_dir), "-o", str(exe), str(src), "-lm"], check=True)
    return bank_dir / BANK_REPO[1], exe


# --- music theory ------------------------------------------------------------

def pitch(name: str) -> int:
    """"F#4" → 66 (C4 = 60)."""
    letter, rest = name[0].upper(), name[1:]
    acc = 0
    while rest and rest[0] in "#b":
        acc += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + NAMES[letter] + acc


QUALITIES = {
    "": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "m7": [0, 3, 7, 10], "maj7": [0, 4, 7, 11],
    "sus2": [0, 2, 7], "sus4": [0, 5, 7], "add9": [0, 4, 7, 14], "madd9": [0, 3, 7, 14], "dim": [0, 3, 6],
    "m7b5": [0, 3, 6, 10], "6": [0, 4, 7, 9], "m6": [0, 3, 7, 9], "5": [0, 7],
}


def chord(symbol: str) -> tuple[int, list[int]]:
    """"F#m7" → (root pitch class, [pitch classes]); "C/G" puts G in the bass."""
    bass = None
    if "/" in symbol:
        symbol, bass_name = symbol.split("/")
        bass = (NAMES[bass_name[0]] + (1 if "#" in bass_name else -1 if "b" in bass_name[1:] else 0)) % 12
    root = NAMES[symbol[0]]
    q = symbol[1:]
    if q[:1] in ("#", "b"):
        root += 1 if q[0] == "#" else -1
        q = q[1:]
    tones = [(root + i) % 12 for i in QUALITIES[q]]
    return (bass if bass is not None else root % 12), tones


def in_range(pc: int, low: int, high: int) -> list[int]:
    return [n for n in range(low, high + 1) if n % 12 == pc]


def voice(tones: list[int], previous: list[int] | None, low: int, high: int, count: int) -> list[int]:
    """Close voicing of the chord in [low, high], moving as little as possible."""
    candidates = sorted({n for pc in tones for n in in_range(pc, low, high)})
    best, best_cost = None, 1e9
    rng = random.Random(len(candidates) * 31 + count)
    options = []
    for start in range(len(candidates)):
        pick = candidates[start:start + count]
        if len(pick) < count:
            break
        options.append(pick)
    for pick in options:
        if len({n % 12 for n in pick}) < min(count, len(set(tones))):
            continue
        if previous:
            cost = sum(min(abs(a - b) for b in previous) for a in pick)
        else:
            cost = abs(sum(pick) / len(pick) - (low + high) / 2) + rng.random() * 0.01
        if cost < best_cost:
            best, best_cost = pick, cost
    return best or candidates[:count]


def parse_melody(text: str, beats_per_bar: float) -> list[tuple[float, int | None, float, int]]:
    """"D5:1.5 E5:.5 | ..." → [(beat, pitch or None, length, accent)]. Bars are checked."""
    out = []
    beat = 0.0
    for b, bar in enumerate(text.split("|")):
        bar_start = beat
        for token in bar.split():
            accent = token.count("!")
            token = token.replace("!", "")
            name, _, length = token.partition(":")
            length_f = float(length) if length else 1.0
            out.append((beat, None if name in ("r", "-") else pitch(name), length_f, accent))
            beat += length_f
        if abs(beat - bar_start - beats_per_bar) > 1e-6:
            raise ValueError(f"bar {b + 1} has {beat - bar_start} beats: {bar.strip()}")
    return out


# --- score -------------------------------------------------------------------

class Part:
    def __init__(self, score: "Score", channel: int, program: int, bank: int, volume: int, pan: int):
        self.score, self.channel, self.program, self.bank = score, channel, program, bank
        self.volume, self.pan = volume, pan
        self.notes: list[tuple[float, int, float, int]] = []
        self.ccs: list[tuple[float, int, int]] = []

    def note(self, beat: float, key: int, length: float, vel: int) -> None:
        if key is None:
            return
        self.notes.append((beat, int(key), length, max(1, min(127, int(vel)))))

    def notes_at(self, beat: float, keys, length: float, vel: int) -> None:
        for k in keys:
            self.note(beat, k, length, vel)

    def swell(self, start: float, end: float, a: int, b: int, cc: int = 11, steps: int = 12) -> None:
        for i in range(steps + 1):
            self.ccs.append((start + (end - start) * i / steps, cc, int(a + (b - a) * i / steps)))

    def melody(self, start_beat: float, text: str, vel: int = 90, octave: int = 0, legato: float = 0.95,
               swing: float = 0.0) -> None:
        for beat, key, length, accent in parse_melody(text, self.score.beats):
            if key is None:
                continue
            self.note(start_beat + beat, key + 12 * octave, length * legato, vel + 12 * accent)


class Score:
    def __init__(self, bpm: float, beats: int = 4, seed: int = 1):
        self.bpm, self.beats = bpm, beats
        self.parts: list[Part] = []
        self.rng = random.Random(seed)

    def part(self, program: str | int, volume: int = 100, pan: int = 64, bank: int = 0) -> Part:
        ch = len(self.parts)
        if ch >= 16:
            raise ValueError("too many parts")
        p = Part(self, ch, GM[program] if isinstance(program, str) else program, bank, volume, pan)
        self.parts.append(p)
        return p

    def drums(self, kit=DRUMS_ORCH, volume: int = 100, pan: int = 64) -> Part:
        return self.part(kit[1], volume, pan, kit[0])

    def seconds(self, beat: float) -> float:
        return beat * 60.0 / self.bpm

    def events(self, humanize: float = 0.006) -> list[str]:
        lines = []
        for p in self.parts:
            lines.append(f"0 P {p.channel} {p.bank} {p.program}")
            lines.append(f"0 C {p.channel} 7 {p.volume}")
            lines.append(f"0 C {p.channel} 10 {p.pan}")
            lines.append(f"0 C {p.channel} 11 127")
            for beat, cc, value in p.ccs:
                lines.append(f"{self.seconds(beat):.5f} C {p.channel} {cc} {max(0, min(127, value))}")
            for beat, key, length, vel in p.notes:
                jitter = self.rng.uniform(-humanize, humanize) if beat > 0 else 0.0
                t0 = max(0.0, self.seconds(beat) + jitter)
                t1 = t0 + max(0.03, self.seconds(length))
                v = max(1, min(127, vel + self.rng.randint(-5, 5)))
                lines.append(f"{t0:.5f} N {p.channel} {key} {v}")
                lines.append(f"{t1:.5f} F {p.channel} {key}")
        return lines


# --- rendering ---------------------------------------------------------------

def reverb_ir(seconds: float, seed: int, damping: float = 5000.0) -> np.ndarray:
    """A stereo hall: early reflections, then a decorrelated noise tail that darkens as it fades."""
    rng = np.random.default_rng(seed)
    n = int(SR * seconds)
    t = np.arange(n) / SR
    ir = np.zeros((n, 2))
    for c in range(2):
        tail = rng.standard_normal(n)
        bright = signal.sosfilt(signal.butter(2, damping, "low", fs=SR, output="sos"), tail)
        dark = signal.sosfilt(signal.butter(2, damping * 0.25, "low", fs=SR, output="sos"), tail)
        decay = np.exp(-6.9 * t / seconds)
        mix = bright * np.exp(-6.9 * t / (seconds * 0.45)) + dark * decay
        mix[: int(SR * 0.02)] *= np.linspace(0, 1, int(SR * 0.02))
        pre = int(SR * 0.018)
        ir[pre:, c] = mix[: n - pre]
        for k in range(7):
            at = int(SR * rng.uniform(0.006, 0.05))
            ir[at, c] += rng.uniform(0.25, 0.6) * (1 if rng.random() > 0.5 else -1)
    ir /= np.sqrt(np.sum(ir ** 2, axis=0, keepdims=True))
    return ir


def render(score: Score, beats_total: float, bank: pathlib.Path, exe: pathlib.Path, reverb: float = 0.3,
           room: float = 2.6, tail: float = 6.0, seed: int = 1) -> np.ndarray:
    """Plays the score twice and keeps the second pass: its start already
    carries the first pass's ringing notes and reverb, and its end flows
    into the third — so the loop has no seam."""
    loop_s = score.seconds(beats_total)
    lines = score.events()
    twice = lines + [f"{float(l.split(' ', 1)[0]) + loop_s:.5f} {l.split(' ', 1)[1]}" for l in lines]
    with tempfile.TemporaryDirectory() as tmp:
        ev = pathlib.Path(tmp) / "ev.txt"
        raw = pathlib.Path(tmp) / "out.f32"
        ev.write_text("\n".join(twice) + "\n")
        subprocess.run([str(exe), str(bank), str(ev), str(raw), f"{2 * loop_s + tail:.3f}", str(SR)], check=True)
        dry = np.fromfile(raw, dtype=np.float32).reshape(-1, 2).astype(np.float64)
    ir = reverb_ir(room, seed)
    wet = np.stack([signal.fftconvolve(dry[:, c], ir[:, c])[: len(dry)] for c in range(2)], axis=1)
    mixed = dry * (1.0 - reverb * 0.5) + wet * reverb
    mixed = signal.sosfiltfilt(signal.butter(2, 32, "high", fs=SR, output="sos"), mixed, axis=0)
    n = int(round(SR * loop_s))
    return master(mixed[n:2 * n].copy())


def master(x: np.ndarray, target_rms_db: float = -19.0, ceiling: float = 0.89) -> np.ndarray:
    # A soft limiter; loudness matched across tracks (the low cut is done in render()).
    rms = np.sqrt(np.mean(x ** 2)) + 1e-9
    x = x * (10 ** (target_rms_db / 20) / rms)
    knee = 0.6
    over = np.abs(x) > knee
    x[over] = np.sign(x[over]) * (knee + (ceiling - knee) * np.tanh((np.abs(x[over]) - knee) / (ceiling - knee)))
    return x


def write_ogg(path: pathlib.Path, x: np.ndarray, quality: float = 4.0) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with tempfile.TemporaryDirectory() as tmp:
        raw = pathlib.Path(tmp) / "src.raw"
        pcm.tofile(raw)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "s16le", "-ar", str(SR), "-ac", "2", "-i", str(raw),
                        "-c:a", "libvorbis", "-q:a", str(quality), "-fflags", "+bitexact", "-map_metadata", "-1",
                        str(path)], check=True)


# --- accompaniment ------------------------------------------------------------

def bars_of(chart: str) -> list[list[str]]:
    """"D | G A | Bm" → [["D"], ["G", "A"], ["Bm"]] (a bar may hold several chords)."""
    return [bar.split() for bar in chart.split("|")]


def each_chord(chart, beats: int, start_bar: int = 0):
    """Yields (beat, length, symbol) over the chart."""
    for b, bar in enumerate(chart):
        step = beats / len(bar)
        for i, sym in enumerate(bar):
            yield (start_bar + b) * beats + i * step, step, sym


def pad(part: Part, chart, beats: int, start_bar: int, low: int, high: int, count: int, vel: int,
        breathe: bool = True) -> None:
    prev = None
    for beat, length, sym in each_chord(chart, beats, start_bar):
        _, tones = chord(sym)
        v = voice(tones, prev, low, high, count)
        prev = v
        part.notes_at(beat, v, length * 0.98 if breathe else length + 0.05, vel)


def bass(part: Part, chart, beats: int, start_bar: int, octave_low: int, pattern, vel: int) -> None:
    """pattern: [(beat in the chord, interval from root or 'fifth'/'octave', length)]."""
    for beat, length, sym in each_chord(chart, beats, start_bar):
        root, tones = chord(sym)
        r = in_range(root, octave_low, octave_low + 11)[0]
        for at, kind, dur in pattern:
            if at >= length:
                continue
            key = r + {"root": 0, "fifth": 7, "octave": 12, "third": (tones[1] - tones[0]) % 12}.get(kind, 0)
            part.note(beat + at, key, min(dur, length - at), vel + (6 if at == 0 else 0))


def arpeggio(part: Part, chart, beats: int, start_bar: int, low: int, figure, step: float, vel: int,
             length: float = 1.5) -> None:
    """figure: indices into the chord tones stacked up from `low` (0,1,2 = chord, 3.. next octave)."""
    for beat, chord_len, sym in each_chord(chart, beats, start_bar):
        root, tones = chord(sym)
        stack = []
        base = in_range(root, low, low + 11)[0]
        for octave in range(4):
            for pc in tones:
                n = base + ((pc - root) % 12) + 12 * octave
                if n not in stack:
                    stack.append(n)
        stack.sort()
        t = 0.0
        i = 0
        while t < chord_len - 1e-6:
            idx = figure[i % len(figure)]
            if idx is not None:
                part.note(beat + t, stack[min(idx, len(stack) - 1)], length, vel - (0 if i % len(figure) == 0 else 8))
            t += step
            i += 1


def counter(part: Part, chart, beats: int, start_bar: int, low: int, high: int, vel: int, seed: int) -> None:
    """A slow countermelody: one chord tone per half bar, moving stepwise when it can."""
    rng = random.Random(seed)
    prev = None
    for beat, length, sym in each_chord(chart, beats, start_bar):
        _, tones = chord(sym)
        halves = 2 if length >= 4 else 1
        for h in range(halves):
            options = sorted(n for pc in tones for n in in_range(pc, low, high))
            if prev is None:
                pick = options[len(options) // 2]
            else:
                near = sorted(options, key=lambda n: (abs(n - prev) == 0, abs(n - prev)))
                pick = near[0] if rng.random() < 0.75 else near[min(1, len(near) - 1)]
            prev = pick
            part.note(beat + h * length / halves, pick, length / halves * 0.97, vel)


# --- the tunes -------------------------------------------------------------------

# The Skyward theme (D major): the title, and in other keys in the meadow.
THEME_A = ("D5:1.5 E5:.5 F#5:1 A5:1 | G5:1.5 F#5:.5 E5:2 | B4:1 D5:1 E5:1 F#5:1 | A4:3 r:1 |"
           "D5:1.5 E5:.5 F#5:1 A5:1 | B5:1.5 A5:.5 G5:1 F#5:1 | E5:1 F#5:.5 G5:.5 A5:1 C#5:1 | D5:3 r:1")
THEME_A_CHART = "D | G | Bm | Asus4 A | D | G | Em7 A7 | D"
THEME_B = ("F#5:2 E5:1 D5:1 | C#5:1 D5:1 E5:2 | D5:1 E5:1 F#5:1 G5:1 | A5:3 r:1 |"
           "B5:2 A5:1 G5:1 | F#5:1 G5:1 A5:2 | G5:1 F#5:1 E5:1 C#5:1 | D5:4")
THEME_B_CHART = "Bm | A | G | D/F# A | Em | D | Em A7 | D"


def transpose(text: str, semis: int) -> str:
    names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    out = []
    for bar in text.split("|"):
        tokens = []
        for token in bar.split():
            name, sep, rest = token.partition(":")
            bang = "!" * name.count("!")
            name = name.replace("!", "")
            if name in ("r", "-"):
                tokens.append(token)
                continue
            p = pitch(name) + semis
            tokens.append(f"{names[p % 12]}{p // 12 - 1}{bang}{sep}{rest}")
        out.append(" ".join(tokens))
    return " | ".join(out)


def transpose_chart(chart: str, semis: int) -> str:
    names = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]

    def one(sym: str) -> str:
        parts = sym.split("/")
        res = []
        for s in parts:
            root = s[0]
            rest = s[1:]
            acc = 0
            if rest[:1] in ("#", "b"):
                acc = 1 if rest[0] == "#" else -1
                rest = rest[1:]
            res.append(names[(NAMES[root] + acc + semis) % 12] + rest)
        return "/".join(res)
    return " | ".join(" ".join(one(s) for s in bar.split()) for bar in chart.split("|"))


def title_track(s: Score) -> int:
    """Main title: the theme grows from harp and flute to the full orchestra."""
    b = s.beats
    harp = s.part("harp", 92, 40)
    strings = s.part("slowstrings", 92, 70)
    celli = s.part("cello", 88, 84)
    basses = s.part("contrabass", 80, 76)
    flute = s.part("flute", 96, 56)
    horn = s.part("horn", 96, 52)
    violins = s.part("strings", 92, 60)
    choir = s.part("choir", 86, 64)
    timp = s.part("timpani", 92, 72)
    perc = s.drums(DRUMS_ORCH, 90)
    glock = s.part("glock", 64, 90)
    intro = bars_of("D | G/D | D | Asus4 A")
    A, B = bars_of(THEME_A_CHART), bars_of(THEME_B_CHART)
    # Intro (bars 0–3).
    arpeggio(harp, intro, b, 0, 50, [0, 1, 2, 3, 4, 3, 2, 1], 0.5, 72)
    pad(strings, intro, b, 0, 57, 74, 3, 52)
    strings.swell(0, 16, 40, 100)
    bass(basses, intro, b, 0, 38, [(0, "root", 4)], 70)
    glock.note(12, pitch("A5"), 2, 60)
    glock.note(14, pitch("C#6"), 2, 55)
    # A on the flute, harp and strings (bars 4–11).
    flute.melody(4 * b, THEME_A, 84)
    arpeggio(harp, A, b, 4, 50, [0, 2, 3, 4, 5, 4, 3, 2], 0.5, 66)
    pad(strings, A, b, 4, 57, 74, 3, 56)
    bass(celli, A, b, 4, 38, [(0, "root", 2), (2, "fifth", 2)], 64)
    # B on the horn, the strings warm (bars 12–19).
    horn.melody(12 * b, THEME_B, 86, octave=-1)
    counter(flute, B, b, 12, 74, 86, 58, 3)
    pad(strings, B, b, 12, 55, 76, 4, 62)
    arpeggio(harp, B, b, 12, 50, [0, 1, 2, 3, 2, 1], 2 / 3, 60)
    bass(celli, B, b, 12, 38, [(0, "root", 3), (3, "fifth", 1)], 66)
    bass(basses, B, b, 12, 26, [(0, "root", 4)], 60)
    choir.swell(12 * b, 20 * b, 50, 100)
    pad(choir, B, b, 16, 57, 72, 3, 48)
    timp.note(19 * b + 2, pitch("A2"), 0.25, 70)
    timp.note(19 * b + 3, pitch("A2"), 0.25, 80)
    # A again — the whole orchestra (bars 20–27).
    violins.melody(20 * b, THEME_A, 92)
    violins.melody(20 * b, THEME_A, 78, octave=-1)
    counter(horn, A, b, 20, 57, 67, 74, 5)
    pad(strings, A, b, 20, 55, 74, 4, 70)
    pad(choir, A, b, 20, 57, 72, 3, 56)
    arpeggio(harp, A, b, 20, 50, [0, 2, 3, 4, 5, 4, 3, 2], 0.5, 64)
    bass(celli, A, b, 20, 38, [(0, "root", 1.5), (1.5, "fifth", 0.5), (2, "octave", 2)], 72)
    bass(basses, A, b, 20, 26, [(0, "root", 4)], 70)
    for bar in range(20, 28):
        timp.note(bar * b, in_range(chord(A[bar - 20][0])[0], 38, 49)[0], 1, 76 if bar % 2 == 0 else 62)
        perc.note(bar * b, BD2, 1, 50)
    perc.note(20 * b, SUS_CYM, 4, 70)
    # Outro back to the start (bars 28–31).
    outro = bars_of("G | Em7 | Asus4 | A")
    pad(strings, outro, b, 28, 55, 74, 4, 60)
    strings.swell(28 * b, 32 * b, 100, 50)
    arpeggio(harp, outro, b, 28, 50, [0, 1, 2, 3, 4, 5, 6, 7], 0.5, 60)
    flute.melody(28 * b, "B5:2 A5:2 | G5:2 E5:2 | E5:2 D5:2 | C#5:3 r:1", 70)
    bass(celli, outro, b, 28, 38, [(0, "root", 4)], 60)
    return 32


def meadow_track(s: Score) -> int:
    """Village and meadows (G): the theme on a folk band, then a tune of its own."""
    b = s.beats
    guitar = s.part("nylon", 80, 46)
    flute = s.part("flute", 112, 72)
    fiddle = s.part("violin", 104, 58)
    oboe = s.part("oboe", 108, 70)
    bassp = s.part("acbass", 92, 64)
    strings = s.part("slowstrings", 72, 84)
    pizz = s.part("pizz", 70, 30)
    perc = s.drums(DRUMS_STD, 70)
    accordion = s.part("accordion", 50, 92)
    A = bars_of(transpose_chart(THEME_A_CHART, 5))
    tune = ("E5:1 D5:.5 C5:.5 E5:1 G5:1 | D5:2 B4:1 G4:1 | A4:1 B4:.5 C5:.5 E5:1 C5:1 | D5:3 r:1 |"
            "B4:1 C5:.5 D5:.5 E5:1 G5:1 | A5:1 G5:.5 E5:.5 C5:2 | D5:1 E5:.5 F#5:.5 A5:1 F#5:1 | G5:3 r:1")
    T = bars_of("C | G | Am | D | Em | C | D | G")
    sections = [(0, A, transpose(THEME_A, 5), flute, -1), (8, T, tune, oboe, 0),
                (16, A, transpose(THEME_A, 5), fiddle, 0), (24, T, tune, flute, 0)]
    for start, chart, mel, lead, octv in sections:
        lead.melody(start * b, mel, 88, octave=octv)
        arpeggio(guitar, chart, b, start, 43, [0, 2, 1, 2, 3, 2, 1, 2], 0.5, 70)
        bass(bassp, chart, b, start, 31, [(0, "root", 1), (2, "fifth", 1), (3.5, "octave", 0.5)], 72)
        for bar in range(start, start + 8):
            for beat in range(4):
                perc.note(bar * b + beat + 0.5, SHAKER, 0.25, 46)
                perc.note(bar * b + beat, SHAKER, 0.25, 36)
            perc.note(bar * b + 1, TAMB, 0.25, 30)
            perc.note(bar * b + 3, TAMB, 0.25, 30)
    pad(strings, A, b, 16, 55, 71, 3, 50)
    pad(strings, T, b, 24, 55, 71, 3, 50)
    counter(fiddle, T, b, 24, 62, 74, 56, 11)
    pad(accordion, T, b, 8, 55, 67, 3, 46)
    for bar in range(16, 24):
        pizz.note(bar * b + 1, in_range(chord(A[bar - 16][0])[1][1], 62, 73)[0], 0.5, 52)
        pizz.note(bar * b + 3, in_range(chord(A[bar - 16][0])[1][2], 62, 73)[0], 0.5, 48)
    return 32


def night_track(s: Score) -> int:
    """Night grove (A minor): a music box over strings, a cello sings the second half."""
    b = s.beats
    box = s.part("celesta", 127, 50)
    harp = s.part("harp", 66, 76)
    strings = s.part("slowstrings", 84, 64)
    cello = s.part("cello", 92, 58)
    basses = s.part("contrabass", 70, 70)
    flute = s.part("flute", 74, 44)
    glass = s.part("glass", 52, 80)
    A = bars_of("Am | F | C | G | Dm | Am | E | E")
    Bc = bars_of("F | G | Em | Am | Dm | G | C | E")
    mel_a = ("E5:1 A5:1 C6:1 B5:1 | A5:2 G5:1 F5:1 | E5:1 G5:1 C6:2 | B5:2 D5:2 |"
             "F5:1 A5:1 D6:1 C6:1 | B5:1 A5:1 E5:2 | G#5:1 B5:1 E5:1 D5:1 | E5:3 r:1")
    mel_b = ("C6:2 A5:1 F5:1 | D6:2 B5:1 G5:1 | B5:1 G5:1 E5:2 | C6:1 B5:1 A5:2 |"
             "F5:1 A5:1 D6:2 | B5:1 G5:1 D5:2 | E5:1 G5:1 C6:2 | B5:2 G#5:2")
    for start, chart, mel in [(0, A, mel_a), (8, Bc, mel_b), (16, A, mel_a), (24, Bc, mel_b)]:
        second = start >= 16
        if second:
            cello.melody(start * b, mel, 84, octave=-2)
            box.melody(start * b, mel, 52)
        else:
            box.melody(start * b, mel, 96)
        pad(strings, chart, b, start, 52, 69, 3, 50 if not second else 58)
        arpeggio(harp, chart, b, start, 45, [0, 1, 2, 3, 2, 1, None, None], 0.5, 52)
        bass(basses, chart, b, start, 28, [(0, "root", 4)], 58)
    counter(flute, Bc, b, 24, 69, 81, 46, 7)
    pad(glass, Bc, b, 8, 64, 79, 2, 40)
    strings.swell(0, 32 * b, 90, 110)
    return 32


def caves_track(s: Score) -> int:
    """Crystal caves (D dorian): sparse crystal notes, a low choir, drops of harp."""
    b = s.beats
    vibes = s.part("vibes", 127, 46)
    choir = s.part("oohs", 70, 64)
    drone = s.part("contrabass", 64, 64)
    celli = s.part("cello", 70, 74)
    harp = s.part("harp", 66, 86)
    flute = s.part("flute", 68, 40)
    glass = s.part("glass", 54, 92)
    timp = s.part("timpani", 62, 60)
    A = bars_of("Dm | C | Dm | Am | Dm | G | Em | A")
    mel = ("A5:1.5 F5:.5 D5:2 | E5:1 G5:1 C6:2 | D6:1 C6:.5 A5:.5 F5:2 | E5:4 |"
           "F5:1 A5:1 D6:1.5 E6:.5 | D6:1 B5:1 G5:2 | B5:1 G5:1 E5:1 G5:1 | A5:4")
    for rep in range(4):
        start = rep * 8
        if rep in (0, 2):
            vibes.melody(start * b, mel, 100 if rep == 0 else 92)
        else:
            flute.melody(start * b, mel, 62, octave=-1)
            vibes.melody(start * b + 0.5, mel, 58, octave=1)
        pad(choir, A, b, start, 50, 65, 3, 46 if rep < 2 else 56)
        bass(drone, A, b, start, 26, [(0, "root", 4)], 56)
        if rep >= 1:
            pad(celli, A, b, start, 38, 52, 2, 46)
        arpeggio(harp, A, b, start, 62, [None, 4, None, 3, None, None, 5, None], 0.5, 40)
        timp.note(start * b, pitch("D2"), 1.5, 40)
    pad(glass, A, b, 16, 69, 81, 2, 34)
    choir.swell(0, 32 * b, 80, 110)
    return 32


def sky_track(s: Score) -> int:
    """Sky islands (F lydian, C major): airy strings, harp in flight, flute and oboe."""
    b = s.beats
    harp = s.part("harp", 74, 42)
    celesta = s.part("celesta", 80, 88)
    strings = s.part("slowstrings", 74, 66)
    violins = s.part("strings", 100, 56)
    flute = s.part("flute", 110, 52)
    oboe = s.part("oboe", 106, 76)
    horn = s.part("horn", 72, 60)
    celli = s.part("cello", 80, 80)
    basses = s.part("contrabass", 70, 70)
    choir = s.part("choir", 56, 64)
    perc = s.drums(DRUMS_ORCH, 70)
    A = bars_of("F | G | Em | Am | F | G | C | C")
    Bc = bars_of("Dm | Em | F | G | Am | Em | F | G")
    mel_a = ("A5:1 C6:1 E6:1.5 D6:.5 | D6:2 B5:1 G5:1 | B5:1 G5:.5 A5:.5 B5:1 E5:1 | A5:3 r:1 |"
             "C6:1 D6:.5 C6:.5 A5:1 F5:1 | G5:1 A5:.5 B5:.5 D6:1 G6:1 | E6:1 D6:1 C6:1 G5:1 | C6:3 r:1")
    mel_b = ("F5:1 A5:1 D6:2 | E6:1 D6:.5 B5:.5 G5:2 | A5:1 C6:1 F6:1.5 E6:.5 | D6:2 B5:2 |"
             "C6:1 E6:1 A6:1.5 G6:.5 | E6:1 D6:.5 E6:.5 B5:2 | A5:1 C6:1 F6:1 E6:1 | D6:2 G5:2")
    for start, chart, mel, lead in [(0, A, mel_a, flute), (8, Bc, mel_b, oboe), (16, A, mel_a, violins), (24, Bc, mel_b, flute)]:
        lead.melody(start * b, mel, 86 if lead is not violins else 84, octave=-1 if lead is oboe else 0)
        arpeggio(harp, chart, b, start, 48, [0, 1, 2, 3, 4, 5, 4, 3], 0.25 if start >= 16 else 0.5, 60)
        pad(strings, chart, b, start, 55, 74, 4, 54 if start < 16 else 64)
        bass(celli, chart, b, start, 36, [(0, "root", 2), (2, "fifth", 2)], 58)
        bass(basses, chart, b, start, 28, [(0, "root", 4)], 54)
        for bar in range(start, start + 8):
            perc.note(bar * b, TRIANGLE, 0.5, 34 if start < 16 else 44)
    counter(horn, A, b, 16, 55, 67, 60, 21)
    pad(choir, Bc, b, 24, 57, 72, 3, 46)
    celesta.melody(16 * b + 0.5, mel_a, 34, octave=1)
    perc.note(16 * b, SUS_CYM, 4, 56)
    return 32


def coast_track(s: Score) -> int:
    """Salt coast (D mixolydian, 3/4): a sea song — whistle, fiddle, guitar, accordion."""
    b = s.beats
    guitar = s.part("nylon", 90, 48)
    whistle = s.part("panflute", 90, 70)
    fiddle = s.part("fiddle", 82, 56)
    accordion = s.part("accordion", 64, 86)
    bassp = s.part("acbass", 90, 64)
    perc = s.drums(DRUMS_STD, 72)
    cello = s.part("cello", 70, 78)
    A = bars_of("D | C | G | D | D | C | G | D")
    Bc = bars_of("Bm | G | C | D | Bm | G | C | D")
    mel_a = ("A4:1 D5:1 F#5:1 | E5:2 C5:1 | D5:1 B4:1 G4:1 | A4:3 |"
             "A4:1 D5:1 F#5:1 | G5:1 E5:1 C5:1 | B4:1 C5:1 D5:1 | D5:3")
    mel_b = ("F#5:1 D5:1 B4:1 | G5:2 D5:1 | E5:1 G5:1 C6:1 | A5:3 |"
             "B5:1 A5:1 F#5:1 | G5:1 D5:1 B4:1 | C5:1 E5:1 G5:1 | F#5:2 r:1")
    for rep in range(2):
        base = rep * 16
        whistle.melody(base * b, mel_a, 84)
        fiddle.melody((base + 8) * b, mel_b, 82)
        if rep == 1:
            fiddle.melody(base * b, mel_a, 56, octave=-1)
            whistle.melody((base + 8) * b, mel_b, 60, octave=1)
            pad(cello, A + Bc, b, base, 45, 57, 2, 50)
        for start, chart in [(base, A), (base + 8, Bc)]:
            arpeggio(guitar, chart, b, start, 47, [0, 2, 3, 1, 2, 3], 0.5, 66)
            bass(bassp, chart, b, start, 33, [(0, "root", 1), (2, "fifth", 1)], 72)
            pad(accordion, chart, b, start, 57, 69, 3, 40 if rep == 0 else 50)
            for bar in range(start, start + 8):
                perc.note(bar * b, TAMB, 0.25, 40)
                perc.note(bar * b + 1.5, SHAKER, 0.25, 38)
                perc.note(bar * b + 2, SHAKER, 0.25, 34)
    return 32


def marsh_track(s: Score) -> int:
    """Misty marsh (E harmonic minor): clarinet and bassoon, pizzicato steps in the fog."""
    b = s.beats
    clar = s.part("clarinet", 90, 52)
    bassoon = s.part("bassoon", 82, 76)
    pizz = s.part("pizz", 84, 40)
    strings = s.part("slowstrings", 70, 72)
    basses = s.part("contrabass", 70, 64)
    glass = s.part("glass", 48, 90)
    perc = s.drums(DRUMS_ORCH, 66)
    harp = s.part("harp", 60, 30)
    A = bars_of("Em | Am | B | Em | C | Am | B | B7")
    mel = ("E5:1.5 G5:.5 B5:1 G5:1 | A5:1 C6:1 B5:1 A5:1 | D#5:1 F#5:1 B5:2 | E5:3 r:1 |"
           "G5:1.5 E5:.5 C5:1 E5:1 | A5:1 G5:.5 F#5:.5 E5:1 C5:1 | B4:1 D#5:1 F#5:1 A5:1 | G5:1 F#5:1 D#5:2")
    for rep in range(4):
        start = rep * 8
        if rep == 1:
            bassoon.melody(start * b, mel, 80, octave=-2)
        elif rep == 3:
            clar.melody(start * b, mel, 82)
            bassoon.melody(start * b, mel, 58, octave=-2)
        else:
            clar.melody(start * b, mel, 84, octave=-1 if rep == 2 else 0)
        bass(pizz, A, b, start, 40, [(0, "root", 0.5), (1, "fifth", 0.5), (2, "octave", 0.5), (3, "fifth", 0.5)], 64)
        pad(strings, A, b, start, 52, 67, 3, 44 + rep * 4)
        bass(basses, A, b, start, 28, [(0, "root", 4)], 50)
        for bar in range(start, start + 8, 2):
            perc.note(bar * b, BD2, 1, 40)
        arpeggio(harp, A, b, start, 64, [None, None, None, 2, None, None, 1, None], 0.5, 36)
    pad(glass, A, b, 8, 71, 83, 2, 32)
    pad(glass, A, b, 24, 71, 83, 2, 36)
    return 32


def ash_track(s: Score) -> int:
    """Ash waste and the forge (C minor): low brass, driving strings, taiko."""
    b = s.beats
    horns = s.part("horn", 96, 52)
    trombones = s.part("trombone", 86, 72)
    strings = s.part("strings", 90, 60)
    celli = s.part("cello", 92, 80)
    basses = s.part("contrabass", 84, 70)
    taiko = s.part("taiko", 88, 64)
    perc = s.drums(DRUMS_ORCH, 88)
    choir = s.part("choir", 64, 64)
    timp = s.part("timpani", 84, 66)
    A = bars_of("Cm | Cm | Ab | Bb | Cm | Cm | Ab | G")
    mel = ("C4:1.5 Eb4:.5 G4:2 | F4:1 Eb4:1 D4:1 C4:1 | Eb4:1.5 F4:.5 Ab4:2 | G4:1 F4:1 D4:2 |"
           "C4:1.5 Eb4:.5 G4:1 C5:1 | Bb4:1 G4:1 Ab4:1 G4:1 | F4:1 Ab4:1 C5:2 | B3:2 D4:2")
    for rep in range(4):
        start = rep * 8
        if rep >= 1:
            horns.melody(start * b, mel, 86 + (8 if rep == 3 else 0), octave=1)
        if rep >= 2:
            trombones.melody(start * b, mel, 78)
        # Ostinato in eighths: root, root, fifth, root, octave...
        arpeggio(celli, A, b, start, 36, [0, 0, 1, 0, 3, 0, 1, 0], 0.5, 70, 0.4)
        if rep >= 1:
            arpeggio(strings, A, b, start, 60, [0, 1, 2, 1, 3, 2, 1, 2], 0.5, 58, 0.4)
        bass(basses, A, b, start, 24, [(0, "root", 2), (2, "root", 2)], 68)
        for bar in range(start, start + 8):
            taiko.note(bar * b, pitch("C3"), 0.5, 90)
            taiko.note(bar * b + 1.5, pitch("C3"), 0.5, 64)
            taiko.note(bar * b + 2, pitch("G2"), 0.5, 78)
            if rep >= 2:
                taiko.note(bar * b + 3.5, pitch("G2"), 0.25, 58)
                perc.note(bar * b + 3, SNARE, 0.25, 40)
        if rep == 3:
            pad(choir, A, b, start, 55, 70, 3, 60)
        timp.note((start + 7) * b + 2, pitch("G2"), 0.25, 72)
        timp.note((start + 7) * b + 2.5, pitch("G2"), 0.25, 76)
        timp.note((start + 7) * b + 3, pitch("G2"), 0.5, 84)
    perc.note(16 * b, CRASH, 2, 60)
    return 32


def rift_track(s: Score) -> int:
    """Shattered island and the rifts (E phrygian): voices, glass, a lonely English horn."""
    b = s.beats
    choir = s.part("choir", 72, 60)
    glass = s.part("glass", 62, 80)
    piano = s.part("piano", 70, 44)
    ehorn = s.part("ehorn", 90, 56)
    basses = s.part("contrabass", 76, 66)
    strings = s.part("tremolo", 56, 76)
    harp = s.part("harp", 60, 90)
    timp = s.part("timpani", 60, 64)
    A = bars_of("Em | F | Em | Dm | Em | F | G | F")
    mel = ("B4:2 G4:1 E4:1 | F4:2 A4:1 C5:1 | B4:1.5 A4:.5 G4:2 | F4:1 E4:1 D4:2 |"
           "E4:1 G4:1 B4:2 | C5:1.5 B4:.5 A4:2 | B4:1 D5:1 G4:2 | A4:2 F4:1 E4:1")
    for rep in range(4):
        start = rep * 8
        if rep in (1, 3):
            ehorn.melody(start * b, mel, 82 if rep == 1 else 76, octave=1 if rep == 3 else 0)
        pad(choir, A, b, start, 52, 67, 3, 44 + rep * 5)
        pad(glass, A, b, start, 64, 76, 2, 36)
        bass(basses, A, b, start, 28, [(0, "root", 4)], 56)
        for bar in range(start, start + 8):
            root = in_range(chord(A[bar - start][0])[0], 28, 39)[0]
            piano.note(bar * b, root, 3, 46)
            piano.note(bar * b + 2.5, root + 19, 1, 30)
        if rep >= 2:
            pad(strings, A, b, start, 64, 79, 2, 40)
        arpeggio(harp, A, b, start, 64, [None, 3, None, None, 4, None, None, 2], 0.5, 34)
        timp.note(start * b, pitch("E2"), 2, 44)
    return 32


def boss_track(s: Score) -> int:
    """Boss (E minor, 150): string ostinato, brass, choir, timpani and drums."""
    b = s.beats
    strings = s.part("strings", 96, 58)
    celli = s.part("cello", 96, 82)
    basses = s.part("contrabass", 90, 70)
    trumpets = s.part("trumpet", 90, 50)
    horns = s.part("horn", 92, 70)
    trombones = s.part("trombone", 88, 78)
    choir = s.part("choir", 80, 64)
    timp = s.part("timpani", 96, 66)
    perc = s.drums(DRUMS_ORCH, 96)
    hits = s.part("orchhit", 56, 64)
    A = bars_of("Em | Em | C | D | Em | Em | C | B")
    Bc = bars_of("Am | Em | C | B | Am | Em | C | B7")
    mel_a = ("E5:1.5 B4:.5 E5:1 G5:1 | F#5:1.5 E5:.5 D5:1 B4:1 | C5:1.5 E5:.5 G5:1 C6:1 | B5:1 A5:1 F#5:2 |"
             "E5:1.5 B4:.5 E5:1 G5:1 | B5:1.5 A5:.5 G5:1 F#5:1 | E5:1 G5:1 C6:1 E6:1 | D#6:2 B5:2")
    mel_b = ("A5:2 C6:1 B5:1 | G5:2 E5:2 | E5:1 F#5:1 G5:1 A5:1 | B5:4 |"
             "C6:2 B5:1 A5:1 | B5:2 G5:2 | A5:1 G5:1 F#5:1 E5:1 | D#5:2 F#5:2")
    for rep in range(2):
        for start, chart, mel in [(rep * 16, A, mel_a), (rep * 16 + 8, Bc, mel_b)]:
            lead = horns if (start // 8) % 2 == 0 and rep == 0 else trumpets
            lead.melody(start * b, mel, 92, octave=-1 if lead is horns else 0)
            if rep == 1:
                horns.melody(start * b, mel, 80, octave=-1) if lead is not horns else None
                pad(choir, chart, b, start, 55, 72, 3, 64)
            arpeggio(strings, chart, b, start, 52, [0, 3, 1, 3, 2, 3, 1, 3], 0.5, 72, 0.4)
            arpeggio(celli, chart, b, start, 40, [0, 0, 3, 0, 0, 3, 1, 2], 0.5, 76, 0.4)
            bass(basses, chart, b, start, 28, [(0, "root", 1.5), (1.5, "root", 0.5), (2, "root", 2)], 74)
            pad(trombones, chart, b, start, 45, 57, 2, 54 if rep == 0 else 66)
            for bar in range(start, start + 8):
                timp.note(bar * b, in_range(chord(chart[bar - start][0])[0], 40, 51)[0], 0.5, 84)
                timp.note(bar * b + 2.5, in_range(chord(chart[bar - start][0])[0], 40, 51)[0], 0.5, 70)
                perc.note(bar * b, BD2, 0.5, 70)
                perc.note(bar * b + 1, SNARE, 0.25, 54)
                perc.note(bar * b + 3, SNARE, 0.25, 58)
                perc.note(bar * b + 3.5, SNARE, 0.25, 40)
            perc.note(start * b, CRASH, 2, 66)
            hits.note(start * b, in_range(chord(chart[0][0])[0], 52, 63)[0], 0.5, 70)
    return 32


TRACKS = {
    # name: (bpm, beats per bar, builder, reverb mix, hall seconds, seed)
    "title": (80, 4, title_track, 0.34, 3.0, 11),
    "meadow": (100, 4, meadow_track, 0.24, 1.8, 12),
    "night": (66, 4, night_track, 0.36, 3.2, 13),
    "caves": (58, 4, caves_track, 0.44, 4.0, 14),
    "sky": (88, 4, sky_track, 0.34, 3.0, 15),
    "coast": (112, 3, coast_track, 0.22, 1.6, 16),
    "marsh": (70, 4, marsh_track, 0.32, 2.6, 17),
    "ash": (100, 4, ash_track, 0.28, 2.4, 18),
    "rift": (60, 4, rift_track, 0.42, 4.0, 19),
    "boss": (150, 4, boss_track, 0.22, 2.0, 20),
}


def build(name: str, bank: pathlib.Path, exe: pathlib.Path) -> np.ndarray:
    bpm, beats, builder, mix, room, seed = TRACKS[name]
    score = Score(bpm, beats, seed)
    bars = builder(score)
    return render(score, bars * beats, bank, exe, mix, room, tail=room + 3.0, seed=seed)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", default="", help="comma list of tracks")
    parser.add_argument("--keep-wav", action="store_true", help="also write .wav previews into tools/audio/.cache")
    args = parser.parse_args()
    bank, exe = ensure_tools()
    wanted = [n for n in args.only.split(",") if n] or list(TRACKS)
    for name in wanted:
        x = build(name, bank, exe)
        write_ogg(OUT / "music" / f"{name}.ogg", x)
        if args.keep_wav:
            pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
            import wave
            with wave.open(str(CACHE / f"{name}.wav"), "wb") as w:
                w.setnchannels(2)
                w.setsampwidth(2)
                w.setframerate(SR)
                w.writeframes(pcm.tobytes())
        peak = float(np.max(np.abs(x)))
        print(f"  music/{name}.ogg  {len(x) / SR:5.1f} s  peak {peak:.2f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
