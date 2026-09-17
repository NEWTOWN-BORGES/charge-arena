"""Synthesize one shot sound per skin weapon (no samples).

    python tools/compose_sfx.py

Writes audio/sfx/shot_0.wav ... shot_10.wav in catalog order: Manopla de energia,
Lança-Farol, Sextante Estelar, Semeador, Perfuradora de Cristal, Lança Eclipse,
Canhão de Corda, Bobina de Tesla, Frasco de Plasma, Bacamarte Estelar, Cetro Solar.
Sounds share one average loudness (about the old shot tone's), with a peak ceiling.
Needs numpy and scipy.
"""
import os
import wave

import numpy as np
from scipy import signal

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET_RMS = 10 ** (-14.0 / 20)
PEAK_LIMIT = 10 ** (-1.5 / 20)
rng = np.random.default_rng(7)


def timeline(seconds):
    return np.arange(int(SR * seconds)) / SR


def phase(freq):
    return 2 * np.pi * np.cumsum(np.broadcast_to(freq, freq.shape)) / SR


def decay(t, attack, tau):
    return np.clip(t / attack, 0, 1) * np.exp(-t / tau)


def band(x, low, high):
    b, a = signal.butter(2, [low / (SR / 2), high / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def lowpass(x, cutoff):
    b, a = signal.butter(2, cutoff / (SR / 2))
    return signal.lfilter(b, a, x)


def highpass(x, cutoff):
    b, a = signal.butter(2, cutoff / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def aurora():
    # Energy gauntlet: a bright zap that drops in pitch, with a click at the front.
    t = timeline(0.16)
    freq = 380 + 1250 * np.exp(-t / 0.05)
    body = 0.55 * np.sin(phase(freq)) + 0.35 * np.sign(np.sin(phase(freq))) * np.exp(-t / 0.02)
    click = highpass(rng.standard_normal(t.size), 3000) * np.exp(-t / 0.004) * 0.4
    return lowpass(body, 5000) * decay(t, 0.002, 0.045) + click


def lighthouse():
    # Lança-Farol: an FM beam with a short airy hiss as it leaves the crystal.
    t = timeline(0.28)
    carrier = 1046 * (1 + 0.03 * t / 0.28)
    index = 0.5 + 2.5 * np.exp(-t / 0.05)
    beam = np.sin(phase(carrier) + index * np.sin(phase(carrier * 2)))
    hiss = band(rng.standard_normal(t.size), 3000, 7000) * decay(t, 0.01, 0.03) * 0.35
    return beam * decay(t, 0.004, 0.09) + hiss


def astronomer():
    # Sextante Estelar: a quick two-note star chime with a shimmer.
    t = timeline(0.3)
    out = np.zeros(t.size)
    for start, freq in ((0.0, 1568), (0.045, 2093)):
        local = np.clip(t - start, 0, None)
        gate = (t >= start).astype(float)
        tone = np.sin(2 * np.pi * freq * local) + 0.25 * np.sin(2 * np.pi * freq * 3 * local)
        out += gate * tone * decay(local, 0.002, 0.12) * (1 + 0.2 * np.sin(2 * np.pi * 30 * local))
    sparkle = highpass(rng.standard_normal(t.size), 6000) * decay(t, 0.002, 0.04) * 0.2
    return out * 0.6 + sparkle


def gardener():
    # Semeador: a round seed pop that bends upwards, with a little bubble.
    t = timeline(0.15)
    freq = 260 + 520 * np.clip(t / 0.05, 0, 1)
    pop = np.sin(phase(freq)) + 0.3 * np.sin(phase(freq * 2))
    bubble = band(rng.standard_normal(t.size), 900, 1600) * decay(t, 0.002, 0.03) * 0.4
    return lowpass(pop * decay(t, 0.003, 0.05), 3000) + bubble


def miner():
    # Perfuradora: a gritty drill burst and a crack of breaking crystal.
    t = timeline(0.17)
    freq = 90 + 50 * np.exp(-t / 0.06)
    saw = 2 * ((np.cumsum(freq) / SR) % 1.0) - 1
    grit = np.tanh(3 * saw) * (0.75 + 0.25 * np.sign(np.sin(2 * np.pi * 60 * t)))
    crack = band(rng.standard_normal(t.size), 1800, 3200) * decay(t, 0.001, 0.025) * 0.9
    return lowpass(grit, 2500) * decay(t, 0.002, 0.06) + crack


def sentinel():
    # Lança Eclipse: a deep falling hum, detuned body and a high corona shimmer.
    t = timeline(0.32)
    low = np.sin(phase(98 + 98 * np.exp(-t / 0.08)))
    body = sum(2 * ((392 * d * t) % 1.0) - 1 for d in (0.994, 1.006)) * 0.5
    shimmer = np.sin(2 * np.pi * 2637 * t) * (0.6 + 0.4 * np.sin(2 * np.pi * 18 * t)) * decay(t, 0.01, 0.15) * 0.3
    air = highpass(rng.standard_normal(t.size), 5000) * decay(t, 0.02, 0.08) * 0.12
    return low * decay(t, 0.006, 0.14) + lowpass(body, 900) * decay(t, 0.006, 0.12) * 0.5 + shimmer + air


def clockmaker():
    # Canhão de Corda: a ratchet of three ticks winding up, then a sprung brass twang.
    t = timeline(0.26)
    out = np.zeros(t.size)
    for k, start in enumerate((0.0, 0.022, 0.044)):
        local = np.clip(t - start, 0, None)
        gate = (t >= start).astype(float)
        out += gate * band(rng.standard_normal(t.size), 2500 + 600 * k, 5200) * np.exp(-local / 0.004) * 0.9
    local = np.clip(t - 0.06, 0, None)
    gate = (t >= 0.06).astype(float)
    freq = 620 * (1 + 0.08 * np.exp(-local / 0.03) * np.sin(2 * np.pi * 38 * local))
    twang = np.sin(phase(freq)) + 0.45 * np.sin(phase(freq * 2.76))
    return out + gate * twang * decay(local, 0.002, 0.07) * 0.8


def storm():
    # Bobina de Tesla: a crackling electric arc that snaps downwards.
    t = timeline(0.22)
    freq = 180 + 900 * np.exp(-t / 0.04)
    buzz = np.sign(np.sin(phase(freq) + 3 * np.sin(phase(freq * 1.5))))
    crackle = (rng.random(t.size) < 0.02).astype(float) * rng.standard_normal(t.size) * 3
    crackle = highpass(crackle, 2000) * decay(t, 0.001, 0.08)
    snap = highpass(rng.standard_normal(t.size), 4000) * np.exp(-t / 0.006) * 0.7
    return lowpass(buzz, 4200) * decay(t, 0.002, 0.05) * 0.6 + crackle + snap


def alchemist():
    # Frasco de Plasma: a glass clink, then bubbles popping upwards out of the flask.
    t = timeline(0.3)
    clink = (np.sin(2 * np.pi * 3520 * t) + 0.5 * np.sin(2 * np.pi * 5270 * t)) * decay(t, 0.001, 0.05) * 0.45
    out = clink
    for k, start in enumerate((0.02, 0.07, 0.11, 0.16)):
        local = np.clip(t - start, 0, None)
        gate = (t >= start).astype(float)
        freq = (420 + 170 * k) * (1 + 1.6 * np.clip(local / 0.035, 0, 1))
        out = out + gate * np.sin(phase(freq * gate)) * decay(local, 0.002, 0.022) * (0.9 - 0.15 * k)
    return lowpass(out, 7000)


def corsair():
    # Bacamarte Estelar: a boomy cannon thump with a burst of powder smoke.
    t = timeline(0.34)
    thump = np.sin(phase(55 + 170 * np.exp(-t / 0.03))) * decay(t, 0.002, 0.12)
    blast = lowpass(rng.standard_normal(t.size), 1800) * decay(t, 0.001, 0.05) * 1.3
    smoke = band(rng.standard_normal(t.size), 400, 1400) * decay(t, 0.03, 0.12) * 0.35
    return np.tanh(1.6 * (thump + blast)) + smoke


def archon():
    # Cetro Solar: a bright major chord flare that rises and glitters.
    t = timeline(0.36)
    rise = 1 + 0.04 * np.clip(t / 0.08, 0, 1)
    chord = sum(np.sin(phase(f * rise)) * g for f, g in ((523, 0.6), (659, 0.45), (784, 0.4), (1568, 0.25)))
    glitter = np.sin(2 * np.pi * 3136 * t) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 24 * t))) * decay(t, 0.02, 0.12) * 0.22
    air = highpass(rng.standard_normal(t.size), 6000) * decay(t, 0.03, 0.08) * 0.1
    return chord * decay(t, 0.012, 0.13) + glitter + air


def write(index, samples):
    samples = samples - samples.mean()
    fade = np.ones(samples.size)
    fade[-int(SR * 0.01):] = np.linspace(1, 0, int(SR * 0.01))
    samples = samples * fade
    samples = samples * TARGET_RMS / np.sqrt(np.mean(samples ** 2))
    peak = np.abs(samples).max()
    if peak > PEAK_LIMIT:
        # Soft-clip only the loudest transients instead of lowering the whole sound.
        samples = np.tanh(samples / peak * 1.4) / np.tanh(1.4) * PEAK_LIMIT
    path = os.path.join(ROOT, "audio", "sfx", "shot_%d.wav" % index)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        handle.writeframes((samples * 32767).astype("<i2").tobytes())
    print("shot_%d.wav  %.2fs" % (index, samples.size / SR))


if __name__ == "__main__":
    for i, recipe in enumerate((aurora, lighthouse, astronomer, gardener, miner, sentinel,
                                    clockmaker, storm, alchemist, corsair, archon)):
        write(i, recipe())
