"""Original melodic score: eight-bar themes, answer phrases, bridge and reprise.
No samples. Leaves music_menu and music_match untouched. Deterministic synthesis.
Run with numpy and ffmpeg installed.
"""
from pathlib import Path
import subprocess
import numpy as np
import wave

ROOT = Path(__file__).resolve().parents[1]
SR = 32000
RNG = np.random.default_rng(220922)

def hz(n):
    return 440 * 2 ** ((n - 69) / 12)

def note(n, duration, voice=0):
    t = np.arange(int((duration + .18) * SR)) / SR
    phase = 2 * np.pi * hz(n) * t + .012 * np.sin(2*np.pi*4.8*t)
    # Predominantly fundamental: a singable lead rather than an arpeggio texture.
    sound = np.sin(phase) + .20 * np.sin(phase*2) + .07*np.sin(phase*3)
    if voice in (1, 6, 8):  # beacon bells, clockwork music box, glass
        sound = np.sin(phase + (.45 if voice == 1 else .8)*np.sin(phase*2)*np.exp(-t*3)) + .12*np.sin(phase*3)
    elif voice == 2:  # breathy orbital flute
        sound = np.sin(phase) + .07*np.sin(phase*3)
    elif voice == 3:  # rounded marimba
        sound = (np.sin(phase) + .22*np.sin(phase*4))*np.exp(-t*1.2)
    elif voice in (4, 5):  # low reed and organ
        sound = np.sin(phase) + .22*np.sin(phase*.5) + .28*np.sin(phase*3)/3
    elif voice in (7, 9, 10):  # storm lead, bowed strings, solar brass
        sound = sum(np.sin(phase*k)*(.6**(k-1))/k for k in range(1,6))
    envelope = np.minimum(t/.025, 1) * np.minimum(np.maximum(duration+.18-t, 0)/.18, 1)
    return sound * envelope * np.exp(-t * (.3 if voice % 3 else 1.1))

def compose(index, target):
    bpm = [108, 112, 96, 104, 110, 92, 116, 118, 106, 114, 104][index]
    beat = 60/bpm
    length = 32*4*beat
    bus = np.zeros((int(length*SR), 2), dtype=np.float64)
    def put(sound, when, gain, pan=0):
        start = int(when*SR)
        indices = (np.arange(len(sound)) + start) % len(bus)
        bus[indices, 0] += sound*gain*np.sqrt((1-pan)/2)
        bus[indices, 1] += sound*gain*np.sqrt((1+pan)/2)
    # Dorian palette shared with the menu; skins get distinct tone centres and phrasing.
    transpose = [0, 0, -2, 3, -5, -2, 2, 0, 5, -3, 0][index]
    chords = [[50,57,60,65], [55,59,62,69], [57,60,64,67], [53,57,60,67]]
    phrases = [
        [(0,74,1), (1,77,.5), (1.5,79,.5), (2,81,1.5)],
        [(0,79,1), (1,77,1), (2.5,74,1)],
        [(0,76,.75), (1,77,.75), (2,79,1.5)],
        [(0,81,1.5), (2,79,.75), (3,77,.75)],
        [(0,74,1), (1.5,77,.5), (2,81,1.5)],
        [(0,83,1), (1,81,1), (2.5,79,1)],
        [(0,77,1), (1.5,76,.5), (2,74,1)],
        [(0,72,1), (1,76,1), (2,74,1.75)],
    ]
    for bar in range(32):
        chord = chords[(bar//2) % 4]
        pos = bar*4*beat
        bridge = 16 <= bar < 24
        for k, n in enumerate(chord):
            put(note(n+transpose, 4*beat, 2), pos, .045, (k-1.5)*.32)
        for tick in range(4):
            put(note(chord[0]-12+transpose, beat*.68, 1), pos+tick*beat, .13)
        # Short rhythm leaves negative space under the long melody.
        for tick in ([0, 2] if bridge else [0, 1.5, 2, 3.5]):
            t = np.arange(int(.24*SR))/SR
            kick = np.sin(2*np.pi*(48*t+65*.025*(1-np.exp(-t/.025))))*np.exp(-t*22)
            put(kick, pos+tick*beat, .23)
        for tick in [1,3]:
            t = np.arange(int(.16*SR))/SR
            noise = RNG.normal(0,1,len(t))
            snare = (noise - .85*np.roll(noise, 1))*np.exp(-t*35)*np.minimum(t/.003,1)
            put(snare, pos+tick*beat, .025 if bridge else .05, -.15)
        for tick in range(8):
            t = np.arange(int(.055*SR))/SR
            hat = RNG.normal(0,1,len(t))*np.exp(-t*90)
            put(hat, pos+tick*.5*beat, .012, .4 if tick%2 else -.4)
        for at, n, hold in phrases[(bar + (index % 3)*2) % 8]:
            pitch = n + transpose - (12 if bridge else 0)
            melody = note(pitch, hold*beat, index)
            put(melody, pos+at*beat, .18 if not bridge else .10, -.08)
            put(melody, pos+(at+.75)*beat, .035, .5)
            put(melody, pos+(at+1.5)*beat, .018, -.5)
        # Bell countervoice only in the reprise, never competing for every beat.
        if bar >= 24:
            put(note(chord[2]+24+transpose, beat*.6, 0), pos+3*beat, .045, .55)
    # Tiny cyclic ambience makes the seam continuous without cutting a release.
    bus += np.roll(bus, int(.19*SR), axis=0)*.07
    peak = np.max(np.abs(bus))
    bus *= .82/max(peak, 1e-9)
    wav = target.with_suffix('.wav')
    with wave.open(str(wav), "wb") as out:
        out.setnchannels(2)
        out.setsampwidth(2)
        out.setframerate(SR)
        out.writeframes((bus*32767).astype("<i2").tobytes())
    subprocess.run(['ffmpeg','-y','-loglevel','error','-i',str(wav),'-af','loudnorm=I=-18:TP=-1.5:LRA=9','-ar',str(SR),'-t',str(length),'-c:a','libvorbis','-q:a','5',str(target)],check=True)
    wav.unlink()
    print(target.name, round(length,2), 'seconds', flush=True)

if __name__ == '__main__':
    compose(0, ROOT/'audio/music_cup.ogg')
    # Boss originals are intentionally preserved; never overwrite music_skin_*.ogg here.
