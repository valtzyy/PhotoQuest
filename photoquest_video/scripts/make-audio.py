# Synthesize royalty-free background music + UI sound effects (no downloads).
# Usage: python scripts/make-audio.py   -> public/music.wav, public/sfx/*.wav
# The .wav files are converted to .mp3 with ffmpeg afterwards.
import os

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SR = 44100
rng = np.random.default_rng(7)


def t_axis(sec):
    return np.arange(int(sec * SR)) / SR


def note(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def lowpass(x, hz):
    b, a = butter(2, hz / (SR / 2))
    return lfilter(b, a, x)


def highpass(x, hz):
    b, a = butter(2, hz / (SR / 2), btype="high")
    return lfilter(b, a, x)


def reverb(x, delays=(0.031, 0.047, 0.071, 0.113, 0.167), decay=0.45):
    out = x.copy()
    for i, d in enumerate(delays):
        n = int(d * SR)
        g = decay ** (i + 1)
        out[n:] += x[:-n] * g
    return out


def save(path, x, peak=0.9):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    wavfile.write(path, SR, (x * 32767).astype(np.int16))


# ---------- Music: warm "tech launch" pad + soft arpeggio + light beat ----------
BPM = 100
beat = 60 / BPM
bar = 4 * beat
# Cmaj7 - Am7 - Fmaj7 - G6 (uplifting, calm)
chords = [
    [48, 55, 59, 64],
    [45, 52, 55, 60],
    [41, 48, 52, 57],
    [43, 50, 55, 59],
]
total_bars = 48  # ~115 s, longer than the video
length = total_bars * bar
T = t_axis(length)
music = np.zeros_like(T)

for b in range(total_bars):
    chord = chords[b % 4]
    start = int(b * bar * SR)
    seg_t = t_axis(bar + 1.0)  # 1 s overlap tail
    env = np.minimum(1, seg_t / 0.6) * np.exp(-np.maximum(0, seg_t - bar) * 4)
    pad = np.zeros_like(seg_t)
    for m in chord:
        f = note(m)
        for detune in (-0.12, 0.0, 0.12):
            ff = f * 2 ** (detune / 12)
            pad += np.sin(2 * np.pi * ff * seg_t + rng.uniform(0, 6.28))
    pad = pad * env * 0.05
    # bass
    bass = np.sin(2 * np.pi * note(chord[0] - 12) * seg_t) * env * 0.18
    end = min(len(music), start + len(seg_t))
    music[start:end] += (pad + bass)[: end - start]

    # arpeggio (8th notes) from bar 2 on
    if b >= 2:
        arp = chord[1:] + [chord[0] + 12, chord[2] + 12]
        for i in range(8):
            m = arp[i % len(arp)] + 12
            ns = int((b * bar + i * beat / 2) * SR)
            nt = t_axis(0.5)
            tone = np.sin(2 * np.pi * note(m) * nt) + 0.3 * np.sin(4 * np.pi * note(m) * nt)
            tone *= np.exp(-nt * 7) * 0.08
            e = min(len(music), ns + len(nt))
            music[ns:e] += tone[: e - ns]

    # soft kick + hat from bar 4 on
    if b >= 4:
        for i in range(4):
            ks = int((b * bar + i * beat) * SR)
            kt = t_axis(0.25)
            kick = np.sin(2 * np.pi * (50 + 80 * np.exp(-kt * 30)) * kt) * np.exp(-kt * 14) * 0.35
            e = min(len(music), ks + len(kt))
            music[ks:e] += kick[: e - ks]
            hs = int((b * bar + i * beat + beat / 2) * SR)
            ht = t_axis(0.06)
            hat = highpass(rng.normal(0, 1, len(ht)), 7000) * np.exp(-ht * 60) * 0.05
            e = min(len(music), hs + len(ht))
            music[hs:e] += hat[: e - hs]

music = lowpass(music, 9000)
music = reverb(music)
fade = int(3 * SR)
music[-fade:] *= np.linspace(1, 0, fade)
music[: int(1.5 * SR)] *= np.linspace(0, 1, int(1.5 * SR))
os.makedirs("public/sfx", exist_ok=True)
save("public/music.wav", music, peak=0.8)

# ---------- SFX ----------
# tap: short soft click
tt = t_axis(0.09)
tap = np.sin(2 * np.pi * 1800 * tt * np.exp(-tt * 20)) * np.exp(-tt * 70)
tap += highpass(rng.normal(0, 1, len(tt)), 3000) * np.exp(-tt * 200) * 0.3
save("public/sfx/tap.wav", tap, peak=0.7)

# whoosh: filtered noise sweep
wt = t_axis(0.6)
noise = rng.normal(0, 1, len(wt))
env = np.sin(np.pi * np.clip(wt / 0.6, 0, 1)) ** 2
sweep = np.zeros_like(noise)
chunks = 30
for i in range(chunks):
    a, b = i * len(wt) // chunks, (i + 1) * len(wt) // chunks
    hz = 400 + 5000 * (i / chunks) ** 1.5
    sweep[a:b] = lowpass(noise, hz)[a:b]
save("public/sfx/whoosh.wav", sweep * env, peak=0.6)

# pop: for icons / words appearing
pt = t_axis(0.15)
pop = np.sin(2 * np.pi * (500 + 900 * np.exp(-pt * 40)) * pt) * np.exp(-pt * 30)
save("public/sfx/pop.wav", pop, peak=0.6)

# shimmer: logo reveal
st = t_axis(1.6)
shimmer = np.zeros_like(st)
for m in [72, 76, 79, 83, 84, 88]:
    shimmer += np.sin(2 * np.pi * note(m) * st) * np.exp(-st * 2.2)
shimmer = reverb(shimmer * np.minimum(1, st / 0.02))
save("public/sfx/shimmer.wav", shimmer, peak=0.6)
