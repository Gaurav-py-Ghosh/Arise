#!/usr/bin/env python3
"""Synthesises the Arise sound effects as small mono WAV files.

Pure standard library. Run from the repo root: python3 tool/make_sounds.py
"""
import math, os, random, struct, wave

RATE = 22050
OUT = "android/app/src/main/res/raw"
random.seed(7)


def env(i, n, a=0.004, r=0.08):
    t = i / RATE
    d = n / RATE
    att = min(1.0, t / a) if a > 0 else 1.0
    rel = min(1.0, max(0.0, (d - t) / r)) if r > 0 else 1.0
    return att * rel


def tone(freq, dur, vol=0.5, shape="sine", a=0.004, r=0.08, sweep=None, vib=0.0):
    n = int(RATE * dur)
    out = []
    phase = 0.0
    for i in range(n):
        f = freq if sweep is None else freq + (sweep - freq) * (i / n)
        if vib:
            f *= 1 + vib * math.sin(2 * math.pi * 6 * i / RATE)
        phase += 2 * math.pi * f / RATE
        if shape == "sine":
            s = math.sin(phase)
        elif shape == "square":
            s = 1.0 if math.sin(phase) >= 0 else -1.0
            s *= 0.6
        elif shape == "tri":
            s = 2 / math.pi * math.asin(math.sin(phase))
        elif shape == "soft":  # sine with a quiet octave: bell-ish
            s = math.sin(phase) + 0.35 * math.sin(2 * phase) + 0.12 * math.sin(3 * phase)
            s /= 1.5
        else:
            s = 0.0
        out.append(s * vol * env(i, n, a, r))
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out


def seq(parts):
    """parts: list of (offset_seconds, samples)."""
    n = max(int(RATE * o) + len(s) for o, s in parts)
    out = [0.0] * n
    for o, s in parts:
        base = int(RATE * o)
        for i, v in enumerate(s):
            out[base + i] += v
    return out


def echo(x, delay=0.11, gain=0.32, taps=3):
    out = list(x) + [0.0] * int(RATE * delay * taps)
    for k in range(1, taps + 1):
        d = int(RATE * delay * k)
        g = gain ** k
        for i, v in enumerate(x):
            out[i + d] += v * g
    return out


def noise_burst(dur, vol=0.3, r=0.03):
    n = int(RATE * dur)
    return [(random.random() * 2 - 1) * vol * env(i, n, 0.001, r) for i in range(n)]


def lowpass(x, k=0.25):
    y, p = [], 0.0
    for v in x:
        p += k * (v - p)
        y.append(p)
    return y


def save(name, samples, peak=0.62):
    m = max(abs(v) for v in samples) or 1.0
    g = peak / m if m > peak else 1.0
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v * g)) * 32767)) for v in samples))
    print(f"{name:10s} {len(samples) / RATE:4.2f}s {os.path.getsize(path) // 1024} KB")


os.makedirs(OUT, exist_ok=True)

# UI tick: a dry, quiet blip.
save("tick", tone(1900, 0.035, 0.5, "tri", 0.001, 0.03))

# Window opens: a short rising sweep with a bright top.
save("open", mix(tone(380, 0.16, 0.35, "tri", 0.005, 0.1, sweep=900),
                 tone(1400, 0.1, 0.12, "sine", 0.02, 0.08)))

# Focus timer start: a firm two-step rise.
save("start", seq([(0.0, tone(520, 0.09, 0.5, "square", 0.002, 0.05)),
                   (0.09, tone(780, 0.16, 0.5, "square", 0.002, 0.1))]))

# Quest complete: a bright major third with a small tail.
save("complete", echo(seq([(0.0, tone(880, 0.11, 0.5, "soft", 0.002, 0.08)),
                           (0.09, tone(1109, 0.11, 0.5, "soft", 0.002, 0.08)),
                           (0.18, tone(1319, 0.28, 0.5, "soft", 0.002, 0.2))]), 0.09, 0.3, 2))

# Daily clear: a rising arpeggio ending on a held chord.
notes = [523, 659, 784, 1047]
parts = [(i * 0.085, tone(f, 0.16, 0.42, "soft", 0.002, 0.1)) for i, f in enumerate(notes)]
chord = mix(*[tone(f, 0.55, 0.26, "soft", 0.005, 0.4) for f in (523, 659, 784, 1047)])
parts.append((0.36, chord))
save("clear", echo(seq(parts), 0.13, 0.32, 3))

# Level up: sweep, then a fanfare with shimmer.
sweep = tone(300, 0.32, 0.36, "tri", 0.01, 0.12, sweep=1500)
fan = [(0.0, sweep)]
for i, f in enumerate([659, 784, 988, 1319]):
    fan.append((0.28 + i * 0.1, tone(f, 0.2, 0.42, "soft", 0.002, 0.12)))
fan.append((0.7, mix(*[tone(f, 0.85, 0.24, "soft", 0.01, 0.6, vib=0.004) for f in (659, 988, 1319, 1976)])))
save("levelup", echo(seq(fan), 0.15, 0.34, 3))

# Warning: two low pulses, a little dissonant.
pulse = lambda: mix(tone(196, 0.16, 0.5, "square", 0.002, 0.1), tone(207, 0.16, 0.4, "square", 0.002, 0.1))
save("warn", lowpass(seq([(0.0, pulse()), (0.22, pulse())]), 0.35))

# Alert (notification): a falling siren-ish figure, loud and short.
alert = seq([(0.0, tone(988, 0.14, 0.5, "square", 0.002, 0.04)),
             (0.16, tone(740, 0.14, 0.5, "square", 0.002, 0.04)),
             (0.32, tone(988, 0.14, 0.5, "square", 0.002, 0.04)),
             (0.48, tone(740, 0.3, 0.5, "square", 0.002, 0.2))])
save("alert", lowpass(alert, 0.45))

# Boot: filtered noise swell into a rising chirp pair.
swell = lowpass(noise_burst(0.35, 0.5, 0.2), 0.08)
save("boot", seq([(0.0, swell), (0.2, tone(440, 0.12, 0.4, "tri", 0.003, 0.08)),
                  (0.32, tone(880, 0.3, 0.45, "soft", 0.003, 0.25))]))
