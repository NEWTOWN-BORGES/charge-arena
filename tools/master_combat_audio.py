"""Bake Charge Arena's combat mix. Original synthesis; no external samples.

The established skin recordings remain the identity layer of every weapon.
All room reflections, transient shaping and synthesis run here, never on a
gameplay frame. PCM stereo avoids decoder work on short, overlapping effects.
Run with Python + numpy; --check audits committed assets without regenerating.
Music is intentionally outside this tool's input/output paths.
"""
from pathlib import Path
import argparse
import hashlib
import json
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "audio/sfx/premium"
RATE = 32000
TAU = 2 * np.pi


def timeline(seconds):
    return np.arange(round(seconds * RATE), dtype=float) / RATE


def envelope(t, decay, attack=.002):
    return (1 - np.exp(-t / attack)) * np.exp(-t * decay)


def noise(t, seed, low=50, high=6200):
    """Deterministic, smooth band-limited air instead of abrasive white hiss."""
    source = np.random.default_rng(seed).normal(0, 1, len(t))
    frequencies = np.fft.rfftfreq(len(t), 1 / RATE)
    response = 1 / np.sqrt(1 + (frequencies / high) ** 8)
    response *= frequencies ** 2 / (frequencies ** 2 + low ** 2)
    result = np.fft.irfft(np.fft.rfft(source) * response, n=len(t))
    return result / max(.001, np.std(result) * 3)


def chirp(t, start, finish, speed=8):
    phase = finish * t + (start - finish) * (1 - np.exp(-t * speed)) / speed
    return np.sin(TAU * phase)


def body(t, start=165, finish=68, decay=11):
    fundamental = chirp(t, start, finish)
    # Octave harmonics carry the weight on small phone speakers, not just a sub.
    harmonic = chirp(t, start * 2, finish * 2) * .27
    return (fundamental + harmonic) * envelope(t, decay)


def read_mono(path, t):
    with wave.open(str(path), "rb") as source:
        assert source.getsampwidth() == 2
        frames = np.frombuffer(source.readframes(source.getnframes()), "<i2")
        frames = frames.reshape(-1, source.getnchannels()).mean(axis=1) / 32768
        return np.interp(t, np.arange(len(frames)) / source.getframerate(), frames, right=0)


def room(dry, wet=.12, tail=.10):
    """Short asymmetric early reflections; mono remains strong and in phase."""
    padded = np.pad(dry, (0, round(tail * RATE)))
    stereo = np.repeat(padded[:, None], 2, axis=1)
    damped = np.convolve(padded, np.ones(7) / 7, mode="same")
    for side, delays in enumerate([(.019, .047, .083), (.027, .058, .097)]):
        for delay, gain in zip(delays, (wet, wet * .53, wet * .27)):
            offset = round(delay * RATE)
            stereo[offset:, side] += damped[:-offset] * gain
    return stereo


def write(name, dry, wet=.12, peak=.76, tail=.10):
    signal = room(dry, wet, tail)
    signal -= np.mean(signal, axis=0)
    # Gentle crest rounding brings texture forward without clipping transients.
    signal = np.tanh(signal * 1.12) / 1.12
    signal -= np.mean(signal, axis=0)
    signal[:64] *= np.linspace(0, 1, 64)[:, None]
    signal[-384:] *= np.linspace(1, 0, 384)[:, None]
    signal *= peak / max(.001, np.max(np.abs(signal)))
    with wave.open(str(OUT / (name + ".wav")), "wb") as target:
        target.setparams((2, 2, RATE, len(signal), "NONE", "not compressed"))
        target.writeframes(np.rint(signal * 32767).astype("<i2").tobytes())


def weapons():
    # Body pitches follow the established themes: resonant crystal, heavy eclipse,
    # clockwork, electric Tesla, soft botanical and broad Corsair recoil.
    pitches = [132, 156, 119, 164, 103, 80, 146, 181, 124, 87, 110, 139]
    for skin in range(12):
        for variant in range(3):
            t = timeline(.36)
            source = read_mono(ROOT / f"audio/sfx/feedback/shot_{skin}_{variant}.wav", t)
            identity = read_mono(ROOT / f"audio/sfx/shot_{skin}.wav", t)
            pitch = pitches[skin] * (1 + (variant - 1) * .013)
            dry = source * .92 + identity * .36
            dry += body(t, pitch * 1.55, pitch, 23) * .13
            dry += noise(t, skin * 73 + variant, 1200, 5200) * envelope(t, 120, .0007) * .08
            write(f"shot_{skin}_{variant}", dry, .085, .72, .10)
    for name in ["metal", "ricochet", "shield", "defense"] + [f"{kind}_{i}" for kind in ["hit", "break"] for i in range(3)]:
        t = timeline(.54 if name == "defense" else .34)
        dry = read_mono(ROOT / f"audio/sfx/feedback/{name}.wav", t)
        if name.startswith("break"):
            dry += body(t, 132, 72, 14) * .23
            dry += noise(t, 814 + int(name[-1]), 480, 4400) * envelope(t, 18) * .12
        elif name.startswith("hit"):
            dry += body(t, 188, 112, 35) * .15
        elif name == "shield":
            dry += chirp(t, 910, 230, 19) * envelope(t, 24) * .13
        write(name, dry, .10, .69 if name in ["metal", "ricochet"] else .76)


def blast(name, seed, seconds=.70, weight=1.0):
    t = timeline(seconds)
    crack = noise(t, seed, 600, 6400) * envelope(t, 65, .0006) * .45
    air = noise(t, seed + 1, 100, 1600) * envelope(t, 8, .008) * .44
    debris = noise(t, seed + 2, 1500, 7500) * envelope(t, 15, .016) * .11
    dry = crack + air + debris + body(t, 175, 56, 7.5) * (.51 * weight)
    write(name, dry, .18, .79, .16)


def chime(name, base, seconds=.75, seed=28, scale=(1, 1.25, 1.5), wet=.20):
    t = timeline(seconds)
    dry = np.zeros_like(t)
    for i, interval in enumerate(scale):
        shifted = np.maximum(0, t - i * .068)
        dry += (np.sin(TAU * base * interval * shifted) + .10 * np.sin(TAU * base * interval * 3 * shifted)) * envelope(shifted, 4.5 + i * .5, .004) * .26
    dry += noise(t, seed, 900, 4900) * envelope(t, 15) * .05
    write(name, dry, wet, .74, .16)


def sweep(name, start, finish, seconds, seed, grit=.10, rising=False):
    t = timeline(seconds)
    if rising:
        p = t / seconds
        frequencies = start + (finish - start) * p ** 1.8
        phase = np.cumsum(frequencies) / RATE
        dry = (np.sin(TAU * phase) + .18 * np.sin(TAU * phase * 2.003))
        dry *= np.minimum(t * 25, 1) * (.2 + p * .65) * np.minimum((seconds - t) * 25, 1)
        dry += noise(t, seed, 450, 4000) * p ** 2 * grit
    else:
        dry = chirp(t, start, finish, 5 / seconds) * envelope(t, 3.3 / seconds) * .54
        dry += noise(t, seed, 200, 5800) * envelope(t, 5 / seconds) * grit
    write(name, dry, .16, .76, .12)


def effects():
    blast("blast", 20)
    blast("meteor", 30, .54, 1.12)
    blast("unleash", 40, .83, 1.16)
    blast("void_burst", 50, 1.05, 1.38)
    # Lightning has a double crack and a rolling, filtered tail, not an explosion.
    t = timeline(.84)
    crack = noise(t, 70, 1000, 7600) * envelope(t, 120, .0004)
    shifted = np.maximum(0, t - .024)
    crack += noise(t, 71, 400, 5300) * envelope(shifted, 77, .0008) * .52
    rumble = noise(t, 72, 45, 620) * envelope(t, 4.8, .006) * .5
    write("thunder", crack * .5 + rumble + body(t, 103, 58, 8) * .25, .22, .79, .16)
    # Solar beam is a harmonic reactor with a modulated corona layer.
    t = timeline(.44)
    reactor = sum(np.sin(TAU * f * t) * a for f, a in [(174, .29), (348.8, .13), (525, .08), (1052, .035)])
    reactor *= .82 + .18 * np.sin(TAU * 32 * t)
    reactor += noise(t, 82, 270, 3900) * .17
    reactor *= np.minimum(t * 180, 1) * np.minimum((.44 - t) * 22, 1)
    write("sun_ray", reactor, .13, .76, .08)
    t = timeline(.34)
    laser = (np.sin(TAU * 281 * t) * .30 + np.sin(TAU * 562 * t) * .12)
    laser += noise(t, 85, 750, 6500) * .13
    laser *= envelope(t, 4, .003) * (.83 + .17 * np.sin(TAU * 47 * t))
    write("laser_tick", laser, .08, .69, .07)
    sweep("charging", 118, 945, 1.90, 91, .13, True)
    sweep("power", 640, 190, .30, 95, .30)
    sweep("boost", 310, 1060, .30, 99, .05, True)
    sweep("plunder", 180, 780, .54, 100, .21, True)
    sweep("singularity", 700, 46, 1.35, 101, .26)
    sweep("void_wave", 1250, 145, .58, 102, .33)
    sweep("surge", 510, 138, .46, 104, .24)
    sweep("sentries", 790, 180, .28, 105, .35)
    sweep("sentry", 1100, 360, .09, 106, .24)
    sweep("stun", 177, 74, .28, 107, .06)
    sweep("bounce", 1170, 745, .08, 108, .06)
    chime("ready", 587.33, .47, 111, wet=.10)
    chime("goal", 293.66, 1.02, 112, (1, 1.25, 1.5, 2), .18)
    chime("bloom", 523.25, .94, 113, (1, 1.25, 1.5, 2), .25)
    chime("volley", 392, .35, 114, wet=.11)
    chime("plating", 784, .55, 115, (1, 1.5, 2.01), .19)
    # Each basic ability has a readable activation identity, apart from its hits.
    configurations = {
        "blast": (580, 105, .23, .34), "rapid": (780, 310, .21, .24),
        "air": (1120, 280, .30, .42), "ghost": (830, 136, .49, .12),
        "laser": (360, 1150, .30, .16), "walls": (170, 70, .46, .42),
        "stun": (1400, 135, .36, .20), "magnet": (790, 245, .46, .09),
        "pierce": (1940, 210, .25, .36), "thorns": (1620, 340, .40, .28),
    }
    for i, (key, (start, end, seconds, grit)) in enumerate(configurations.items()):
        sweep("ability_" + key, start, end, seconds, 120 + i, grit, key == "laser")
    for key, base, scale in [("rebuild", 440, (1, 1.25, 1.5)), ("weld", 554.37, (1, 1.5)), ("freeze", 988, (1, 1.414, 2.02)), ("mirror", 830.61, (1, 1.5, 2))]:
        chime("ability_" + key, base, .52, 140, scale, .16)


def audit():
    records = []
    for path in sorted(OUT.glob("*.wav")):
        with wave.open(str(path), "rb") as source:
            assert source.getnchannels() == 2 and source.getframerate() == RATE
            x = np.frombuffer(source.readframes(source.getnframes()), "<i2").reshape(-1, 2).astype(float) / 32768
        peak = float(np.max(np.abs(x)))
        duration = len(x) / RATE
        assert 0 < peak <= .791 and .09 < duration <= 2.1, path.name
        assert np.max(np.abs(x[0])) < .001 and np.max(np.abs(x[-1])) < .001, path.name
        assert np.max(np.abs(np.mean(x, axis=0))) < .003, path.name
        # Reflections must not disappear when a phone sums to one speaker.
        stereo_energy = np.mean(x ** 2)
        mono_energy = np.mean(np.mean(x, axis=1) ** 2)
        assert mono_energy / stereo_energy > .93, path.name
        records.append({"name": path.name, "seconds": round(duration, 3), "peak_dbfs": round(20 * np.log10(peak), 2), "rms_dbfs": round(10 * np.log10(stereo_energy), 2), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    assert len(records) == 83, f"Expected 83 independent effects, found {len(records)}"
    assert len({r["sha256"] for r in records}) == len(records), "Duplicate cues"
    result = {"sample_rate": RATE, "channels": 2, "bits": 16, "asset_count": len(records), "total_bytes": sum(p.stat().st_size for p in OUT.glob("*.wav")), "maximum_peak_dbfs": max(r["peak_dbfs"] for r in records), "assets": records}
    (OUT / "audit.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"AUDIT PASS: {len(records)} cues, {result['total_bytes'] / 1024 / 1024:.2f} MiB PCM, max {result['maximum_peak_dbfs']} dBFS; mono compatible, distinct, faded ends.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if not args.check:
        OUT.mkdir(parents=True, exist_ok=True)
        weapons()
        effects()
    audit()
