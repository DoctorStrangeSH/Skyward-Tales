#!/usr/bin/env python3
"""Skyward Tales sound effects, 44.1 kHz (stage 20, 9 ноября 2026).

    python3 tools/audio/sfx_hd.py [--only hit,chest,...]

Replaces the 8-bit effects of tools/audio/build_audio.py: layered noise
and resonators for blows, whooshes and magic, and real instruments (harp,
bells, brass — the GeneralUser GS bank via tools/audio/orchestra.py) for
rewards and fanfares. Writes assets/audio/sfx/<name>.wav (mono, 16 bit).
Deterministic: fixed seeds.
"""
from __future__ import annotations

import argparse
import pathlib
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy import signal

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import orchestra as orch  # noqa: E402

SR = 44100
OUT = orch.OUT / "sfx"
_TOOLS: tuple | None = None


# --- primitives -------------------------------------------------------------

def n_of(seconds: float) -> int:
    return int(SR * seconds)


def t_of(seconds: float) -> np.ndarray:
    return np.arange(n_of(seconds)) / SR


def noise(seconds: float, seed: int) -> np.ndarray:
    return np.random.default_rng(seed).standard_normal(n_of(seconds))


def sos(kind: str, freq, order: int = 2):
    return signal.butter(order, freq, kind, fs=SR, output="sos")


def lp(x, f, order=2):
    return signal.sosfilt(sos("low", f, order), x)


def hp(x, f, order=2):
    return signal.sosfilt(sos("high", f, order), x)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(sos("band", [lo, hi], order), x)


def sweep_bp(x: np.ndarray, f0: float, f1: float, q: float = 1.2, steps: int = 48) -> np.ndarray:
    """Band-pass whose centre glides from f0 to f1 (exponentially)."""
    out = np.zeros_like(x)
    edges = np.linspace(0, len(x), steps + 1).astype(int)
    zi = None
    for i in range(steps):
        f = f0 * (f1 / f0) ** (i / max(1, steps - 1))
        lo, hi = f / (1 + 0.5 / q), min(SR * 0.45, f * (1 + 0.5 / q))
        s = sos("band", [lo, hi])
        if zi is None or zi.shape != (s.shape[0], 2):
            zi = np.zeros((s.shape[0], 2))
        out[edges[i]:edges[i + 1]], zi = signal.sosfilt(s, x[edges[i]:edges[i + 1]], zi=zi)
    return out


def adsr(n: int, attack: float, decay_curve: float = 3.0, release: float = 0.02) -> np.ndarray:
    a = max(1, n_of(attack))
    e = np.ones(n)
    e[:a] = np.linspace(0, 1, a) ** 1.5
    e[a:] = np.exp(-decay_curve * np.linspace(0, 1, n - a))
    r = min(n, n_of(release))
    e[-r:] *= np.linspace(1, 0, r)
    return e


def swell(n: int, peak_at: float, sharp: float = 2.0) -> np.ndarray:
    """Rises to a peak (fraction of the length), then falls away."""
    x = np.linspace(0, 1, n)
    up = (x / peak_at) ** sharp
    down = np.exp(-4.0 * (x - peak_at) / (1 - peak_at))
    e = np.where(x < peak_at, up, down)
    e[-n_of(0.01):] *= np.linspace(1, 0, n_of(0.01))
    return e


def sine_glide(f0: float, f1: float, seconds: float, curve: float = 3.0) -> np.ndarray:
    t = np.linspace(0, 1, n_of(seconds))
    f = f1 + (f0 - f1) * np.exp(-curve * t)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def ring(freqs, seconds: float, decays, amps) -> np.ndarray:
    """Struck metal/glass: damped partials."""
    t = t_of(seconds)
    out = np.zeros_like(t)
    for f, d, a in zip(freqs, decays, amps):
        out += a * np.sin(2 * np.pi * f * t) * np.exp(-t / d)
    return out


def crackles(seconds: float, rate: float, seed: int, lo: float = 1500, hi: float = 7000) -> np.ndarray:
    rng = np.random.default_rng(seed)
    out = np.zeros(n_of(seconds))
    count = int(seconds * rate)
    for _ in range(count):
        at = rng.integers(0, len(out) - 400)
        k = rng.integers(40, 300)
        burst = rng.standard_normal(k) * np.exp(-np.linspace(0, 6, k)) * rng.uniform(0.3, 1.0)
        out[at:at + k] += burst
    return bp(out, lo, hi)


def mix(length: float, *layers) -> np.ndarray:
    """layers: (array, start seconds, gain)."""
    out = np.zeros(n_of(length))
    for x, at, gain in layers:
        i = n_of(at)
        k = min(len(x), len(out) - i)
        if k > 0:
            out[i:i + k] += x[:k] * gain
    return out


def room(x: np.ndarray, seconds: float = 0.5, wet: float = 0.2, seed: int = 3) -> np.ndarray:
    ir = orch.reverb_ir(seconds, seed)[:, 0]
    tail = signal.fftconvolve(x, ir)[: len(x)]
    return x * (1 - wet * 0.4) + tail * wet


def instruments(notes, seconds: float, seed: int = 1) -> np.ndarray:
    """notes: [(time s, gm name or (bank, preset), key, velocity, length s)] → mono."""
    global _TOOLS
    if _TOOLS is None:
        _TOOLS = orch.ensure_tools()
    bank, exe = _TOOLS
    score = orch.Score(60, 4, seed)
    parts: dict = {}
    for at, program, key, vel, length in notes:
        if program not in parts:
            if isinstance(program, tuple):
                parts[program] = score.part(program[1], 120, 64, program[0])
            else:
                parts[program] = score.part(program, 120, 64)
        parts[program].note(at, key, length, vel)
    with tempfile.TemporaryDirectory() as tmp:
        ev = pathlib.Path(tmp) / "ev.txt"
        raw = pathlib.Path(tmp) / "out.f32"
        ev.write_text("\n".join(score.events(humanize=0.0)) + "\n")
        subprocess.run([str(exe), str(bank), str(ev), str(raw), f"{seconds:.3f}", str(SR)], check=True)
        x = np.fromfile(raw, dtype=np.float32).reshape(-1, 2).mean(axis=1).astype(np.float64)
    return x[: n_of(seconds)]


P = orch.pitch


# --- the sounds ---------------------------------------------------------------

def sfx_hit():
    """A blade biting: click, swish, body thump and a faint ring of steel."""
    click = hp(noise(0.006, 1), 3000) * np.linspace(1, 0, n_of(0.006))
    slash = bp(noise(0.09, 2), 1400, 6000) * adsr(n_of(0.09), 0.002, 5)
    thump = sine_glide(150, 55, 0.14, 4) * adsr(n_of(0.14), 0.001, 4)
    body = lp(noise(0.12, 3), 900) * adsr(n_of(0.12), 0.001, 6)
    steel = ring([2140, 3410, 5230, 6870], 0.25, [0.06, 0.05, 0.035, 0.025], [0.25, 0.2, 0.12, 0.08])
    return room(mix(0.3, (click, 0, 0.35), (slash, 0.002, 0.55), (thump, 0, 0.9), (body, 0, 0.5), (steel, 0.003, 0.35)), 0.35, 0.12)


def sfx_hurt():
    """The hero is struck: a dull thud and a crunch, no ring."""
    thud = sine_glide(110, 48, 0.22, 3) * adsr(n_of(0.22), 0.002, 4)
    crunch = bp(noise(0.12, 5), 300, 1800) * adsr(n_of(0.12), 0.001, 5)
    grit = crackles(0.08, 200, 6, 800, 3000)
    return room(mix(0.3, (thud, 0, 1.0), (crunch, 0, 0.7), (grit, 0.005, 0.4)), 0.3, 0.1)


def sfx_enemy_die():
    """A foe falls: thud, a puff of dust and a soft magical fade."""
    thud = sine_glide(120, 40, 0.25, 3) * adsr(n_of(0.25), 0.002, 4)
    puff = sweep_bp(noise(0.55, 7), 2400, 260, 1.0) * swell(n_of(0.55), 0.12, 1.5)
    sparkle = instruments([(0.08, "celesta", P("E7"), 70, 0.3), (0.13, "celesta", P("B6"), 62, 0.3),
                           (0.18, "celesta", P("G#6"), 54, 0.4)], 0.9)
    return room(mix(0.9, (thud, 0, 0.8), (puff, 0, 0.8), (sparkle, 0, 0.45)), 0.6, 0.2)


def sfx_cast_fire():
    """A fireball leaves the hand: whoosh, crackle and a low burn."""
    whoosh = sweep_bp(noise(0.55, 11), 350, 2600, 1.1) * swell(n_of(0.55), 0.18)
    crackle = crackles(0.5, 70, 12) * swell(n_of(0.5), 0.2)
    rumble = lp(noise(0.5, 13), 160) * swell(n_of(0.5), 0.15)
    pop = sine_glide(220, 90, 0.08, 4) * adsr(n_of(0.08), 0.002, 5)
    return room(mix(0.6, (whoosh, 0, 1.0), (crackle, 0.02, 0.45), (rumble, 0, 0.9), (pop, 0, 0.4)), 0.4, 0.15)


def sfx_cast_ice():
    """A frost bolt: a sharp crystal crack and a shimmer of glass."""
    crack = hp(noise(0.03, 21), 2500) * adsr(n_of(0.03), 0.001, 8)
    shimmer = instruments([(0.0, "glock", P("B6"), 80, 0.4), (0.03, "celesta", P("E7"), 76, 0.4),
                           (0.06, "glock", P("G#7"), 64, 0.5), (0.09, "celesta", P("B7"), 56, 0.5)], 0.75)
    air = sweep_bp(noise(0.5, 22), 6000, 3000, 1.5) * swell(n_of(0.5), 0.1)
    glass = ring([3520, 5190, 7240], 0.5, [0.15, 0.1, 0.07], [0.2, 0.15, 0.1])
    return room(mix(0.75, (crack, 0, 0.3), (shimmer, 0, 0.8), (air, 0, 0.35), (glass, 0.004, 0.3)), 0.6, 0.25)


def _zap(seconds: float, seed: int, base: float = 120.0) -> np.ndarray:
    rng = np.random.default_rng(seed)
    t = t_of(seconds)
    jitter = np.repeat(rng.uniform(0.6, 1.6, len(t) // 220 + 1), 220)[: len(t)]
    f = base * jitter
    phase = np.cumsum(f) / SR
    buzz = (2 * (phase % 1.0) - 1) + 0.5 * np.sign(np.sin(2 * np.pi * phase * 3.01))
    return bp(buzz, 300, 7000)


def sfx_cast_lightning():
    """Lightning: a whip-crack and a crackling buzz."""
    crack = hp(noise(0.05, 31), 1800) * adsr(n_of(0.05), 0.0005, 7)
    zap = _zap(0.4, 32) * adsr(n_of(0.4), 0.002, 4)
    sparks = crackles(0.45, 120, 33, 2500, 9000) * adsr(n_of(0.45), 0.005, 3)
    boom = lp(noise(0.3, 34), 200) * adsr(n_of(0.3), 0.003, 4)
    return room(mix(0.5, (crack, 0, 0.45), (zap, 0.01, 0.5), (sparks, 0, 0.5), (boom, 0.01, 0.6)), 0.45, 0.18)


def sfx_cast_wave():
    """Огненная волна: a roaring fan of fire — big whoosh, boom, long crackle."""
    roar = sweep_bp(noise(0.95, 41), 250, 1800, 0.8) * swell(n_of(0.95), 0.25, 1.4)
    hiss = sweep_bp(noise(0.9, 42), 1800, 5200, 1.0) * swell(n_of(0.9), 0.3)
    crackle = crackles(0.9, 110, 43, 1200, 7000) * swell(n_of(0.9), 0.35)
    boom = sine_glide(90, 38, 0.6, 2.5) * adsr(n_of(0.6), 0.01, 3)
    return room(mix(1.0, (roar, 0, 1.0), (hiss, 0.05, 0.35), (crackle, 0.05, 0.5), (boom, 0, 0.9)), 0.7, 0.2)


def sfx_cast_wall():
    """Ледяная стена: ice grows with cracks, blocks land, crystals chime."""
    rng = np.random.default_rng(51)
    cracks = np.zeros(n_of(0.6))
    for i in range(9):
        at = n_of(0.03 + i * 0.055 + rng.uniform(0, 0.02))
        k = n_of(0.03)
        burst = bp(noise(0.03, 60 + i), 1800 + 300 * i, 6000) * np.exp(-np.linspace(0, 7, k))
        cracks[at:at + k] += burst * rng.uniform(0.6, 1.0)
    thumps = np.zeros(n_of(0.6))
    for i in range(5):
        th = sine_glide(130, 60, 0.12, 4) * adsr(n_of(0.12), 0.002, 5)
        at = n_of(0.05 + i * 0.09)
        thumps[at:at + len(th)] += th[: len(thumps) - at]
    chime = instruments([(0.35, "glock", P("E6"), 70, 0.6), (0.38, "glock", P("B6"), 64, 0.6),
                         (0.41, "celesta", P("E7"), 60, 0.6), (0.44, "celesta", P("G#7"), 52, 0.6)], 1.1)
    return room(mix(1.1, (cracks, 0, 0.8), (thumps, 0, 0.7), (chime, 0, 0.6)), 0.7, 0.25)


def sfx_cast_orb():
    """Шаровая молния: a humming orb wakes up, crackling and rising."""
    t = t_of(0.9)
    f = 95 * (1 + 0.6 * t / t[-1])
    phase = np.cumsum(f) / SR
    hum = sum(np.sin(2 * np.pi * phase * h) / h for h in (1, 2, 3, 5, 7))
    hum *= 0.7 + 0.3 * np.sin(2 * np.pi * 17 * t)
    hum = lp(hum, 3000) * swell(len(t), 0.4, 1.2)
    whine = np.sin(2 * np.pi * np.cumsum(np.linspace(900, 2200, len(t))) / SR) * swell(len(t), 0.5) * 0.15
    sparks = crackles(0.9, 90, 71, 3000, 9000) * swell(len(t), 0.45)
    crack = hp(noise(0.04, 72), 2000) * adsr(n_of(0.04), 0.0005, 7)
    return room(mix(0.95, (hum, 0, 0.8), (whine, 0, 1.0), (sparks, 0, 0.5), (crack, 0, 0.6)), 0.5, 0.18)


def sfx_dash():
    """A roll or a dash: a quick airy whoosh."""
    w = sweep_bp(noise(0.32, 81), 500, 2200, 1.0) * swell(n_of(0.32), 0.35, 1.6)
    low = lp(noise(0.32, 82), 300) * swell(n_of(0.32), 0.3) * 0.5
    return mix(0.35, (w, 0, 1.0), (low, 0, 0.6))


def sfx_gust():
    """Wind on the sky islands."""
    w = sweep_bp(noise(1.3, 91), 400, 1100, 0.8) * swell(n_of(1.3), 0.4, 1.3)
    w2 = sweep_bp(noise(1.3, 92), 1600, 900, 1.5) * swell(n_of(1.3), 0.55, 1.5)
    return mix(1.3, (w, 0, 1.0), (w2, 0, 0.4))


def sfx_pickup():
    """Picking something up: two bright bell notes."""
    notes = instruments([(0.0, "celesta", P("E6"), 84, 0.3), (0.07, "celesta", P("B6"), 88, 0.5),
                         (0.07, "glock", P("B6"), 50, 0.4)], 0.6)
    return room(notes, 0.5, 0.2)


def sfx_chest():
    """A chest: a wooden creak, then a harp glissando and sparkles."""
    t = t_of(0.35)
    rng = np.random.default_rng(101)
    f = 180 + 60 * np.sin(2 * np.pi * 3 * t) + np.repeat(rng.uniform(-20, 20, len(t) // 400 + 1), 400)[: len(t)]
    phase = np.cumsum(f) / SR
    creak = bp(np.sign(np.sin(2 * np.pi * phase)) * (rng.random(len(t)) > 0.3), 400, 2500) * swell(len(t), 0.5) * 0.4
    gliss = [(0.3 + i * 0.045, "harp", k, 70 + i * 2, 1.0) for i, k in enumerate(
        [P(n) for n in ("C5", "D5", "E5", "G5", "A5", "C6", "D6", "E6", "G6")])]
    sparkle = [(0.72, "glock", P("C7"), 62, 0.6), (0.78, "glock", P("G7"), 54, 0.6)]
    music = instruments(gliss + sparkle, 1.6)
    return room(mix(1.6, (creak, 0, 1.0), (music, 0, 0.9)), 0.8, 0.22)


def sfx_level_up():
    """Level up: a harp rush into a bright brass-and-strings chord with bells."""
    gliss = [(i * 0.035, "harp", k, 76, 1.2) for i, k in enumerate(
        [P(n) for n in ("D4", "F#4", "A4", "D5", "F#5", "A5", "D6", "F#6")])]
    chord = [(0.3, "brass", P(n), 92, 1.3) for n in ("D4", "A4", "D5", "F#5")]
    chord += [(0.3, "strings", P(n), 86, 1.5) for n in ("D4", "A4", "F#5", "A5")]
    bells = [(0.3, "glock", P("A6"), 70, 0.8), (0.42, "glock", P("D7"), 64, 0.8), (0.3, "timpani", P("D2"), 96, 1.0)]
    return room(instruments(gliss + chord + bells, 2.2), 1.2, 0.3)


def sfx_quest():
    """A quest is done: a short horn call and a warm major chord."""
    call = [(0.0, "horn", P("G4"), 90, 0.18), (0.16, "horn", P("C5"), 94, 0.18), (0.32, "horn", P("E5"), 100, 0.9)]
    chord = [(0.32, "strings", P(n), 78, 1.0) for n in ("C4", "G4", "C5", "E5")]
    chord += [(0.32, "harp", P(n), 72, 1.0) for n in ("C4", "E4", "G4", "C5")]
    chord += [(0.32, "trumpet", P("G5"), 70, 0.8)]
    return room(instruments(call + chord, 1.6), 1.0, 0.3)


def sfx_travel():
    """Travel and flight: a rising harp, chimes and a whoosh of wind."""
    gliss = [(i * 0.05, "harp", k, 66, 1.0) for i, k in enumerate(
        [P(n) for n in ("F4", "A4", "C5", "E5", "G5", "A5", "C6", "E6")])]
    chimes = [(0.45, "celesta", P("E7"), 60, 0.8), (0.55, "celesta", P("C7"), 56, 0.8)]
    music = instruments(gliss + chimes, 1.6)
    wind = sweep_bp(noise(1.6, 111), 500, 1800, 0.8) * swell(n_of(1.6), 0.45)
    return room(mix(1.6, (music, 0, 1.0), (wind, 0, 0.35)), 0.9, 0.25)


def sfx_boss_roar():
    """A boss appears: low brass cluster, a growl and a timpani hit."""
    brass = instruments([(0.0, "tuba", P("C2"), 116, 1.4), (0.0, "trombone", P("C3"), 112, 1.4),
                         (0.02, "trombone", P("Db3"), 104, 1.3), (0.0, "horn", P("G3"), 104, 1.3),
                         (0.0, "timpani", P("C2"), 120, 1.5), (0.0, "orchhit", P("C3"), 80, 0.6)], 1.9)
    t = t_of(1.4)
    growl_src = noise(1.4, 121) * (0.6 + 0.4 * np.sin(2 * np.pi * 28 * t))
    growl = (bp(growl_src, 180, 420) + 0.6 * bp(growl_src, 600, 1100) + 0.3 * bp(growl_src, 1800, 2600))
    growl *= swell(len(t), 0.3, 1.5)
    return room(mix(1.9, (brass, 0, 1.0), (growl, 0.05, 0.7)), 1.0, 0.25)


def sfx_ui():
    """A soft wooden tick for buttons."""
    tick = ring([1850, 3200, 4700], 0.05, [0.008, 0.005, 0.003], [1.0, 0.4, 0.2])
    click = hp(noise(0.004, 131), 4000) * np.linspace(1, 0, n_of(0.004))
    return mix(0.06, (tick, 0, 0.8), (click, 0, 0.3))


SFX = {
    "hit": sfx_hit, "hurt": sfx_hurt, "enemy_die": sfx_enemy_die,
    "cast_fire": sfx_cast_fire, "cast_ice": sfx_cast_ice, "cast_lightning": sfx_cast_lightning,
    "cast_wave": sfx_cast_wave, "cast_wall": sfx_cast_wall, "cast_orb": sfx_cast_orb,
    "dash": sfx_dash, "gust": sfx_gust, "pickup": sfx_pickup, "chest": sfx_chest, "level_up": sfx_level_up,
    "quest": sfx_quest, "travel": sfx_travel, "boss_roar": sfx_boss_roar, "ui": sfx_ui,
}
# Loudness by role (RMS, dB): interface and small pickups quieter, blows and magic fuller.
LOUDNESS = {"ui": -27.0, "pickup": -22.0, "dash": -23.0, "gust": -24.0, "travel": -20.0}


def write_wav(path: pathlib.Path, x: np.ndarray, rms_db: float) -> None:
    x = x - np.mean(x)
    x = x * (10 ** (rms_db / 20) / (np.sqrt(np.mean(x ** 2)) + 1e-9))
    # A soft limiter keeps sharp transients (cracks, clicks) under full scale.
    knee, ceiling = 0.7, 0.97
    over = np.abs(x) > knee
    x[over] = np.sign(x[over]) * (knee + (ceiling - knee) * np.tanh((np.abs(x[over]) - knee) / (ceiling - knee)))
    fade = min(len(x), n_of(0.008))
    x[-fade:] *= np.linspace(1, 0, fade)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", default="")
    args = parser.parse_args()
    wanted = [n for n in args.only.split(",") if n] or list(SFX)
    for name in wanted:
        x = SFX[name]()
        write_wav(OUT / f"{name}.wav", x, LOUDNESS.get(name, -18.0))
        print(f"  sfx/{name}.wav  {len(x) / SR:.2f} s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
