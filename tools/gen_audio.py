"""Generate all game audio procedurally (pure stdlib) into godot/audio/."""

import math
import os
import random
import struct
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "godot", "audio")
os.makedirs(OUT, exist_ok=True)
random.seed(7)


def silence(dur):
    return [0.0] * int(SR * dur)


def add(buf, samples, at=0.0, gain=1.0):
    start = int(at * SR)
    for i, s in enumerate(samples):
        j = start + i
        if 0 <= j < len(buf):
            buf[j] += s * gain
    return buf


def osc(kind, phase):
    if kind == "sine":
        return math.sin(phase)
    if kind == "square":
        return 1.0 if math.sin(phase) >= 0 else -1.0
    if kind == "saw":
        return 2.0 * ((phase / (2 * math.pi)) % 1.0) - 1.0
    if kind == "tri":
        p = (phase / (2 * math.pi)) % 1.0
        return 4.0 * abs(p - 0.5) - 1.0
    return 0.0


def tone(f0, f1, dur, kind="sine", vol=0.5, attack=0.006, decay=1.0, vib=0.0, vibf=6.0):
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        f = f0 * (f1 / f0) ** t if f0 > 0 and f1 > 0 else f0
        if vib:
            f *= 1.0 + vib * math.sin(2 * math.pi * vibf * i / SR)
        phase += 2 * math.pi * f / SR
        a = min(1.0, i / max(1.0, attack * SR))
        d = (1.0 - t) ** decay
        out.append(osc(kind, phase) * vol * a * d)
    return out


def noise(dur, vol=0.4, decay=1.0, lowpass=0.0, sweep=0.0, attack=0.004):
    n = int(SR * dur)
    out = []
    lp = 0.0
    coef = lowpass
    for i in range(n):
        t = i / n
        c = coef * (1.0 + sweep * t)
        c = min(0.995, max(0.0, c))
        r = random.uniform(-1, 1)
        lp += (r - lp) * (1.0 - c)
        a = min(1.0, i / max(1.0, attack * SR))
        out.append(lp * vol * a * (1.0 - t) ** decay)
    return out


def mix(*layers):
    n = max(len(x) for x in layers)
    out = [0.0] * n
    for layer in layers:
        for i, s in enumerate(layer):
            out[i] += s
    return out


def fit(buf, dur):
    n = int(SR * dur)
    if len(buf) < n:
        buf = buf + [0.0] * (n - len(buf))
    else:
        buf = buf[:n]
    # click-free tail
    fade = min(400, n // 6)
    for i in range(fade):
        buf[n - 1 - i] *= i / fade
    return buf


def write(name, buf, gain=0.9):
    n = len(buf)
    peak = max(1e-6, max(abs(x) for x in buf))
    scale = min(gain / peak, 1.0)
    data = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x * scale)) * 32767)) for x in buf)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print("%-16s %5.0f ms" % (name, 1000.0 * n / SR))


# --- UI -------------------------------------------------------------------
write("click", fit(tone(880, 1180, 0.07, "sine", 0.4, decay=2.4), 0.09), 0.6)
write("select", fit(mix(tone(520, 780, 0.1, "tri", 0.3, decay=2.0),
                        tone(1040, 1560, 0.07, "sine", 0.16, decay=3.0)), 0.12), 0.55)
write("deny", fit(mix(tone(150, 110, 0.16, "square", 0.22, decay=1.4),
                      noise(0.1, 0.1, 2.0, 0.85)), 0.17), 0.55)

# --- planting -------------------------------------------------------------
write("plant", fit(mix(noise(0.26, 0.5, 2.2, 0.9, 0.25),
                       tone(120, 62, 0.22, "sine", 0.55, decay=1.8),
                       ), 0.3), 0.85)
write("dig", fit(mix(noise(0.2, 0.45, 2.4, 0.75),
                     tone(180, 90, 0.16, "tri", 0.3, decay=2.0)), 0.22), 0.7)

# --- combat ---------------------------------------------------------------
write("shoot", fit(mix(tone(560, 300, 0.1, "sine", 0.42, decay=2.6),
                       noise(0.05, 0.12, 3.0, 0.6)), 0.11), 0.5)
write("hit", fit(mix(tone(320, 180, 0.07, "square", 0.2, decay=3.0),
                     noise(0.07, 0.3, 3.2, 0.55)), 0.08), 0.55)
write("chomp", fit(mix(noise(0.24, 0.5, 2.0, 0.42, 0.3),
                       tone(95, 60, 0.2, "saw", 0.3, decay=1.6)), 0.26), 0.8)
write("explode", fit(mix(noise(0.9, 0.85, 1.5, 0.28, -0.1),
                         tone(90, 32, 0.8, "sine", 0.85, decay=1.4),
                         noise(0.2, 0.3, 3.0, 0.05)), 0.95), 0.95)
write("shove", fit(noise(0.24, 0.55, 1.6, 0.75, -0.55), 0.26), 0.7)
write("freeze", fit(mix(tone(1400, 900, 0.18, "sine", 0.18, decay=2.0),
                        noise(0.16, 0.16, 2.2, 0.05)), 0.2), 0.5)

# --- sun ------------------------------------------------------------------
write("sun", fit(mix(tone(700, 900, 0.07, "tri", 0.22, decay=2.0),
                     add(silence(0.05), tone(1200, 1500, 0.12, "sine", 0.18, decay=2.2))), 0.2), 0.5)

# --- zombies --------------------------------------------------------------
def groan(seed):
    random.seed(seed)
    dur = 0.62
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        f = 92 + 26 * math.sin(2 * math.pi * 4.2 * t) + 40 * t
        phase += 2 * math.pi * f / SR
        body = osc("saw", phase) * 0.5 + math.sin(phase * 2) * 0.18
        rough = random.uniform(-1, 1) * 0.06
        a = min(1.0, i / (0.04 * SR)) * min(1.0, (1 - t) * 3.0)
        out.append((body + rough) * a * 0.55)
    return out


write("groan1", fit(groan(3), 0.66), 0.75)
write("groan2", fit(groan(11), 0.7), 0.75)
write("groan3", fit(groan(23), 0.6), 0.75)

write("wave", fit(mix(tone(110, 110, 0.9, "saw", 0.22, attack=0.1, decay=0.7),
                      tone(165, 165, 0.9, "saw", 0.14, attack=0.12, decay=0.7),
                      tone(220, 220, 0.9, "tri", 0.1, attack=0.14, decay=0.8)), 0.95), 0.7)

write("mower", fit(mix(tone(70, 130, 0.8, "saw", 0.3, attack=0.02, decay=0.9, vib=0.08, vibf=28),
                       noise(0.8, 0.3, 1.2, 0.55, 0.2)), 0.85), 0.8)

# --- movement -------------------------------------------------------------
write("step_grass", fit(noise(0.09, 0.35, 3.4, 0.7), 0.1), 0.4)
write("step_wood", fit(mix(noise(0.07, 0.25, 3.6, 0.55),
                           tone(240, 150, 0.06, "sine", 0.25, decay=3.0)), 0.08), 0.45)
write("step_water", fit(mix(noise(0.18, 0.4, 2.2, 0.35, 0.3),
                            tone(320, 620, 0.12, "sine", 0.1, decay=2.2)), 0.2), 0.55)

# --- jingles --------------------------------------------------------------
def arp(notes, step, dur, kind="tri", vol=0.3):
    out = silence(step * len(notes) + dur)
    for i, f in enumerate(notes):
        add(out, tone(f, f, dur, kind, vol, decay=1.8), i * step)
    return out


write("win", fit(arp([523.25, 659.25, 783.99, 1046.5], 0.13, 0.55, "tri", 0.28), 0.95), 0.75)
write("lose", fit(arp([392.0, 349.23, 293.66, 220.0], 0.2, 0.7, "sine", 0.3), 1.3), 0.75)

# --- doors ----------------------------------------------------------------
write("door_open", fit(mix(tone(185, 245, 0.42, "saw", 0.11, attack=0.06, decay=0.7, vib=0.03, vibf=8),
                           noise(0.42, 0.16, 1.1, 0.55, 0.12),
                           add(silence(0.36), tone(940, 640, 0.07, "sine", 0.16, decay=3.0))), 0.47), 0.62)
write("door_close", fit(mix(tone(118, 68, 0.2, "sine", 0.5, decay=2.2),
                            noise(0.12, 0.3, 3.2, 0.45),
                            add(silence(0.01), tone(780, 520, 0.08, "square", 0.11, decay=3.2))), 0.3), 0.8)

# --- chimney --------------------------------------------------------------
# a slow brick-scrape loop: four scrapes rising in pitch, ending in a puff
_buf = silence(2.9)
for i in range(5):
    at = 0.18 + i * 0.52
    _buf = add(_buf, noise(0.22, 0.3, 2.2, 0.55, 0.1), at, 0.75)
    _buf = add(_buf, tone(210 + i * 26, 150 + i * 20, 0.2, "saw", 0.10, attack=0.02, decay=1.6), at, 0.6)
_buf = add(_buf, noise(0.35, 0.22, 2.6, 0.7), 2.45, 0.6)
write("chimney", fit(_buf, 2.85), 0.62)

# --- ambience -------------------------------------------------------------
# soft wind loop, 8 s, seamless-ish
random.seed(99)
n = int(SR * 8.0)
buf = []
lp = 0.0
lp2 = 0.0
for i in range(n):
    t = i / SR
    r = random.uniform(-1, 1)
    lp += (r - lp) * 0.012
    lp2 += (lp - lp2) * 0.02
    lfo = 0.55 + 0.45 * math.sin(2 * math.pi * t / 8.0)
    buf.append(lp2 * 2.2 * lfo)
    if i < 2000:
        pass
# crossfade the seam
fade = int(SR * 0.4)
for i in range(fade):
    k = i / fade
    buf[i] = buf[i] * k + buf[n - fade + i] * (1 - k)
write("wind", buf, 0.35)

print("done ->", OUT)
