"""Compose ten complete, independent and seamless skin themes.

Every theme has its own drums, bass, harmony, arrangement and lead instruments.
No Charge Circuit audio is mixed underneath and no third-party samples are used.
All events wrap at the 64-second boundary so Godot can loop each theme.
"""
from pathlib import Path
import subprocess
import sys
import numpy as np

SR = 44100
DURATION = 64.0
N = int(SR * DURATION)
ROOT = Path(__file__).resolve().parents[1]
RNG = np.random.default_rng(4071)
BEAT = 0.5  # 120 BPM


def hz(note):
    return 440.0 * 2 ** ((note - 69) / 12)


def add(bus, sound, at, gain=1.0, pan=0.0):
    start = int(round(at * SR)) % N
    index = (start + np.arange(len(sound))) % N
    left = np.sqrt((1.0 - pan) * 0.5)
    right = np.sqrt((1.0 + pan) * 0.5)
    np.add.at(bus[0], index, sound * gain * left)
    np.add.at(bus[1], index, sound * gain * right)


def echo(bus, seconds, feedback):
    wet = np.zeros_like(bus)
    delay = int(seconds * SR)
    for repeat in range(1, 5):
        amount = feedback ** repeat
        wet[repeat % 2] += np.roll(bus[1 - repeat % 2], delay * repeat) * amount
    return wet


def bell(note, length=1.8):
    t = np.arange(int(length * SR)) / SR
    f = hz(note)
    tone = (np.sin(2*np.pi*f*t + 2.5*np.sin(2*np.pi*f*2.01*t))
            + 0.35*np.sin(2*np.pi*f*3.98*t))
    return tone * np.exp(-t * 2.7) * np.minimum(t / 0.004, 1.0)


def space_pluck(note, length=1.1):
    t = np.arange(int(length * SR)) / SR
    f = hz(note)
    vibrato = 1 + 0.002 * np.sin(2*np.pi*4.3*t)
    tone = np.sin(2*np.pi*f*vibrato*t) + 0.45*np.sin(2*np.pi*f*2.003*t)
    return tone * np.exp(-t * 4.2) * np.minimum(t / 0.012, 1.0)


def wood(note, length=0.55):
    t = np.arange(int(length * SR)) / SR
    f = hz(note)
    body = np.sin(2*np.pi*f*t) + 0.42*np.sin(2*np.pi*f*3.0*t)
    click = RNG.standard_normal(len(t)) * np.exp(-t * 90)
    return (body * np.exp(-t * 7.5) + click * 0.08) * np.minimum(t / 0.002, 1.0)


def metal(note=74, length=0.75):
    t = np.arange(int(length * SR)) / SR
    f = hz(note)
    partials = sum(np.sin(2*np.pi*f*ratio*t + RNG.random()*6.28) * gain
                   for ratio, gain in [(1, .4), (1.41, .32), (2.73, .22), (4.11, .13)])
    grit = RNG.standard_normal(len(t)) * 0.12
    return (partials + grit) * np.exp(-t * 8.5) * np.minimum(t / 0.001, 1.0)


def brass(note, length=0.72):
    t = np.arange(int(length * SR)) / SR
    f = hz(note)
    phase = (f*t) % 1.0
    saw = 2*phase - 1
    tone = .58*saw + .55*np.sin(2*np.pi*f*t) + .18*np.sin(2*np.pi*f*0.5*t)
    env = np.minimum(t/.06, 1.0) * np.exp(-np.maximum(t-.34, 0)*6)
    # Gentle one-pole low pass gives a dark, horn-like edge.
    out = np.empty_like(tone)
    state = 0.0
    alpha = 0.18
    for i, value in enumerate(tone):
        state += alpha * (value - state)
        out[i] = state
    return np.tanh(out * 1.3) * env


def kick(weight=1.0):
    t = np.arange(int(.42 * SR)) / SR
    phase = 2*np.pi*(48*t + 95*.027*(1-np.exp(-t/.027)))
    body = np.sin(phase) * np.exp(-t/(.12 + .035*weight))
    click = RNG.standard_normal(len(t)) * np.exp(-t*130) * .12
    return np.tanh((body + click) * (1.4 + .35*weight))


def snare(soft=False):
    t = np.arange(int(.30 * SR)) / SR
    noise = RNG.standard_normal(len(t))
    # Difference filter removes the low rumble without scipy.
    hiss = np.concatenate([[noise[0]], np.diff(noise)])
    body = np.sin(2*np.pi*178*t) * np.exp(-t/.055)
    return (hiss * (.22 if soft else .34) * np.exp(-t/.075) + body*.35)


def hat(open_hat=False):
    length = .34 if open_hat else .09
    t = np.arange(int(length * SR)) / SR
    noise = RNG.standard_normal(len(t))
    bright = np.concatenate([[noise[0]], np.diff(noise)])
    return bright * np.exp(-t/(.11 if open_hat else .022)) * .24


def bass(note, length=.46, rough=0.0):
    t = np.arange(int((length + .08) * SR)) / SR
    f = hz(note)
    phase = (f*t) % 1.0
    tone = .82*np.sin(2*np.pi*f*t) + rough*(2*phase-1)
    env = np.minimum(t/.008, 1.0) * np.exp(-np.maximum(t-length*.72, 0)/.11)
    return np.tanh(tone*(1.0 + rough)) * env


def pad_tone(note, length=4.0, colour=0.5):
    t = np.arange(int((length + .7) * SR)) / SR
    f = hz(note)
    detune = 2 ** (5/1200)
    tone = (np.sin(2*np.pi*f*t) + .55*np.sin(2*np.pi*f*detune*t)
            + colour*.28*np.sin(2*np.pi*f*2.002*t))
    attack = np.minimum(t/.55, 1.0)
    release = np.exp(-np.maximum(t-length, 0)/.45)
    breathe = .82 + .18*np.sin(2*np.pi*t/4)
    return tone * attack * release * breathe * .42


def pulse(note, length=.38, bright=1.0):
    t = np.arange(int((length + .12) * SR)) / SR
    f = hz(note)
    phase = (f*t) % 1.0
    square = np.where(phase < .5, 1.0, -1.0)
    tone = .65*np.sin(2*np.pi*f*t) + .22*bright*square
    return np.tanh(tone) * np.minimum(t/.006, 1.0) * np.exp(-np.maximum(t-length*.45, 0)/.12)


def one_pole(x, alpha):
    out = np.empty_like(x)
    state = 0.0
    for i, value in enumerate(x):
        state += alpha * (value - state)
        out[i] = state
    return out


def music_box(note, length=1.4):
    t = np.arange(int(length * SR)) / SR
    f = hz(note)
    tone = (np.sin(2*np.pi*f*t) + .3*np.sin(2*np.pi*f*4.0*t)*np.exp(-t*9)
            + .12*np.sin(2*np.pi*f*6.8*t)*np.exp(-t*14))
    return tone * np.exp(-t * 3.4) * np.minimum(t / 0.0015, 1.0)


def zap_lead(note, length=.2):
    t = np.arange(int(length * SR)) / SR
    f = hz(note)
    saw = (2*((f*t) % 1.0) - 1) * .6 + (2*((f*1.006*t) % 1.0) - 1) * .4
    return one_pole(saw, .35) * np.exp(-t * 11) * np.minimum(t / 0.002, 1.0)


def glass_drop(note, length=.6):
    t = np.arange(int(length * SR)) / SR
    f = hz(note)
    bend = 1 + .06*np.exp(-t/.02)
    tone = np.sin(2*np.pi*f*np.cumsum(bend)/SR) + .35*np.sin(2*np.pi*f*2.76*t)*np.exp(-t*12)
    return tone * np.exp(-t * 6.0) * np.minimum(t / 0.002, 1.0)


def squeezebox(note, length=.5):
    t = np.arange(int(length * SR)) / SR
    f = hz(note)
    ph = np.cumsum(f * (1 + .004*np.sin(2*np.pi*5.5*t))) / SR
    reed = sum(np.where((ph*d) % 1.0 < .5, 1.0, -1.0) for d in (1.0, 1.006)) * .3
    tone = one_pole(reed + .5*np.sin(2*np.pi*ph), .22)
    env = np.minimum(t/.03, 1.0) * np.exp(-np.maximum(t-length*.7, 0)/.05)
    return tone * env


def choir(note, length=4.0):
    t = np.arange(int((length + .8) * SR)) / SR
    f = hz(note)
    vowel = sum(np.sin(2*np.pi*f*k*t*(1 + .003*np.sin(2*np.pi*(4.7+k*.3)*t))) * g
                for k, g in [(1, 1.0), (2, .45), (3, .28), (4, .12), (5, .07)])
    attack = np.minimum(t/.7, 1.0)
    release = np.exp(-np.maximum(t-length, 0)/.5)
    return vowel * attack * release * .32


CHORDS = [
    ([45, 52, 57, 60, 64], 45),  # Am
    ([41, 48, 53, 57, 60], 41),  # Fmaj7
    ([48, 52, 55, 60, 64], 40),  # C/E
    ([43, 50, 55, 59, 62], 43),  # G
]


def foundation(style):
    """A complete rhythm section and harmonic arrangement unique to each style."""
    bus = np.zeros((2, N))
    for bar in range(32):
        notes, root = CHORDS[(bar//2) % 4]
        # First bar uses an open A/E fifth, avoiding a clashing third while the
        # D-dorian menu track is still fading out.
        if bar % 2 == 0:
            harmony = [45, 52, 57] if bar == 0 else notes
            for voice, note in enumerate(harmony):
                colour = [.85, .35, .58, .25, .72, .5, .2, .65, .4, .9][style-1]
                pan = (voice/(max(len(harmony)-1, 1))-.5)*.9
                add(bus, pad_tone(note, 4.0, colour), bar*4*BEAT, [.065,.075,.07,.045,.08,.06,.05,.065,.06,.085][style-1], pan)

        if style == 1:  # Faroleiro: confident electro pulse
            for beat in range(4):
                add(bus, kick(.75), (bar*4+beat)*BEAT, .34)
                add(bus, bass(root + (12 if beat == 3 else 0)), (bar*4+beat)*BEAT, .15, -.08)
                add(bus, hat(False), (bar*4+beat+.5)*BEAT, .08, .35)
            for beat in [1, 3]: add(bus, snare(True), (bar*4+beat)*BEAT, .20, -.15)
        elif style == 2:  # Astrónomo: floating half-time with a rolling low pulse
            for beat in [0, 2]: add(bus, kick(.55), (bar*4+beat)*BEAT, .28)
            add(bus, snare(True), (bar*4+2)*BEAT, .16, .25)
            for slot in [0, 1.5, 2.5, 3.5]: add(bus, bass(root, .58), (bar*4+slot)*BEAT, .12, -.25)
            for slot in [.5, 1.5, 2.5, 3.5]: add(bus, hat(False), (bar*4+slot)*BEAT, .045, .65)
        elif style == 3:  # Jardineiro: warm, lightly syncopated organic groove
            for beat in [0, 2.5]: add(bus, kick(.45), (bar*4+beat)*BEAT, .28)
            for beat in [1, 3]: add(bus, wood(72, .25), (bar*4+beat)*BEAT, .12, .4)
            for slot in [0, .75, 1.5, 2.5, 3.25]: add(bus, bass(root, .34), (bar*4+slot)*BEAT, .105, -.2)
            for slot in [.5, 1.5, 2.5, 3.5]: add(bus, hat(False), (bar*4+slot)*BEAT, .035, -.5)
        elif style == 4:  # Mineiro: heavy industrial drive
            for slot in [0, 1.5, 2, 3]: add(bus, kick(1.2), (bar*4+slot)*BEAT, .38)
            for beat in [1, 3]: add(bus, snare(False), (bar*4+beat)*BEAT, .23, -.25)
            for beat in range(4): add(bus, bass(root + (12 if beat == 3 else 0), .42, .5), (bar*4+beat)*BEAT, .16)
            for slot in [.5, 1.5, 2.5, 3.5]: add(bus, hat(False), (bar*4+slot)*BEAT, .07, .55)
        elif style == 6:  # Relojoeiro: clockwork shuffle with a ticking rim
            for beat in [0, 2]: add(bus, kick(.6), (bar*4+beat)*BEAT, .3)
            for beat in [1, 3]: add(bus, snare(True), (bar*4+beat)*BEAT, .15, .2)
            for slot in range(8):
                add(bus, metal(98, .06), (bar*4 + slot*.5 + (.08 if slot % 2 else 0))*BEAT, .05, -.6 if slot % 2 else .6)
            for slot in [0, 1.5, 2, 3.5]: add(bus, bass(root, .3), (bar*4+slot)*BEAT, .13, -.1)
        elif style == 7:  # Caça-Trovões: fast electric drive in sixteenths
            for beat in range(4): add(bus, kick(.9), (bar*4+beat)*BEAT, .34)
            for beat in [1, 3]: add(bus, snare(False), (bar*4+beat)*BEAT, .2, .1)
            for slot in range(16): add(bus, hat(slot % 4 == 2), (bar*4+slot*.25)*BEAT, .035 if slot % 2 else .055, .5)
            for slot in range(8): add(bus, bass(root + (12 if slot % 4 == 3 else 0), .2, .7), (bar*4+slot*.5)*BEAT, .12)
        elif style == 8:  # Alquimista: bouncy, bubbling off-beat groove
            for beat in [0, 1.75, 2.5]: add(bus, kick(.5), (bar*4+beat)*BEAT, .27)
            add(bus, snare(True), (bar*4+3)*BEAT, .17, -.2)
            for slot in [.5, 1.5, 2.5, 3.5]: add(bus, bass(root + 7, .2), (bar*4+slot)*BEAT, .1, .15)
            for slot in [0, 2]: add(bus, bass(root, .4), (bar*4+slot)*BEAT, .12, -.15)
            for slot in [.75, 2.25, 3.25]: add(bus, hat(False), (bar*4+slot)*BEAT, .05, -.45)
        elif style == 9:  # Corsário: rolling sea-shanty stomp
            for beat in [0, 2]: add(bus, kick(1.0), (bar*4+beat)*BEAT, .36)
            for beat in [1, 3]: add(bus, snare(False), (bar*4+beat)*BEAT, .19, .15)
            for slot in [.5, 1.5, 2.5, 3.5]: add(bus, hat(True), (bar*4+slot)*BEAT, .028, -.5)
            for slot, step in [(0, 0), (1, 7), (2, 12), (3, 7)]: add(bus, bass(root + step, .4, .3), (bar*4+slot)*BEAT, .14)
        elif style == 10:  # Arconte Solar: grand march with timpani rolls
            add(bus, kick(1.3), bar*4*BEAT, .38)
            add(bus, kick(1.1), (bar*4+1.5)*BEAT, .26)
            add(bus, kick(1.1), (bar*4+2)*BEAT, .3)
            add(bus, snare(False), (bar*4+3)*BEAT, .2)
            if bar % 4 == 3:
                for slot in [3.25, 3.5, 3.75]: add(bus, snare(True), (bar*4+slot)*BEAT, .12, .3)
            for slot in [0, 2, 3]: add(bus, bass(root-12, .5, .15), (bar*4+slot)*BEAT, .17)
        else:  # Sentinela: dark cinematic half-time
            add(bus, kick(1.0), bar*4*BEAT, .36)
            add(bus, kick(.65), (bar*4+2.5)*BEAT, .22)
            add(bus, snare(False), (bar*4+2)*BEAT, .18, .2)
            for slot in [0, 1.5, 3]: add(bus, bass(root-12, .68, .24), (bar*4+slot)*BEAT, .16)
            for slot in [1, 3]: add(bus, hat(True), (bar*4+slot)*BEAT, .035, -.55)
    return bus


def theme_faroleiro():
    bus = foundation(1)
    phrase = [76, 79, 81, 84, 81, 79, 76, 72]
    for step in range(64):
        if step % 2 == 0 or step >= 48:
            add(bus, bell(phrase[step % len(phrase)]), step * BEAT, .11, -.35 if step % 4 == 0 else .35)
    # Echo only the identity motif; the rhythm section stays tight.
    motif = np.zeros((2, N))
    for step in range(0, 64, 4):
        add(motif, bell(phrase[step % len(phrase)], 1.2), step*BEAT, .065, -.45 if step%8==0 else .45)
    return bus + echo(motif, BEAT * .75, .34)


def theme_astronomo():
    bus = foundation(2)
    motif = np.zeros((2, N))
    notes = [69, 72, 76, 79, 81, 79, 76, 72]
    for step in range(128):
        add(motif, space_pluck(notes[step % 8] + (12 if step % 16 >= 12 else 0)), step * BEAT/2,
            .08, -.65 if step % 2 == 0 else .65)
    # A very slow orbital sine bed stays phase-aligned at the loop boundary.
    t = np.arange(N) / SR
    for note, pan in [(45, -.45), (52, .45), (57, 0)]:
        # Quantize the oscillator to a whole number of cycles per loop.
        frequency = round(hz(note) * DURATION) / DURATION
        wave = np.sin(2*np.pi*frequency*t) * (0.5 + 0.5*np.sin(2*np.pi*t/16 + pan))
        bus[0] += wave * .018 * (1-pan*.4)
        bus[1] += wave * .018 * (1+pan*.4)
    return bus + motif + echo(motif, BEAT * 1.5, .46)


def theme_jardineiro():
    bus = foundation(3)
    motif = np.zeros((2, N))
    phrase = [69, 72, 76, 74, 72, 67, 69, 64]
    for bar in range(32):
        for slot in [0, .75, 1.5, 2.5, 3.25]:
            note = phrase[(bar * 2 + round(slot*2)) % len(phrase)]
            add(motif, wood(note), (bar*4 + slot)*BEAT, .13, np.sin((bar+slot)*1.7)*.45)
    return bus + motif + echo(motif, BEAT, .2)


def theme_mineiro():
    bus = foundation(4)
    motif = np.zeros((2, N))
    for bar in range(32):
        add(motif, metal(57 + (bar % 4)*3), bar*4*BEAT, .16, -.4)
        add(motif, metal(69 + (bar % 3)*2, .45), (bar*4 + 2)*BEAT, .12, .4)
        if bar >= 16:
            for slot in [1, 1.5, 3, 3.5]:
                add(motif, metal(81, .22), (bar*4 + slot)*BEAT, .045, -.55 if slot % 1 else .55)
    return bus + motif + echo(motif, BEAT*.5, .17)


def theme_sentinela():
    bus = foundation(5)
    motif = np.zeros((2, N))
    roots = [45, 41, 43, 43]
    for bar in range(32):
        root = roots[(bar//2) % 4]
        add(motif, brass(root), bar*4*BEAT, .14, -.2)
        add(motif, brass(root+7), (bar*4 + 2)*BEAT, .11, .2)
        if bar >= 16:
            add(motif, brass(root+12, .5), (bar*4 + 3)*BEAT, .08, .5)
    return bus + motif + echo(motif, BEAT*1.5, .27)


def theme_relojoeiro():
    bus = foundation(6)
    motif = np.zeros((2, N))
    phrase = [81, 76, 72, 76, 79, 76, 74, 72, 76, 72, 69, 72, 74, 71, 67, 71]
    for step in range(128):
        if step % 16 in (7, 15) and step < 64:
            continue
        lift = 12 if step >= 96 and step % 4 == 0 else 0
        add(motif, music_box(phrase[step % 16] + lift), step*BEAT/2, .085, -.4 if step % 2 == 0 else .4)
    return bus + motif + echo(motif, BEAT * .5, .22)


def theme_cacatrovoes():
    bus = foundation(7)
    motif = np.zeros((2, N))
    arps = [[57, 64, 69, 72], [53, 60, 65, 69], [52, 60, 64, 67], [55, 62, 67, 71]]
    for bar in range(32):
        chord = arps[(bar//2) % 4]
        for slot in range(16):
            order = [0, 1, 2, 3, 2, 1][slot % 6] if bar < 16 else slot % 4
            add(motif, zap_lead(chord[order] + 12), (bar*4 + slot*.25)*BEAT, .07, np.sin(slot*.9)*.6)
    return bus + motif + echo(motif, BEAT * .75, .3)


def theme_alquimista():
    bus = foundation(8)
    motif = np.zeros((2, N))
    phrase = [69, 72, 71, 76, 74, 72, 67, 64]
    for bar in range(32):
        for k, slot in enumerate([0, .5, 1.25, 2, 2.75, 3.5]):
            if bar < 8 and k % 2:
                continue
            note = phrase[(bar + k*3) % 8] + (12 if (bar*6 + k) % 7 == 0 else 0)
            add(motif, glass_drop(note), (bar*4 + slot)*BEAT, .12, np.sin(bar*1.3 + k)*.55)
    return bus + motif + echo(motif, BEAT * 1.5, .36)


def theme_corsario():
    bus = foundation(9)
    motif = np.zeros((2, N))
    tune = [(69, 1), (72, .5), (76, .5), (74, 1), (72, 1), (71, .5), (72, .5), (74, 1), (76, 2),
            (77, 1), (76, .5), (74, .5), (72, 1), (71, 1), (69, 2), (64, 2)]
    length = sum(d for _, d in tune)
    for turn in range(int(128 // length)):
        at = turn * length
        for note, dur in tune:
            if turn % 2 == 0 or note >= 70:
                add(motif, squeezebox(note, dur*BEAT*.95), at*BEAT, .1, -.2)
            if turn >= 4:
                add(motif, squeezebox(note - 5, dur*BEAT*.95), at*BEAT, .05, .35)
            at += dur
    return bus + motif + echo(motif, BEAT, .18)


def theme_arconte():
    bus = foundation(10)
    motif = np.zeros((2, N))
    for bar in range(0, 32, 2):
        notes, root = CHORDS[(bar//2) % 4]
        for voice, note in enumerate(notes[1:]):
            add(motif, choir(note + 12, 3.8), bar*4*BEAT, .05, (voice/3 - .5)*.8)
    fanfare = [(69, 0), (76, 1), (81, 1.5), (79, 2), (76, 3)]
    for bar in range(32):
        if bar % 2 == 1 or bar >= 16:
            for note, slot in fanfare:
                add(motif, brass(note - (0 if bar % 4 < 2 else 2), .45), (bar*4 + slot)*BEAT, .07, .25)
    return bus + motif + echo(motif, BEAT * 1.5, .3)


def encode(mix, index):
    # Soft saturation keeps the full compositions controlled on phone speakers.
    mix = np.tanh(mix * 1.05)
    peak = np.max(np.abs(mix))
    mix *= (10 ** (-2/20)) / max(peak, 1e-8)
    # Match the original Charge Circuit at -17.1 LUFS without reusing its mix.
    trim_db = {1: -2.5, 2: -1.5, 3: -1.9, 4: -2.0, 5: -.9, 6: -1.1, 7: -1.8, 8: -2.4, 9: -3.2, 10: -2.6}[index]
    mix *= 10 ** (trim_db / 20)
    proc = subprocess.Popen([
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "f32le",
        "-ar", str(SR), "-ac", "2", "-i", "-", "-c:a", "libvorbis", "-q:a", "5",
        str(ROOT / "audio" / f"music_skin_{index}.ogg")
    ], stdin=subprocess.PIPE)
    proc.communicate(mix.T.astype("<f4").tobytes())
    if proc.returncode:
        raise SystemExit(proc.returncode)


def main():
    makers = [theme_faroleiro, theme_astronomo, theme_jardineiro, theme_mineiro, theme_sentinela,
              theme_relojoeiro, theme_cacatrovoes, theme_alquimista, theme_corsario, theme_arconte]
    # Optional theme numbers render only those: python tools/compose_skin_music.py 6 7
    only = [int(a) for a in sys.argv[1:]]
    for index, maker in enumerate(makers, 1):
        if only and index not in only:
            continue
        encode(maker(), index)
        path = ROOT / "audio" / f"music_skin_{index}.ogg"
        print(path.name, path.stat().st_size)


if __name__ == "__main__":
    main()
