"""Original, deterministic weapon Foley; no third-party samples.

Bakes the established skin voice into a transient/body/energy/room mix.
Three variations share loudness and duration, avoiding fatigue during rapid fire.
Run from the repository root with Python + numpy.
"""
from pathlib import Path
import wave
import numpy as np

RATE = 22050
OUT = Path('audio/sfx/feedback')
OUT.mkdir(parents=True, exist_ok=True)


def write(name, signal):
    signal -= np.mean(signal)
    signal *= min(1.0, 0.78 / max(0.001, np.max(np.abs(signal))))
    signal[:44] *= np.linspace(0, 1, 44)
    signal[-220:] *= np.linspace(1, 0, 220)
    with wave.open(str(OUT / (name + '.wav')), 'wb') as target:
        target.setparams((1, 2, RATE, len(signal), 'NONE', 'not compressed'))
        target.writeframes((signal * 32767).astype('<i2').tobytes())


def bed(seconds, seed):
    t = np.arange(int(seconds * RATE)) / RATE
    noise = np.random.default_rng(seed).uniform(-1, 1, len(t))
    return t, noise


for skin in range(12):
    with wave.open(f'audio/sfx/shot_{skin}.wav', 'rb') as source:
        assert source.getsampwidth() == 2
        original = np.frombuffer(source.readframes(source.getnframes()), '<i2').astype(float) / 32768
        original = original.reshape(-1, source.getnchannels()).mean(axis=1)
        rate = source.getframerate()
    for variant in range(3):
        t, noise = bed(0.34, skin * 19 + variant)
        voice = np.interp(t * (1 + (variant - 1) * .015), np.arange(len(original)) / rate, original, right=0)
        snap = noise * np.exp(-t * 135) * .43
        body = np.sin(2 * np.pi * (112 * t + 3.5 * (1 - np.exp(-t * 24)))) * np.exp(-t * 24) * .40
        energy = np.sin(2 * np.pi * (480 * t + 5 * (1 - np.exp(-t * 30)))) * np.exp(-t * 39) * .12
        dry = snap + body + energy + voice * .32
        room = np.zeros_like(t)
        for delay, gain in [(.037, .12), (.061, .075), (.089, .04)]:
            offset = int(delay * RATE)
            room[offset:] += dry[:-offset] * gain
        write(f'shot_{skin}_{variant}', dry + room)

for variant in range(3):
    t, noise = bed(.30, 503 + variant)
    thock = .48 * np.sin(2 * np.pi * (174 * t + 1.4 * (1 - np.exp(-t * 45)))) * np.exp(-t * 40)
    thock += .30 * noise * np.exp(-t * 95)
    write(f'hit_{variant}', thock)
    delayed = np.maximum(0, t - .025)
    crack = noise * np.exp(-delayed * 20) * (t >= .025) * .40
    write(f'break_{variant}', thock + crack + .15 * np.sin(2 * np.pi * 76 * t) * np.exp(-t * 16))

t, noise = bed(.16, 880)
metal = sum(np.sin(2 * np.pi * f * t) * a * np.exp(-t * decay) for f, a, decay in [(1470,.24,40),(2301,.11,55),(3617,.06,75)])
write('metal', metal + noise * np.exp(-t * 190) * .13)
write('ricochet', metal * .62 + np.sin(2 * np.pi * (1800 * t - 2100 * t*t)) * np.exp(-t * 65) * .10)
t, noise = bed(.25, 881)
write('shield', .42 * np.sin(2 * np.pi * (120 * t + 6 * (1 - np.exp(-t * 18)))) * np.exp(-t * 19) + noise * .08 * np.exp(-t * 50))
t, noise = bed(.48, 882)
write('defense', .48 * np.sin(2 * np.pi * (65 * t + 4 * (1 - np.exp(-t * 20)))) * np.exp(-t * 11) + noise * .25 * np.exp(-t * 20))
print('46 original feedback samples generated; PCM peaks <= -2.1 dBFS.')
