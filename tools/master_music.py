"""Master the existing recordings, preserving every melody, arrangement and tempo.

Original OGGs remain untouched. Circular EQ/envelopes preserve the loop boundary.
Adds no new notes or drum patterns: extracts and lifts existing rhythmic transients.
Requires numpy and ffmpeg. Outputs audio/polished plus a numerical QA report.
"""
from pathlib import Path
import json
import subprocess
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'audio' / 'polished'
OUT.mkdir(exist_ok=True)
SR = 44100


def decode(path):
    data = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(path), '-f', 'f32le', '-ar', str(SR), '-ac', '2', '-'])
    return np.frombuffer(data, '<f4').reshape(-1, 2).astype(np.float64)


def band(f, center, width):
    return np.exp(-.5 * (np.log2(np.maximum(f, 1) / center) / width) ** 2)


report = []
for source in sorted((ROOT / 'audio').glob('music*.ogg')):
    original = decode(source)
    n = len(original)
    freq = np.fft.rfftfreq(n, 1 / SR)
    spectrum = np.fft.rfft(original, axis=0)
    # More kick/bass, less low-mid masking, and definition for existing lead lines.
    gentle = .45 if source.stem == 'music_menu' else 1.0
    eq_db = gentle * (3.1 * band(freq, 78, .8) + 1.8 * band(freq, 155, .6) - 1.4 * band(freq, 330, .65) + 1.7 * band(freq, 1450, .8) + .7 * band(freq, 4200, .65))
    shaped = np.fft.irfft(spectrum * (10 ** (eq_db / 20))[:, None], n=n, axis=0)
    low = np.fft.irfft(spectrum * np.exp(-(freq / 210) ** 4)[:, None], n=n, axis=0)
    # Detect actual low-end attacks; sustain and quiet passages do not receive the lift.
    hop = 256
    frames = np.arange(0, n, hop)
    energy = np.sqrt(np.add.reduceat(np.mean(low * low, axis=1), frames) / np.minimum(hop, n - frames) + 1e-12)
    slow = sum(np.roll(energy, shift) for shift in range(1, 15)) / 14
    attack = np.clip((energy / (slow + .006) - 1) * .75, 0, 1)
    attack = (attack + np.roll(attack, 1)) * .5
    envelope = np.interp(np.arange(n), np.append(frames, n), np.append(attack, attack[0]))
    shaped += low * envelope[:, None] * .9 * gentle
    # Gentle low-band saturation creates harmonics audible on small phone speakers.
    shaped += (np.tanh(low * 3) / 3 - low) * -.35 * gentle
    # Keep headroom and dynamic contrast rather than simply maximizing loudness.
    shaped -= np.mean(shaped, axis=0)
    shaped *= min(1.06, .79 / np.max(np.abs(shaped)))
    target = OUT / source.name
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(SR), '-ac', '2', '-i', '-', '-c:a', 'libvorbis', '-q:a', '6', str(target)], input=shaped.astype('<f4').tobytes(), check=True)
    encoded = decode(target)
    assert len(encoded) == n
    peak = float(np.max(np.abs(encoded)))
    correlation = float(np.corrcoef(original.flatten(), encoded.flatten())[0, 1])
    assert peak < .96 and correlation > .92
    row = {'track': source.name, 'seconds': n / SR, 'correlation_to_original': round(correlation, 5), 'peak_dbfs': round(20 * np.log10(peak), 2), 'original_rms': float(np.sqrt(np.mean(original ** 2))), 'master_rms': float(np.sqrt(np.mean(encoded ** 2))), 'loop_jump': float(np.max(np.abs(encoded[-1] - encoded[0])))}
    report.append(row)
    print(source.name, 'correlation', row['correlation_to_original'], 'peak', row['peak_dbfs'], flush=True)
(OUT / 'master_report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
