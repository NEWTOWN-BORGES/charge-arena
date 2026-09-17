"""Compose Charge Arena's two background loops from scratch (no samples, no licences).

    python tools/compose_music.py

Writes audio/music_menu.ogg ("Aurora Drift", 84 BPM) and audio/music_match.ogg
("Charge Circuit", 120 BPM). Every note is written modulo the loop length, and
reverb/delay are applied circularly, so each file loops without a seam.
Needs numpy, scipy and ffmpeg (libvorbis) on PATH.
"""
import os
import re
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy import ndimage, signal

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rng = np.random.default_rng(2026)


def hz(note):
    return 440.0 * 2 ** ((note - 69) / 12)


# ---------------------------------------------------------------- oscillators

def saw(freq, n):
    dt = np.broadcast_to(np.asarray(freq, dtype=np.float64) / SR, (n,))
    phase = (np.cumsum(dt) + rng.random()) % 1.0
    out = 2 * phase - 1
    wrap = phase < dt
    t = phase[wrap] / dt[wrap]
    out[wrap] -= t + t - t * t - 1
    wrap = phase > 1 - dt
    t = (phase[wrap] - 1) / dt[wrap]
    out[wrap] -= t * t + t + t + 1
    return out


def sine(freq, n, phase=0.0):
    dt = np.broadcast_to(np.asarray(freq, dtype=np.float64) / SR, (n,))
    return np.sin(2 * np.pi * (np.cumsum(dt) + phase))


def noise(n):
    return rng.standard_normal(n)


def envelope(n, attack, decay, sustain, release, gate):
    t = np.arange(n) / SR
    body = np.where(t < attack, t / max(attack, 1e-4), sustain + (1 - sustain) * np.exp(-(t - attack) / max(decay, 1e-4)))
    held = t >= gate
    if held.any():
        at_gate = body[min(int(gate * SR), n - 1)]
        body[held] = at_gate * np.exp(-(t[held] - gate) / max(release / 5, 1e-4))
    return body


# -------------------------------------------------------------------- filters

def biquad(kind, cutoff, q=0.707):
    w0 = 2 * np.pi * min(cutoff, SR * 0.45) / SR
    alpha = np.sin(w0) / (2 * q)
    cos = np.cos(w0)
    if kind == "low":
        b = [(1 - cos) / 2, 1 - cos, (1 - cos) / 2]
    elif kind == "high":
        b = [(1 + cos) / 2, -(1 + cos), (1 + cos) / 2]
    else:
        b = [alpha, 0, -alpha]
    a = [1 + alpha, -2 * cos, 1 - alpha]
    return np.array(b) / a[0], np.array(a) / a[0]


def filt(x, kind, cutoff, q=0.707):
    b, a = biquad(kind, cutoff, q)
    return signal.lfilter(b, a, x)


def sweep(x, cutoffs, q=0.8, block=128):
    """Low-pass whose cutoff follows `cutoffs(t_seconds)` block by block."""
    out = np.empty_like(x)
    zi = np.zeros(2)
    for start in range(0, len(x), block):
        b, a = biquad("low", cutoffs(start / SR), q)
        out[start:start + block], zi = signal.lfilter(b, a, x[start:start + block], zi=zi)
    return out


# ------------------------------------------------------------------ the track

class Track:
    def __init__(self, bpm, bars):
        self.beat = int(round(SR * 60 / bpm))
        self.length = self.beat * 4 * bars
        self.dry = np.zeros((2, self.length))
        self.verb = np.zeros((2, self.length))
        self.echo = np.zeros((2, self.length))

    def at(self, bar, beat=0.0):
        return int(round((bar * 4 + beat) * self.beat))

    def add(self, sound, start, gain=1.0, pan=0.0, verb=0.0, echo=0.0):
        sound = np.asarray(sound)
        if sound.ndim == 1:
            angle = (pan + 1) * np.pi / 4
            sound = np.vstack([sound * np.cos(angle), sound * np.sin(angle)]) * np.sqrt(2)
        index = (start + np.arange(sound.shape[1])) % self.length
        for bus, amount in ((self.dry, gain), (self.verb, gain * verb), (self.echo, gain * echo)):
            if amount:
                np.add.at(bus[0], index, sound[0] * amount)
                np.add.at(bus[1], index, sound[1] * amount)

    def pump(self, depth, recover=0.22):
        """Sidechain curve locked to the beat, so it loops cleanly too."""
        t = np.arange(self.beat) / SR
        rise = np.clip(t / 0.004, 0, 1)
        curve = 1 - depth * rise * (1 - np.clip(t / recover, 0, 1)) ** 2
        return np.tile(curve, self.length // self.beat)[: self.length]


def circular(x, response):
    return np.fft.irfft(np.fft.rfft(x) * response, n=len(x))


def reverb(bus, rt60, damping, width=0.3):
    n = int(SR * min(rt60 * 1.3, 5.0))
    t = np.arange(n) / SR
    out = np.zeros_like(bus)
    for ch in range(2):
        grain = noise(n)
        low = filt(grain, "low", damping)
        ir = low * np.exp(-6.91 * t / rt60) + 0.4 * (grain - low) * np.exp(-6.91 * t / (rt60 * 0.3))
        ir *= np.clip(t / 0.012, 0, 1)
        ir = np.concatenate([np.zeros(int(SR * 0.018)), ir])
        ir /= np.sqrt(np.sum(ir ** 2))
        source = bus[ch] + width * bus[1 - ch]
        out[ch] = circular(source, np.fft.rfft(ir, n=bus.shape[1]))
    return out


def ping_pong(bus, delay, feedback, tone):
    b, a = biquad("low", tone)
    freqs = np.fft.rfftfreq(bus.shape[1], 1 / SR)
    _, response = signal.freqz(b, a, worN=freqs, fs=SR)
    mono = bus[0] + bus[1]
    spectrum = np.fft.rfft(mono)
    out = np.zeros_like(bus)
    for k in range(1, 7):
        spectrum = spectrum * response
        echo = np.roll(np.fft.irfft(spectrum, n=len(mono)), delay * k) * feedback ** (k - 1)
        out[k % 2] += echo
    return out


def limit(mix, ceiling_db=-2.0):
    """Look-ahead peak limiter; every window wraps so the loop point stays seamless."""
    ceiling = 10 ** (ceiling_db / 20)
    width = int(SR * 0.004)
    peak = ndimage.maximum_filter1d(np.abs(mix).max(axis=0), size=2 * width + 1, mode="wrap")
    gain = np.minimum(1.0, ceiling / np.maximum(peak, 1e-9))
    gain = ndimage.minimum_filter1d(gain, size=width, mode="wrap")
    window = np.hanning(width)
    gain = ndimage.convolve1d(gain, window / window.sum(), mode="wrap")
    return mix * gain


def phone_eq(mix):
    """Zero-phase, loop-safe tone shaping: trim rumble phones cannot play, lift presence."""
    f = np.maximum(np.fft.rfftfreq(mix.shape[1], 1 / SR), 1.0)
    gain_db = -24 * np.maximum(0.0, np.log2(38 / f))
    gain_db -= 5 / (1 + (f / 150) ** 2)
    gain_db += 3 * np.exp(-0.5 * (np.log2(f / 3000) / 0.9) ** 2)
    response = 10 ** (gain_db / 20)
    response[0] = 0.0
    return np.vstack([circular(ch, response) for ch in mix])


def write_wav(path, mix):
    data = (np.clip(mix, -1, 1).T * 32767).astype("<i2")
    with wave.open(path, "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        handle.writeframes(data.tobytes())


def loudness(path):
    result = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128=peak=true", "-f", "null", "-"], capture_output=True, text=True)
    text = result.stderr[result.stderr.rfind("Summary:"):]
    lufs = float(re.search(r"I:\s+(-?[\d.]+) LUFS", text).group(1))
    peak = float(re.search(r"Peak:\s+(-?[\d.]+) dBFS", text).group(1))
    return lufs, peak


def finish(track, name, target_lufs, verb_gain, echo_gain):
    mix = track.dry + verb_gain * reverb_out(track) + echo_gain * echo_out(track)
    mix = phone_eq(mix)
    mix /= np.abs(mix).max()
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, name + ".wav")
        for _ in range(3):
            write_wav(wav, limit(mix))
            lufs, _ = loudness(wav)
            mix *= 10 ** ((target_lufs - lufs) / 20)
        write_wav(wav, limit(mix))
        lufs, peak = loudness(wav)
        out = os.path.join(ROOT, "audio", name + ".ogg")
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", out], check=True)
    print(f"{name}: {track.length / SR:.3f}s  {lufs:.1f} LUFS  true peak {peak:.1f} dBTP  {os.path.getsize(out) / 1e6:.2f} MB")


def reverb_out(track):
    return reverb(track.verb, track.rt60, track.damping)


def echo_out(track):
    return ping_pong(track.echo, track.beat * 3 // 4, track.feedback, track.echo_tone)


# ---------------------------------------------------------------- instruments

def pad(notes, seconds, bright, gain_per_voice=0.16):
    n = int(SR * (seconds + 3.0))
    stereo = np.zeros((2, n))
    env = envelope(n, 1.1, 1.5, 0.85, 2.8, seconds)
    for i, note in enumerate(notes):
        for detune, side in ((-9, 0), (0, None), (9, 1)):
            voice = saw(hz(note) * 2 ** (detune / 1200), n)
            voice = sweep(voice, lambda s, o=i: bright * (0.75 + 0.25 * np.sin(s * 0.9 + o)), q=0.6)
            voice *= env * gain_per_voice
            if side is None:
                stereo += voice * 0.7
            else:
                stereo[side] += voice
                stereo[1 - side] += voice * 0.35
    return stereo


def sub_bass(note, seconds):
    n = int(SR * (seconds + 0.6))
    f = hz(note)
    tone = 0.75 * sine(f, n) + 0.45 * sine(2 * f, n) + 0.2 * sine(3 * f, n) + 0.12 * np.tanh(3 * sine(f, n))
    return tone * envelope(n, 0.06, 0.8, 0.8, 0.5, seconds)


def pluck(note, brightness=2600, decay=0.32, length=1.2):
    n = int(SR * length)
    f = hz(note)
    tone = 0.6 * saw(f, n) + 0.4 * sine(f, n) + 0.25 * sine(2 * f, n)
    env = envelope(n, 0.003, decay, 0.0, 0.1, length)
    return sweep(tone, lambda s: 350 + brightness * np.exp(-s / 0.09), q=1.1) * env


def bell(note, seconds):
    n = int(SR * (seconds + 3.2))
    t = np.arange(n) / SR
    f = hz(note)
    index = 0.4 + 2.2 * np.exp(-t / 0.35)
    tone = np.sin(2 * np.pi * f * t + index * np.sin(2 * np.pi * 3.5 * f * t))
    return tone * np.exp(-t / 1.4) * np.clip(t / 0.004, 0, 1)


def kick(soft=False):
    n = int(SR * 0.45)
    t = np.arange(n) / SR
    pitch = 54 + (115 if soft else 150) * np.exp(-t / 0.03)
    body = sine(pitch, n) * np.exp(-t / (0.11 if soft else 0.15))
    click = filt(noise(n), "high", 2500) * np.exp(-t / 0.005) * (0.08 if soft else 0.4)
    return np.tanh((body + click) * 1.6)


def snare(level=1.0):
    n = int(SR * 0.3)
    t = np.arange(n) / SR
    body = sine(185 * (1 + 0.4 * np.exp(-t / 0.01)), n) * np.exp(-t / 0.06) * 0.6
    hiss = filt(noise(n), "band", 1900, 0.8) * np.exp(-t / 0.09)
    return (body + hiss * 1.3) * level


def hat(length=0.045, level=1.0):
    n = int(SR * max(length * 4, 0.05))
    t = np.arange(n) / SR
    return filt(noise(n), "high", 7500) * np.exp(-t / length) * level


def lead(note, seconds):
    n = int(SR * (seconds + 0.4))
    t = np.arange(n) / SR
    vibrato = 2 ** ((12 * np.clip((t - 0.2) / 0.3, 0, 1) * np.sin(2 * np.pi * 5.4 * t)) / 1200)
    f = hz(note) * vibrato
    tone = 0.5 * saw(f * 2 ** (6 / 1200), n) + 0.5 * saw(f * 2 ** (-6 / 1200), n) + 0.12 * sine(f / 2, n)
    tone = filt(tone, "low", 3400, 0.9)
    return tone * envelope(n, 0.012, 0.3, 0.75, 0.18, seconds)


def bass_note(note, seconds):
    n = int(SR * (seconds + 0.08))
    f = hz(note)
    tone = saw(f, n) * 0.7 + sine(f, n) * 0.6
    tone = sweep(tone, lambda s: 420 + 2200 * np.exp(-s / 0.07), q=1.0)
    return tone * envelope(n, 0.004, 0.18, 0.6, 0.05, seconds)


def swell(seconds, start_hz, end_hz, rising=True):
    n = int(SR * seconds)
    s = np.arange(n) / n
    shape = s ** 2 if rising else (1 - s) ** 3
    centre = start_hz * (end_hz / start_hz) ** s
    grain = noise(n)
    out = np.empty(n)
    zi = np.zeros(2)
    for start in range(0, n, 256):
        b, a = biquad("band", centre[start], 1.2)
        out[start:start + 256], zi = signal.lfilter(b, a, grain[start:start + 256], zi=zi)
    return out * shape


def scanner(length=0.7):
    n = int(SR * length)
    t = np.arange(n) / SR
    glide = 1700 * (1.6 ** (t / length))
    return sine(glide, n) * (0.55 + 0.45 * np.sin(2 * np.pi * 17 * t)) * np.exp(-t / 0.22) * np.clip(t / 0.03, 0, 1)


# ------------------------------------------------------------------ the songs

def aurora_drift():
    """Menu: floating D-dorian pads, a patient arpeggio and FM bells."""
    track = Track(84, 16)
    track.rt60, track.damping, track.feedback, track.echo_tone = 3.8, 4200, 0.45, 2800
    bar = track.beat * 4 / SR
    chords = [
        ([53, 57, 60, 64], 38), ([50, 53, 57, 60], 34), ([58, 62, 65, 69], 43), ([55, 57, 62, 64], 45),
        ([53, 57, 60, 64], 38), ([50, 53, 57, 60], 34), ([55, 57, 62, 64], 36), ([57, 61, 64, 67], 33),
    ]
    for i, (notes, root) in enumerate(chords):
        start = track.at(i * 2)
        track.add(pad(notes, bar * 2, 2600), start, 0.3, verb=0.55)
        track.add(sub_bass(root, bar * 2 - 0.1), start, 0.24, verb=0.05)
        if i >= 2:
            tones = [n + 12 for n in notes] + [notes[0] + 24]
            for step, pick in enumerate([0, 2, 1, 3, 2, 4, 3, 1] * 2):
                accent = 1.0 if step % 4 == 0 else 0.72
                pan = -0.35 if step % 2 == 0 else 0.35
                track.add(pluck(tones[pick], 2100, 0.28), start + step * track.beat // 2, 0.12 * accent, pan, verb=0.45, echo=0.35)
    melody = [(8, 0, 81, 3), (8, 3, 76, 1), (9, 0, 74, 2), (9, 2, 77, 2), (10, 0, 84, 3), (10, 3, 81, 1), (11, 0, 77, 4),
              (12, 0, 76, 2), (12, 2, 79, 2), (13, 0, 81, 4), (14, 0, 74, 2), (14, 2, 76, 2), (15, 0, 73, 2), (15, 2, 76, 2)]
    for bar_index, beat, note, beats in melody:
        track.add(bell(note, beats * track.beat / SR), track.at(bar_index, beat), 0.1, pan=0.15, verb=0.65, echo=0.25)
    for bar_index in range(8, 16):
        for beat in (0, 2):
            track.add(kick(soft=True), track.at(bar_index, beat), 0.3)
        for beat in (0.5, 1.5, 2.5, 3.5):
            track.add(hat(0.03), track.at(bar_index, beat), 0.035, pan=0.3, verb=0.3)
    for bar_index in (3, 7, 11, 15):
        track.add(scanner(), track.at(bar_index, 3.25), 0.035, pan=-0.4, verb=0.5, echo=0.6)
    # Airy hiss that breathes twice per loop; its period divides the loop exactly.
    for ch in range(2):
        air = filt(noise(track.length), "band", 3600, 0.7)
        drift = 0.5 + 0.5 * np.sin(2 * np.pi * 2 * np.arange(track.length) / track.length + ch)
        track.verb[ch] += air * drift * 0.012
    finish(track, "music_menu", -19.0, 0.55, 0.35)


def charge_circuit():
    """Match: A-minor synthwave pulse with an arp, a lead and a loop-back fill."""
    track = Track(120, 32)
    track.rt60, track.damping, track.feedback, track.echo_tone = 1.9, 5200, 0.38, 3200
    beat = track.beat / SR
    progression = [([57, 60, 64, 67], 45), ([53, 57, 60, 64], 41), ([55, 60, 64, 67], 36), ([55, 59, 62, 65], 43)]
    finale = [([53, 57, 62, 65], 38), ([53, 57, 60, 64], 41), ([52, 55, 59, 64], 40), ([52, 56, 59, 64], 40)]
    pads = Track(120, 32)
    basses = Track(120, 32)
    for section in range(4):
        chords = finale if section == 3 else progression
        for i, (notes, root) in enumerate(chords):
            start = track.at(section * 8 + i * 2)
            pads.add(pad(notes, beat * 8, 3600, 0.12), start, 1.0, verb=0.3)
            pattern = [0, 12, 0, 12, 0, 12, 0, 12] if section < 3 else [0, 0, 12, 0, 0, 12, 0, 12]
            for bar_offset in range(2):
                for step, jump in enumerate(pattern):
                    accent = 1.0 if step % 2 == 0 else 0.8
                    basses.add(bass_note(root + jump, beat * 0.42), start + (bar_offset * 8 + step) * track.beat // 2, 0.5 * accent)
            if section >= 1:
                tones = [n + 12 for n in notes] + [notes[0] + 24]
                arp_gain = 0.1 if section == 2 else 0.14
                for step in range(32):
                    pick = [0, 1, 2, 3, 1, 2, 3, 4][step % 8]
                    pan = [-0.45, 0.45][step % 2]
                    track.add(pluck(tones[pick], 3000, 0.12, 0.5), start + step * track.beat // 4, arp_gain, pan, verb=0.25, echo=0.3)
    pad_curve = pads.pump(0.6)
    bass_curve = basses.pump(0.4, 0.14)
    track.dry += pads.dry * pad_curve * 0.9 + basses.dry * bass_curve * 0.55
    track.verb += pads.verb * pad_curve * 0.9
    melodies = [
        (16, [(0, 76, 1.5), (1.5, 74, 0.5), (2, 72, 1), (3, 76, 1), (4, 81, 3), (7, 79, 1), (8, 77, 1.5), (9.5, 76, 0.5), (10, 72, 2),
              (12, 69, 1), (13, 72, 1), (14, 74, 2), (16, 76, 1.5), (17.5, 79, 0.5), (18, 76, 1), (19, 74, 1), (20, 72, 2), (22, 74, 1),
              (23, 76, 1), (24, 74, 2), (26, 71, 2), (28, 67, 1), (29, 71, 1), (30, 74, 1), (31, 76, 1)]),
        (24, [(0, 77, 2), (2, 81, 2), (4, 86, 3), (7, 84, 1), (8, 81, 2), (10, 84, 1), (11, 81, 1), (12, 77, 4), (16, 79, 2), (18, 83, 2),
              (20, 88, 2), (22, 86, 2), (24, 83, 2), (26, 80, 2), (28, 76, 3)]),
    ]
    for first_bar, notes in melodies:
        for offset, note, beats in notes:
            track.add(lead(note, beats * beat * 0.92), track.at(first_bar, offset), 0.16, pan=0.05, verb=0.28, echo=0.22)
    for bar_index in range(32):
        for b in range(4):
            track.add(kick(), track.at(bar_index, b), 0.85)
        if bar_index >= 4 and bar_index != 31:
            for b in (1, 3):
                track.add(snare(), track.at(bar_index, b), 0.42, verb=0.22)
        for b in (0.5, 1.5, 2.5, 3.5):
            track.add(hat(), track.at(bar_index, b), 0.13, pan=0.25)
        if bar_index >= 16:
            for b in (0.25, 0.75, 1.25, 1.75, 2.25, 2.75, 3.25, 3.75):
                track.add(hat(0.02), track.at(bar_index, b), 0.05, pan=-0.3)
        if bar_index >= 8:
            track.add(hat(0.22), track.at(bar_index, 3.5), 0.08, pan=0.25, verb=0.2)
    # Last bar: a snare roll that lands back on bar 1.
    track.add(snare(), track.at(31, 1), 0.42, verb=0.22)
    for step in range(8):
        track.add(snare(0.35 + 0.65 * step / 7), track.at(31, 2 + step * 0.25), 0.32, verb=0.2)
    for bar_index in (0, 16, 24):
        track.add(swell(1.8, 9000, 3000, rising=False), track.at(bar_index), 0.1, verb=0.4)
    track.add(swell(beat * 8, 400, 7000), track.at(30), 0.07, verb=0.3)
    finish(track, "music_match", -17.0, 0.4, 0.3)


if __name__ == "__main__":
    which = sys.argv[1:] or ["menu", "match"]
    if "menu" in which:
        aurora_drift()
    if "match" in which:
        charge_circuit()
