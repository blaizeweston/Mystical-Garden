"""Render the original Mystical Garden soundtrack and ambience loops.

Run from any directory with Python and NumPy. The generated WAVs carry forward
loop points in their sampler chunks so the Godot importer preserves the seams.
"""

import argparse
from pathlib import Path
import struct
import wave

import numpy as np


RATE = 24_000
AUDIO = Path(__file__).resolve().parents[2] / "audio" / "soundscape"
RNG = np.random.default_rng(13749)
TAU = np.pi * 2.0


def timeline(seconds):
    return np.arange(round(seconds * RATE), dtype=np.float32) / RATE


def periodic_noise(seconds, low, high):
    count = round(seconds * RATE)
    freq = np.fft.rfftfreq(count, 1.0 / RATE)
    shaping = (1.0 - np.exp(-(freq / low) ** 4)) * np.exp(-(freq / high) ** 4)
    spectrum = np.fft.rfft(RNG.standard_normal(count)) * shaping
    noise = np.fft.irfft(spectrum, count)
    return (noise / max(noise.std(), 0.001)).astype(np.float32)


def stereo(mono, position):
    angle = (position + 1.0) * np.pi / 4.0
    return np.column_stack((mono * np.cos(angle), mono * np.sin(angle)))


def add(track, sample, start, position=0.0):
    offset = round(start * RATE) % len(track)
    first = min(len(sample), len(track) - offset)
    track[offset:offset + first] += stereo(sample[:first], position)
    if first < len(sample):
        track[:len(sample) - first] += stereo(sample[first:], position)


def air(seconds, low, high, amount, width=0.35):
    t = timeline(seconds)
    wind = periodic_noise(seconds, low, high)
    movement = .74 + .17 * np.cos(TAU * 3 * t / seconds) + .09 * np.sin(TAU * 5 * t / seconds)
    space = periodic_noise(seconds, low, high)
    return np.column_stack((wind + space * width, wind - space * width)) * (amount * movement[:, None])


def envelope(t, length, attack, release):
    front = np.clip(t / attack, 0, 1)
    tail = np.clip((length - t) / release, 0, 1)
    return np.sin(front * np.pi / 2) ** 2 * np.sin(tail * np.pi / 2) ** 2


def frequency(midi):
    return 440.0 * 2.0 ** ((midi - 69.0) / 12.0)


def pluck(midi, seconds):
    t = timeline(seconds)
    phase = TAU * frequency(midi) * t
    body = (
        np.sin(phase) * np.exp(-t * 1.65)
        + .34 * np.sin(phase * 2.004) * np.exp(-t * 3.2)
        + .17 * np.sin(phase * 3.008) * np.exp(-t * 4.5)
        + .08 * np.sin(phase * 4.05) * np.exp(-t * 7.8)
    )
    nail = periodic_noise(seconds, 620, 3100) * .043 * np.exp(-t * 54)
    return (body + nail) * envelope(t, seconds, .016, .36)


def bow(midi, seconds, rough=0.0):
    t = timeline(seconds)
    phase = TAU * frequency(midi) * t + .10 * np.sin(TAU * 3.0 * t)
    body = np.sin(phase) + .26 * np.sin(phase * 2.003 + .35) + .11 * np.sin(phase * 3.013)
    body += rough * .31 * np.sin(phase * 2.063 + .4 * np.sin(TAU * .8 * t))
    texture = periodic_noise(seconds, 95, 1480) * (.023 + rough * .053)
    swell = .87 + .13 * np.sin(TAU * .54 * t + .4)
    return (body + texture) * swell * envelope(t, seconds, .85, 1.5)


def flute(midi, seconds):
    t = timeline(seconds)
    phase = TAU * frequency(midi) * t + .16 * np.sin(TAU * 4.0 * t)
    breath = periodic_noise(seconds, 870, 2800)
    return (.78 * np.sin(phase) + .12 * np.sin(2 * phase) + .085 * breath) * envelope(t, seconds, .21, .42)


def thud(seconds, pitch):
    t = timeline(seconds)
    phase = TAU * (pitch * t + 19 * .12 * (1.0 - np.exp(-t / .12)))
    sound = np.sin(phase) * np.exp(-t * 3.6)
    skin = .11 * periodic_noise(seconds, 210, 1200) * np.exp(-t * 13)
    return (sound + skin) * envelope(t, seconds, .014, .35)


def room(track, reflections):
    direct = track.copy()
    for seconds, gain in reflections:
        track += gain * np.roll(direct[:, ::-1], round(seconds * RATE), axis=0)


def title_score():
    beat = 1.04
    chords = [
        (50, 57, 62, 66, 69), (47, 54, 62, 66, 71), (43, 55, 59, 62, 67), (45, 57, 61, 64, 69),
        (50, 57, 62, 66, 69), (47, 54, 59, 62, 66), (43, 55, 62, 67, 71), (45, 57, 62, 64, 67),
        (42, 54, 61, 66, 69), (43, 55, 59, 62, 67), (47, 54, 62, 64, 66), (45, 57, 61, 64, 69),
    ]
    melody = {
        0: [(1.0, 66, 1.7), (2.9, 69, 1.0)], 1: [(0, 71, 2.3), (2.7, 69, 1.2)],
        3: [(1.1, 64, 2.6)], 4: [(0.5, 66, 1.7), (2.4, 69, 1.25)], 5: [(0, 74, 2.15), (2.4, 71, 1.25)],
        6: [(0.4, 67, 2.1)], 8: [(1.2, 73, 2.1)], 9: [(0, 71, 2.5), (2.8, 67, 1.1)], 10: [(1.1, 66, 2.1)],
    }
    track = np.zeros((round(len(chords) * 4 * beat * RATE), 2), dtype=np.float32)
    for bar, chord in enumerate(chords):
        start = 4 * bar * beat
        add(track, bow(chord[0], 5.15) * .045, start - .42, -.24)
        add(track, bow(chord[2], 4.9) * .021, start - .09, .37)
        for when, index in ((.18, 1), (1.42, 2), (2.13, 3), (3.06, 4)):
            add(track, pluck(chord[index], 2.9) * (.064 if index < 4 else .045), start + when * beat, -.30 + index * .12)
        for when, note, length in melody.get(bar, []):
            add(track, flute(note, length * beat) * .043, start + when * beat, .31)
    room(track, [(.088, .19), (.214, .15), (.412, .094), (.682, .06), (.942, .031)])
    return track


def garden_score():
    beat = .93
    chords = [
        (50, 57, 64, 66, 69), (47, 54, 62, 66, 69), (43, 55, 62, 66, 71), (45, 57, 64, 67, 71),
        (50, 57, 64, 66, 69), (47, 54, 62, 64, 66), (43, 55, 62, 67, 71), (45, 57, 61, 64, 69),
        (42, 54, 61, 64, 69), (43, 55, 62, 66, 71), (47, 57, 62, 66, 69), (45, 57, 64, 66, 71),
        (43, 55, 59, 62, 66), (45, 57, 62, 64, 67), (50, 57, 64, 66, 69), (45, 57, 61, 64, 66),
    ]
    phrases = {
        0: [(1.5, 69, 1.4), (3.2, 71, .6)], 1: [(0, 74, 1.5), (2.3, 69, 1.5)],
        4: [(0.8, 66, 1.1), (2.4, 69, 1.1)], 5: [(0, 71, 1.15), (1.7, 69, 1.65)],
        8: [(0.6, 73, 1.1), (2.1, 74, 1.3)], 9: [(0, 71, 2.4)], 10: [(1.8, 69, 1.15)],
        12: [(1.1, 67, 1.4), (3, 66, .8)], 13: [(0, 64, 1.9), (2.3, 67, 1.1)],
        14: [(0.3, 66, 1.6), (2.5, 69, 1.05)], 15: [(0, 64, 2.3)],
    }
    track = np.zeros((round(64 * beat * RATE), 2), dtype=np.float32)
    for bar, chord in enumerate(chords):
        start = 4 * bar * beat
        add(track, bow(chord[0], 4.8) * .045, start - .26, -.08)
        add(track, bow(chord[1], 4.5) * .027, start + .13, .28)
        plucks = [(0, 1), (.75, 2), (1.8, 3), (2.6, 2), (3.35, 4)] if bar % 2 == 0 else [(0, 1), (1.25, 3), (2.2, 2), (3.4, 4)]
        for note, index in plucks:
            level = .095 if index < 4 else .064
            add(track, pluck(chord[index], 2.6) * level, start + note * beat, -.28 + index * .09)
        for when, note, length in phrases.get(bar, []):
            add(track, flute(note, length * beat) * .062, start + when * beat, .33)
    room(track, [(0.071, .16), (.157, .11), (.311, .09), (.571, .06), (.873, .032)])
    return track


def wilds_score():
    chords = [
        (38, 45, 51), (38, 46, 53), (39, 46, 50), (36, 43, 50),
        (38, 45, 53), (38, 44, 51), (34, 46, 53), (36, 43, 49),
        (38, 45, 51), (41, 48, 54), (39, 46, 50), (36, 43, 51),
        (38, 45, 53), (34, 41, 52), (36, 43, 51), (38, 44, 51),
    ]
    track = np.zeros((64 * RATE, 2), dtype=np.float32)
    tension = np.zeros_like(track)
    motif = {0: [62, 63, 69], 4: [62, 65, 68], 8: [62, 63, 58], 12: [62, 65, 63]}
    for bar, (root, fifth, color) in enumerate(chords):
        start = bar * 4.0
        add(track, bow(root, 5.7, .3) * .108, start - .6, -.16)
        add(track, bow(fifth, 5.0, .58) * .044, start + .2, .32)
        add(track, bow(color, 4.9, .72) * .034, start + 1.2, -.55)
        if bar % 2 == 0:
            add(track, thud(1.6, 46) * .105, start + .18, -.08)
        for offset, note in zip((.7, 2.15, 4.3), motif.get(bar, [])):
            add(track, pluck(note, 3.35) * .062, start + offset, .42 if offset < 3 else -.47)
        add(tension, bow(color + 12, 5.9, 1.0) * .06, start + .4, -.36)
        add(tension, bow(root + 13, 4.6, .9) * .065, start - .4, .35)
        for offset in (0.0, 2.0) if bar % 2 == 0 else (1.0, 2.5):
            add(tension, thud(1.55, 53) * .085, start + offset, 0)
    reflections = [(0.109, .17), (.24, .13), (.433, .08), (.742, .055), (1.124, .035)]
    room(track, reflections)
    room(tension, reflections)
    return track, tension


def bird(seconds, center, rise):
    t = timeline(seconds)
    pitch = center + rise * np.sin(np.pi * t / seconds) + 92 * np.sin(TAU * 8 * t)
    phase = TAU * np.cumsum(pitch) / RATE
    return (np.sin(phase) + .21 * np.sin(2 * phase)) * envelope(t, seconds, .038, .075)


def breeze(seconds, low, high, amount):
    return air(seconds, low, high, amount, width=.21)


def rustle(seconds, low, high, pace):
    t = timeline(seconds)
    leaves = periodic_noise(seconds, low, high)
    motion = .54 + .29 * np.sin(TAU * pace * t) + .17 * np.sin(TAU * pace * 1.59 * t + .6)
    return leaves * motion * envelope(t, seconds, seconds * .31, seconds * .52)


def garden_air():
    seconds = 47
    track = breeze(seconds, 65, 280, .005)
    for start, length, side in [(1.9, 2.7, -.54), (9.3, 3.8, .57), (17.4, 2.2, -.23),
                                (24.9, 4.1, .42), (35.6, 2.9, -.65), (43.8, 3.7, .35)]:
        add(track, rustle(length, 310, 1330, 2.6) * .045, start, side)
    for start, side in [(3.7, -.56), (10.9, .57), (16.1, -.2), (26.0, .42), (31.4, -.64), (40.7, .32)]:
        for index in range(3):
            note = bird(.17 + index * .035, 1580 + index * 95 + RNG.uniform(-75, 75), 470 - 60 * index)
            add(track, note * .065, start + index * .32, side)
    room(track, [(.13, .10), (.27, .05)])
    return track


def grove_air():
    seconds = 39
    track = breeze(seconds, 54, 320, .007)
    for start, side in [(2.7, -.43), (10.4, .53), (17.4, -.34), (29.1, .38), (35.4, -.57)]:
        t = timeline(.77)
        creak = np.sin(TAU * (181 * t - 45 * t**2) + .8 * np.sin(TAU * 20 * t))
        snap = periodic_noise(.77, 420, 1350)
        add(track, (.066 * creak + .014 * snap) * envelope(t, .77, .1, .29), start, side)
        length = float(RNG.uniform(1.9, 3.5))
        add(track, rustle(length, 275, 1150, 1.7) * .048, start + .27, side)
    room(track, [(.14, .13), (.38, .055)])
    return track


def mire_air():
    seconds = 42
    track = breeze(seconds, 76, 360, .005)
    for start, side in [(3.8, -.45), (13.7, .43), (23.3, -.55), (36.1, .48)]:
        add(track, rustle(3.4, 310, 980, 1.4) * .026, start, side)
        for index in range(4):
            length = float(RNG.uniform(.18, .40))
            t = timeline(length)
            pitch = float(RNG.uniform(175, 310))
            phase = TAU * (pitch * t - 89 * t * t)
            body = np.sin(phase) + .25 * np.sin(phase * 2.1)
            bubble = body * envelope(t, length, .024, length * .72)
            add(track, bubble * RNG.uniform(.034, .068), start + .65 + index * .43, side + RNG.uniform(-.2, .2))
    room(track, [(.095, .11), (.24, .07)])
    return track


def hollow_air():
    seconds = 43
    track = breeze(seconds, 44, 190, .006)
    for index, start in enumerate([.4, 7.9, 17.3, 24.8, 35.2]):
        side = .52 if index % 2 == 0 else -.53
        sigh = bow([35, 37, 39, 36, 34][index], 4.5, .21)
        add(track, sigh * .063, start, side)
        t = timeline(.72)
        pitch = float(RNG.uniform(450, 690))
        phase = TAU * (pitch * t - 115 * t**2)
        drip = (np.sin(phase) + .22 * np.sin(phase * 1.42)) * np.exp(-t * 8)
        add(track, drip * envelope(t, .72, .012, .29) * .058, start + 2.6, -side * .65)
    room(track, [(.19, .19), (.59, .09), (1.07, .04)])
    return track


def spring_water():
    seconds = 25
    track = breeze(seconds, 160, 880, .018)
    for _ in range(120):
        length = float(RNG.uniform(.065, .20))
        t = timeline(length)
        pitch = float(RNG.uniform(310, 870))
        phase = TAU * (pitch * t - 430 * t**2)
        ripple = np.sin(phase) + .23 * np.sin(phase * 1.8)
        ripple *= envelope(t, length, .012, length * .78)
        add(track, ripple * RNG.uniform(.017, .068), RNG.uniform(0, seconds), RNG.uniform(-.5, .5))
    room(track, [(.08, .16), (.18, .07)])
    return track.mean(axis=1)


def heart_pulse():
    seconds = 26
    track = air(seconds, 44, 240, .027)
    for start in [0.4, 4.7, 9.2, 13.4, 17.9, 22.3]:
        add(track, thud(1.55, 57) * .20, start)
        add(track, thud(1.2, 50) * .11, start + .29)
        add(track, bow(43, 3.45, .42) * .021, start - .65)
    return track.mean(axis=1)


def write(name, samples, peak):
    samples = samples - samples.mean(axis=0)
    samples *= peak / np.max(np.abs(samples))
    pcm = np.rint(samples * 32767).astype("<i2")
    path = AUDIO / f"{name}.wav"
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(1 if pcm.ndim == 1 else pcm.shape[1])
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(pcm.tobytes())
    header = struct.pack("<9I", 0, 0, round(1e9 / RATE), 60, 0, 0, 0, 1, 0)
    loop = struct.pack("<6I", 0, 0, 0, len(samples) - 1, 0, 0)
    with path.open("r+b") as stream:
        stream.seek(0, 2)
        stream.write(b"smpl" + struct.pack("<I", len(header + loop)) + header + loop)
        size = stream.tell()
        stream.seek(4)
        stream.write(struct.pack("<I", size - 8))
    print(f"{name:16s} {len(samples)/RATE:5.1f} s  RMS {20*np.log10(np.sqrt(np.mean(samples**2))):5.1f} dBFS")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--ambience-only", action="store_true", help="Render background and spring ambience.")
    selection.add_argument("--menu-only", action="store_true", help="Render the main-menu theme.")
    options = parser.parse_args()
    AUDIO.mkdir(parents=True, exist_ok=True)
    if options.menu_only:
        write("title_theme", title_score(), .53)
        return
    if not options.ambience_only:
        wild, tension = wilds_score()
        for name, samples, peak in [
            ("garden_theme", garden_score(), .63), ("wilds_theme", wild, .58),
            ("wilds_tension", tension, .45), ("heart_pulse", heart_pulse(), .51),
        ]:
            write(name, samples, peak)
        RNG.bit_generator.state = np.random.default_rng(13749).bit_generator.state
        write("title_theme", title_score(), .53)

    # Keep the ambience reproducible when generated separately from the scores.
    RNG.bit_generator.state = np.random.default_rng(29521).bit_generator.state
    for name, render, peak in [
        ("garden_air", garden_air, .32), ("grove_air", grove_air, .32), ("mire_air", mire_air, .31),
        ("hollow_air", hollow_air, .30), ("spring_water", spring_water, .33),
    ]:
        write(name, render(), peak)


if __name__ == "__main__":
    main()
