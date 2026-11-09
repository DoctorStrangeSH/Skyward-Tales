#!/usr/bin/env python3
"""Generates all Skyward Tales sound effects and music from code.

Usage: python3 tools/audio/build_audio.py [--only sfx|music]
Writes assets/audio/sfx/*.wav and assets/audio/music/*.ogg (needs ffmpeg with
libvorbis). Deterministic: the same seeds always give the same sounds.
"""
from __future__ import annotations

import argparse
import pathlib
import random
import subprocess
import tempfile
import wave

import numpy as np
from scipy import signal

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "audio"
SR = 22050


# --- primitives -------------------------------------------------------------

def t_axis(seconds: float) -> np.ndarray:
    return np.arange(int(SR * seconds)) / SR


def osc(kind: str, freq, seconds: float, duty: float = 0.5) -> np.ndarray:
    t = t_axis(seconds)
    f = np.broadcast_to(np.asarray(freq, dtype=float), t.shape)
    phase = np.cumsum(f) / SR
    frac = phase % 1.0
    if kind == "sine":
        return np.sin(2 * np.pi * phase)
    if kind == "square":
        return np.where(frac < duty, 1.0, -1.0) * 0.6
    if kind == "triangle":
        return 2 * np.abs(2 * frac - 1) - 1
    if kind == "saw":
        return (2 * frac - 1) * 0.6
    raise ValueError(kind)


def noise(seconds: float, seed: int) -> np.ndarray:
    return np.random.default_rng(seed).uniform(-1, 1, int(SR * seconds))


def env(n: int, attack: float = 0.005, release: float = 0.1, curve: float = 2.0) -> np.ndarray:
    """Attack then exponential-ish decay over the whole length."""
    a = max(1, int(SR * attack))
    e = np.ones(n)
    e[:a] = np.linspace(0, 1, a)
    tail = np.linspace(1, 0, n - a) ** curve
    e[a:] = tail
    r = min(n, int(SR * release))
    if r > 1:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def lowpass(x: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    b, a = signal.butter(order, min(cutoff / (SR / 2), 0.99), "low")
    return signal.lfilter(b, a, x)


def highpass(x: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    b, a = signal.butter(order, min(cutoff / (SR / 2), 0.99), "high")
    return signal.lfilter(b, a, x)


def bandpass(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    b, a = signal.butter(2, [lo / (SR / 2), min(hi / (SR / 2), 0.99)], "band")
    return signal.lfilter(b, a, x)


def sweep_lowpass(x: np.ndarray, start: float, end: float, steps: int = 24) -> np.ndarray:
    """Piecewise low-pass with a moving cutoff (cheap filter sweep)."""
    out = np.zeros_like(x)
    chunks = np.array_split(np.arange(len(x)), steps)
    for i, idx in enumerate(chunks):
        cutoff = start + (end - start) * i / max(1, steps - 1)
        out[idx] = lowpass(x, cutoff)[idx]
    return out


def echo(x: np.ndarray, delay: float, feedback: float, repeats: int = 4) -> np.ndarray:
    d = int(SR * delay)
    out = np.concatenate([x, np.zeros(d * repeats)])
    for k in range(1, repeats + 1):
        out[d * k:d * k + len(x)] += x * feedback ** k
    return out


def place(buf: np.ndarray, sound: np.ndarray, at: float) -> None:
    i = int(at * SR)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(sound))
    buf[i:j] += sound[: j - i]


def note_hz(midi: float) -> float:
    return 440.0 * 2 ** ((midi - 69) / 12)


def normalize(x: np.ndarray, peak: float = 0.85) -> np.ndarray:
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def write_wav(path: pathlib.Path, x: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def write_ogg(path: pathlib.Path, x: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        src = pathlib.Path(tmp) / "src.wav"
        write_wav(src, x)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(src), "-c:a", "libvorbis",
                        "-q:a", "3", "-fflags", "+bitexact", "-map_metadata", "-1", str(path)], check=True)


# --- sound effects ------------------------------------------------------------

def sfx_hit():
    n = noise(0.09, 1)
    body = osc("sine", np.linspace(160, 60, int(SR * 0.09)), 0.09)
    x = lowpass(n, 2600) * 0.7 + body
    return x * env(len(x), 0.001, 0.02, 3)


def sfx_enemy_die():
    s = 0.32
    tone = osc("square", np.linspace(520, 90, int(SR * s)), s, 0.3)
    puff = lowpass(noise(s, 2), 1800)
    x = lowpass(tone, 2400) * 0.6 + puff * 0.5
    return x * env(len(x), 0.002, 0.05, 2)


def sfx_hurt():
    s = 0.18
    x = lowpass(osc("square", np.linspace(300, 120, int(SR * s)), s, 0.4), 1600)
    x += lowpass(noise(s, 3), 900) * 0.4
    return x * env(len(x), 0.002, 0.03, 1.5)


def sfx_cast_fire():
    s = 0.34
    whoosh = sweep_lowpass(noise(s, 4), 400, 3400)
    crackle = (np.random.default_rng(5).random(int(SR * s)) > 0.985) * np.random.default_rng(6).uniform(-1, 1, int(SR * s))
    roar = osc("saw", np.linspace(110, 70, int(SR * s)), s)
    x = whoosh * 0.9 + crackle * 0.6 + lowpass(roar, 600) * 0.5
    return x * env(len(x), 0.02, 0.1, 1.6)


def sfx_cast_ice():
    s = 0.42
    x = np.zeros(int(SR * s))
    for k, midi in enumerate([88, 95, 91, 100]):
        tone = osc("sine", note_hz(midi), 0.2) * env(int(SR * 0.2), 0.001, 0.05, 3)
        place(x, tone * 0.5, k * 0.045)
    x += highpass(noise(s, 7), 5000) * 0.12 * env(int(SR * s), 0.01, 0.1, 2)
    return echo(x, 0.06, 0.35, 3)


def sfx_cast_lightning():
    s = 0.3
    t = t_axis(s)
    buzz = osc("square", 60 + 40 * np.sin(2 * np.pi * 37 * t), s, 0.2)
    zap = highpass(noise(s, 8), 1800) * (np.random.default_rng(9).random(len(t)) > 0.6)
    x = lowpass(buzz, 3000) * 0.5 + zap * 0.6
    return x * env(len(x), 0.001, 0.05, 1.3)


def sfx_dash():
    s = 0.22
    x = bandpass(noise(s, 10), 600, 3500)
    shape = np.sin(np.linspace(0, np.pi, len(x))) ** 1.5
    return x * shape


def _arp(notes, step, length, wave_kind="square", duty=0.25, vol=0.5):
    total = step * (len(notes) - 1) + length
    x = np.zeros(int(SR * total) + 1)
    for k, midi in enumerate(notes):
        tone = lowpass(osc(wave_kind, note_hz(midi), length, duty), 4000)
        place(x, tone * env(len(tone), 0.003, 0.05, 1.8) * vol, k * step)
    return x


def sfx_pickup():
    return _arp([84, 91], 0.06, 0.12)


def sfx_chest():
    return echo(_arp([72, 76, 79, 84, 88], 0.07, 0.22), 0.09, 0.3, 3)


def sfx_level_up():
    x = _arp([72, 76, 79, 84, 79, 84, 88, 91], 0.075, 0.3, vol=0.45)
    x += np.concatenate([np.zeros(int(SR * 0.53)), _arp([84, 88, 91, 96], 0.0, 0.6, "triangle", vol=0.3)])[: len(x)]
    return echo(x, 0.11, 0.3, 3)


def sfx_quest():
    return echo(_arp([79, 84, 88], 0.12, 0.45, "triangle", vol=0.6), 0.13, 0.3, 3)


def sfx_travel():
    s = 0.6
    x = sweep_lowpass(noise(s, 11), 300, 2600, 30) * np.sin(np.linspace(0, np.pi, int(SR * s)))
    shimmer = osc("sine", np.linspace(600, 1400, int(SR * s)), s) * 0.15 * env(int(SR * s), 0.2, 0.2, 1)
    return x + shimmer


def sfx_boss_roar():
    s = 1.0
    t = t_axis(s)
    base = 55 * (1 + 0.06 * np.sin(2 * np.pi * 6 * t))
    x = lowpass(osc("saw", base, s) + osc("saw", base * 1.5, s) * 0.5, 900)
    x += lowpass(noise(s, 12), 500) * 0.5
    return x * env(len(x), 0.08, 0.3, 1.2)


def sfx_gust():
    s = 0.7
    x = bandpass(noise(s, 13), 300, 1600)
    return x * np.sin(np.linspace(0, np.pi, len(x))) ** 2


def sfx_ui():
    tone = osc("square", 1320, 0.035, 0.25)
    return lowpass(tone, 5000) * env(len(tone), 0.001, 0.01, 2) * 0.5


SFX = {
    "hit": sfx_hit, "enemy_die": sfx_enemy_die, "hurt": sfx_hurt,
    "cast_fire": sfx_cast_fire, "cast_ice": sfx_cast_ice, "cast_lightning": sfx_cast_lightning,
    "dash": sfx_dash, "pickup": sfx_pickup, "chest": sfx_chest, "level_up": sfx_level_up,
    "quest": sfx_quest, "travel": sfx_travel, "boss_roar": sfx_boss_roar, "gust": sfx_gust, "ui": sfx_ui,
}


# --- music --------------------------------------------------------------------

class Track:
    """Tiny sequencer: chords per bar, bass, arpeggio/pad and a melody."""

    def __init__(self, bpm: float, bars: int, beats: int = 4):
        self.beat = 60.0 / bpm
        self.bars = bars
        self.beats = beats
        self.length = self.beat * beats * bars
        self.buf = np.zeros(int(SR * self.length) + SR * 2)

    def bar_time(self, bar: int, beat: float = 0.0) -> float:
        return (bar * self.beats + beat) * self.beat

    def note(self, midi: float, at: float, dur: float, kind: str, vol: float, duty: float = 0.5,
             attack: float = 0.01, cutoff: float = 3000, curve: float = 1.5) -> None:
        tone = osc(kind, note_hz(midi), dur, duty)
        tone = lowpass(tone, cutoff) if cutoff else tone
        place(self.buf, tone * env(len(tone), attack, min(0.08, dur * 0.3), curve) * vol, at)

    def drum(self, kind: str, at: float, vol: float, seed: int) -> None:
        if kind == "kick":
            s = 0.18
            x = osc("sine", np.linspace(130, 45, int(SR * s)), s) * env(int(SR * s), 0.001, 0.03, 2.5)
        elif kind == "snare":
            s = 0.16
            x = bandpass(noise(s, seed), 900, 5000) * env(int(SR * s), 0.001, 0.03, 2.5)
        else:
            s = 0.05
            x = highpass(noise(s, seed), 6000) * env(int(SR * s), 0.001, 0.01, 3)
        place(self.buf, x * vol, at)

    def render(self, reverb: float = 0.25, delay: float = 0.3) -> np.ndarray:
        x = self.buf
        wet = echo(x, delay, reverb, 3)[: len(x)]
        x = x * 0.8 + wet * 0.5
        # Fold the tail back to the start so the loop is seamless.
        n = int(SR * self.length)
        loop = x[:n].copy()
        tail = x[n:]
        loop[: len(tail)] += tail[: n]
        fade = min(len(loop), SR // 50)
        loop[-fade:] *= np.linspace(1, 0.98, fade)
        return normalize(loop, 0.7)


def chord_tones(root: int, quality: str) -> list[int]:
    return [root, root + (3 if quality == "m" else 4), root + 7]


def melody(track: Track, progression, scale, rng: random.Random, octave: int, kind: str, vol: float,
           density: float, cutoff: float, duty: float = 0.5) -> None:
    """Chord tones on strong beats, stepwise scale motion between them."""
    current = progression[0][0] + octave
    for bar, (root, quality) in enumerate(progression):
        tones = [t + octave for t in chord_tones(root, quality)]
        beat = 0.0
        while beat < track.beats:
            if rng.random() < density or beat == 0:
                strong = beat % 2 == 0
                if strong:
                    current = min(tones + [t + 12 for t in tones], key=lambda t: abs(t - current) + rng.random() * 3)
                else:
                    pool = [s + octave + 12 * k for s in scale for k in (-1, 0, 1)]
                    near = sorted(pool, key=lambda t: abs(t - current))[1:4]
                    current = rng.choice(near)
                length = rng.choice([0.5, 1.0, 1.0, 1.5]) if not strong else rng.choice([1.0, 1.5, 2.0])
                length = min(length, track.beats - beat)
                track.note(current, track.bar_time(bar, beat), length * track.beat * 0.95, kind, vol,
                           duty, 0.01, cutoff)
                beat += length
            else:
                beat += 0.5


def build_track(name: str, bpm: float, progression, scale, seed: int, style: dict) -> np.ndarray:
    rng = random.Random(seed)
    tr = Track(bpm, len(progression))
    for bar, (root, quality) in enumerate(progression):
        tones = chord_tones(root, quality)
        # Bass.
        for b in style.get("bass_beats", [0, 2]):
            tr.note(root - 24 + 12 * style.get("bass_oct", 0), tr.bar_time(bar, b), tr.beat * 1.8, "triangle",
                    style.get("bass_vol", 0.5), attack=0.005, cutoff=900)
        # Pad.
        if style.get("pad"):
            for t in tones:
                tr.note(t, tr.bar_time(bar), tr.beat * tr.beats, "saw", style["pad"], attack=0.4,
                        cutoff=style.get("pad_cutoff", 900), curve=0.6)
        # Arpeggio.
        if style.get("arp"):
            step = style.get("arp_step", 0.5)
            pattern = tones + [tones[1] + 12, tones[2]]
            k = 0
            beat = 0.0
            while beat < tr.beats:
                tr.note(pattern[k % len(pattern)] + style.get("arp_oct", 12), tr.bar_time(bar, beat), tr.beat * step * 0.9,
                        style.get("arp_wave", "square"), style["arp"], duty=0.25, attack=0.002,
                        cutoff=style.get("arp_cutoff", 2400), curve=2.0)
                beat += step
                k += 1
        # Drums.
        for b in style.get("kick", []):
            tr.drum("kick", tr.bar_time(bar, b), style.get("drum_vol", 0.5), seed + bar)
        for b in style.get("snare", []):
            tr.drum("snare", tr.bar_time(bar, b), style.get("drum_vol", 0.5) * 0.6, seed + bar * 3)
        for b in style.get("hats", []):
            tr.drum("hat", tr.bar_time(bar, b), style.get("drum_vol", 0.5) * 0.35, seed + bar * 7 + int(b * 2))
    if style.get("melody"):
        melody(tr, progression, scale, rng, style.get("mel_oct", 12), style.get("mel_wave", "square"),
               style["melody"], style.get("density", 0.6), style.get("mel_cutoff", 2600), style.get("mel_duty", 0.5))
    return tr.render(style.get("reverb", 0.3), style.get("delay", 0.3))


C, D, E, F, G, A, B = 60, 62, 64, 65, 67, 69, 71
MUSIC = {
    # Village and meadows: warm, hopeful, light drums.
    "meadow": (100, [(C, ""), (G - 12, ""), (A - 12, "m"), (F - 12, ""), (C, ""), (G - 12, ""), (F - 12, ""), (G - 12, "")] * 2,
               [0, 2, 4, 5, 7, 9, 11], 7,
               dict(arp=0.12, arp_step=0.5, pad=0.05, melody=0.22, mel_wave="triangle", mel_oct=12, density=0.55,
                    kick=[0, 2], hats=[0.5, 1.5, 2.5, 3.5], drum_vol=0.45, bass_vol=0.45)),
    # Night forest: slow minor pads, soft bells.
    "night": (72, [(A - 12, "m"), (F - 12, ""), (C, ""), (G - 12, ""), (A - 12, "m"), (D, "m"), (E - 12, "m"), (E - 12, "")],
              [9, 11, 0, 2, 4, 5, 7], 13,
              dict(pad=0.08, pad_cutoff=700, arp=0.07, arp_step=1.0, arp_wave="sine", arp_oct=24, melody=0.18,
                   mel_wave="sine", mel_oct=12, density=0.35, bass_vol=0.35, bass_beats=[0], reverb=0.45, delay=0.42)),
    # Crystal caves: sparse, echoing, mysterious.
    "caves": (64, [(D, "m"), (C, ""), (D, "m"), (A - 12, "m"), (D, "m"), (C, ""), (B - 12, "m"), (A - 12, "")],
              [2, 4, 5, 7, 9, 11, 0], 21,
              dict(pad=0.07, pad_cutoff=500, melody=0.2, mel_wave="sine", mel_oct=24, density=0.25,
                   bass_vol=0.4, bass_beats=[0], reverb=0.55, delay=0.5)),
    # Sky islands: airy lydian, bright arpeggios.
    "sky": (88, [(F - 12, ""), (G - 12, ""), (E - 12, "m"), (A - 12, "m"), (F - 12, ""), (G - 12, ""), (C, ""), (C, "")] * 2,
            [5, 7, 9, 11, 0, 2, 4], 31,
            dict(arp=0.1, arp_step=0.25, arp_wave="triangle", arp_oct=24, pad=0.06, pad_cutoff=1200, melody=0.2,
                 mel_wave="triangle", mel_oct=12, density=0.5, bass_vol=0.4, hats=[1, 3], drum_vol=0.3,
                 reverb=0.4, delay=0.36)),
    # Boss: driving minor, full drums.
    "boss": (144, [(E - 12, "m"), (E - 12, "m"), (C, ""), (D, ""), (E - 12, "m"), (E - 12, "m"), (A - 12, "m"), (B - 12, "")] * 2,
             [4, 6, 7, 9, 11, 0, 2], 41,
             dict(arp=0.12, arp_step=0.25, arp_oct=12, pad=0.05, melody=0.22, mel_wave="square", mel_duty=0.25,
                  mel_oct=12, density=0.75, bass_beats=[0, 0.5, 1.5, 2, 2.5, 3.5], bass_vol=0.5,
                  kick=[0, 1, 2, 3], snare=[1, 3], hats=[0.5, 1.5, 2.5, 3.5], drum_vol=0.55, reverb=0.2, delay=0.2)),
}


# --- ambience (looping beds, Этап 18 tech debt) --------------------------------

AMB_LEN = 16.0


def _loopable(x: np.ndarray, fade: float = 1.0) -> np.ndarray:
    """Crossfades the tail into the head so the loop has no seam."""
    n = int(SR * fade)
    head, body, tail = x[:n], x[n:-n], x[-n:]
    ramp = np.linspace(0.0, 1.0, n)
    mixed = tail * (1.0 - ramp) + head * ramp
    return np.concatenate([body, mixed])


def amb_wind():
    n = noise(AMB_LEN + 2, 101)
    slow = 0.55 + 0.45 * np.sin(2 * np.pi * t_axis(AMB_LEN + 2) / 7.0) * np.sin(2 * np.pi * t_axis(AMB_LEN + 2) / 3.1 + 1.0)
    x = sweep_lowpass(n, 280, 900, 40) * slow
    return _loopable(lowpass(x, 1200), 1.0)


def amb_waves():
    t = t_axis(AMB_LEN + 2)
    n = noise(AMB_LEN + 2, 202)
    swell = np.clip(np.sin(2 * np.pi * t / 4.0), 0, 1) ** 2 + 0.25 * np.clip(np.sin(2 * np.pi * t / 2.7 + 2), 0, 1) ** 3
    x = bandpass(n, 200, 2600) * (0.15 + swell)
    return _loopable(x, 1.0)


NATURE_LEN = 36.0


def _tone(freqs: np.ndarray, harmonic: float = 0.12) -> np.ndarray:
    """A whistled note: the frequency track, a touch of the 2nd harmonic."""
    phase = np.cumsum(freqs) / SR
    return np.sin(2 * np.pi * phase) + harmonic * np.sin(4 * np.pi * phase)


def _soft_env(n: int, attack: float = 0.15, release: float = 0.35) -> np.ndarray:
    """Smooth rise and fall as a share of the note (no clicks)."""
    x = np.linspace(0.0, 1.0, n)
    rise = np.clip(x / attack, 0, 1)
    fall = np.clip((1.0 - x) / release, 0, 1)
    return np.sin(rise * np.pi / 2) ** 2 * np.sin(fall * np.pi / 2) ** 2


def _distant(x: np.ndarray, distance: float) -> np.ndarray:
    """Far birds are quieter and duller, with a little forest echo."""
    cutoff = 7500 - 4500 * distance
    y = lowpass(x, cutoff) * (1.0 - 0.75 * distance)
    return echo(y, 0.09 + 0.05 * distance, 0.18 + 0.15 * distance, 2)


def _warble(rng: random.Random) -> np.ndarray:
    """A robin-like phrase: quick notes gliding up and down."""
    notes = []
    for _ in range(rng.randint(4, 8)):
        dur = rng.uniform(0.06, 0.16)
        n = int(SR * dur)
        f0, f1 = rng.uniform(2300, 4300), rng.uniform(2300, 4600)
        track = np.linspace(f0, f1, n) + 90 * np.sin(2 * np.pi * rng.uniform(25, 55) * np.arange(n) / SR)
        notes.append(_tone(track) * _soft_env(n, 0.2, 0.4))
        notes.append(np.zeros(int(SR * rng.uniform(0.02, 0.07))))
    return np.concatenate(notes)


def _two_note(rng: random.Random) -> np.ndarray:
    """A tit's "ти-ву, ти-ву": a high and a lower note, repeated."""
    hi, lo = rng.uniform(4200, 5200), rng.uniform(2800, 3500)
    parts = []
    for _ in range(rng.randint(2, 4)):
        for f, dur in ((hi, 0.08), (lo, 0.11)):
            n = int(SR * dur)
            parts.append(_tone(np.full(n, f) * np.linspace(1.02, 0.98, n), 0.06) * _soft_env(n))
            parts.append(np.zeros(int(SR * 0.05)))
        parts.append(np.zeros(int(SR * 0.12)))
    return np.concatenate(parts)


def _dove(rng: random.Random) -> np.ndarray:
    """A far wood pigeon: low, soft hoots."""
    parts = []
    for f, dur in ((560, 0.32), (520, 0.5), (500, 0.28)):
        n = int(SR * dur)
        parts.append(_tone(np.full(n, f) * np.linspace(1.0, 0.94, n), 0.25) * _soft_env(n, 0.3, 0.5))
        parts.append(np.zeros(int(SR * 0.12)))
    return np.concatenate(parts)


def amb_birds():
    """Daytime meadow (owner's list №4): leaves in a light wind and a few
    birds now and then — a warbler, a tit, a far pigeon — at different
    distances, with long quiet gaps."""
    length = NATURE_LEN + 2
    t_all = t_axis(length)
    leaves = lowpass(noise(length, 303), 900) * (0.05 + 0.03 * np.sin(2 * np.pi * t_all / 9.0) ** 2)
    base = leaves.copy()
    rng = random.Random(17)
    t = 1.5
    while t < NATURE_LEN - 2.0:
        kind = rng.choices(["warble", "two", "dove"], weights=[5, 4, 1])[0]
        phrase = {"warble": _warble, "two": _two_note, "dove": _dove}[kind](rng)
        distance = rng.uniform(0.25, 0.95) if kind != "dove" else 0.9
        place(base, 0.16 * _distant(phrase, distance), t)
        t += len(phrase) / SR + rng.uniform(2.5, 7.0)
    return _loopable(base, 1.5)


def _chirp(freq: float, pulses: int) -> np.ndarray:
    """One field-cricket chirp: a few 20 ms pulses of a pure high tone."""
    parts = []
    for _ in range(pulses):
        n = int(SR * 0.02)
        parts.append(np.sin(2 * np.pi * freq * np.arange(n) / SR) * _soft_env(n, 0.25, 0.4))
        parts.append(np.zeros(int(SR * 0.016)))
    return np.concatenate(parts)


def amb_night():
    """A summer night (owner's list №4): a soft breeze, two or three crickets
    at different distances singing in bouts with pauses, an owl once."""
    length = NATURE_LEN + 2
    base = lowpass(noise(length, 404), 350) * 0.05
    rng = random.Random(23)
    for cricket in range(3):
        freq = rng.uniform(4200, 4900)
        gain = [0.11, 0.06, 0.035][cricket]
        rate = rng.uniform(1.6, 2.3)
        t = rng.uniform(0.0, 4.0)
        while t < NATURE_LEN - 1.0:
            bout_end = t + rng.uniform(5.0, 11.0)
            while t < min(bout_end, NATURE_LEN - 1.0):
                place(base, gain * lowpass(_chirp(freq, rng.choice([3, 3, 4])), 6500 - 1500 * cricket), t)
                t += 1.0 / rate * rng.uniform(0.92, 1.08)
            t += rng.uniform(3.0, 9.0)
    owl = []
    for dur, f in ((0.45, 390), (0.18, 0), (0.22, 400), (0.12, 0), (0.5, 380)):
        n = int(SR * dur)
        owl.append(np.zeros(n) if f == 0 else _tone(np.full(n, f), 0.3) * _soft_env(n, 0.3, 0.5))
    place(base, 0.07 * _distant(np.concatenate(owl), 0.8), rng.uniform(12.0, 24.0))
    return _loopable(base, 1.5)


def amb_cave():
    base = 0.35 * lowpass(noise(AMB_LEN + 2, 505), 160)
    rng = random.Random(11)
    t = 0.5
    while t < AMB_LEN:
        f = rng.uniform(900, 1700)
        tt = t_axis(0.25)
        drip = np.sin(2 * np.pi * f * (1 + 0.6 * np.exp(-tt * 30)) * tt) * np.exp(-tt * 22)
        place(base, 0.4 * drip, t)
        t += rng.uniform(1.2, 3.4)
    return _loopable(echo(base, 0.18, 0.3, 3)[:int(SR * (AMB_LEN + 2))], 1.0)


def amb_fire():
    base = 0.4 * lowpass(noise(AMB_LEN + 2, 606), 700)
    rng = random.Random(13)
    t = 0.1
    while t < AMB_LEN:
        crack = highpass(noise(0.03, rng.randint(0, 9999)), 1500) * env(int(SR * 0.03), 0.001, 0.02)
        place(base, 0.5 * crack, t)
        t += rng.uniform(0.08, 0.6)
    return _loopable(base, 1.0)


AMBIENCE = {"wind": amb_wind, "waves": amb_waves, "birds": amb_birds, "night": amb_night, "cave": amb_cave, "fire": amb_fire}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", choices=["sfx", "music", "ambience"])
    parser.add_argument("--names", default="", help="comma list of ambience beds to rebuild")
    args = parser.parse_args()
    if args.only in (None, "sfx"):
        for name, fn in SFX.items():
            write_wav(OUT / "sfx" / f"{name}.wav", normalize(fn(), 0.8))
            print(f"  sfx/{name}.wav")
    if args.only in (None, "music"):
        for name, (bpm, prog, scale, seed, style) in MUSIC.items():
            write_ogg(OUT / "music" / f"{name}.ogg", build_track(name, bpm, prog, scale, seed, style))
            print(f"  music/{name}.ogg")
    if args.only in (None, "ambience"):
        wanted = [n for n in args.names.split(",") if n]
        for name, fn in AMBIENCE.items():
            if wanted and name not in wanted:
                continue
            # Nature beds are mixed quieter (owner's list №4).
            write_ogg(OUT / "ambience" / f"{name}.ogg", normalize(fn(), 0.32 if name in ("birds", "night") else 0.6))
            print(f"  ambience/{name}.ogg")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
