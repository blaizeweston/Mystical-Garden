"""Render the original one-shot interaction cues for Mystical Garden."""

from pathlib import Path
import wave

import numpy as np

from render_soundscape import RATE, TAU, envelope, frequency, periodic_noise, pluck, timeline


AUDIO = Path(__file__).resolve().parents[2] / "audio" / "cues"


def strike(note, length, roughness=.1):
    t = timeline(length)
    phase = TAU * frequency(note) * t
    tone = np.sin(phase) * np.exp(-3.8 * t)
    tone += .23 * np.sin(phase * 2.01) * np.exp(-8.0 * t)
    tone += roughness * np.sin(phase * 3.68) * np.exp(-9.1 * t)
    return tone * envelope(t,length,.012,.24)


def place(target, sample, seconds, gain):
    at = round(seconds * RATE)
    end = min(len(target),at+len(sample))
    target[at:end] += gain * sample[:end-at]


def reflections(track):
    direct = track.copy()
    for delay, gain in [(0.072,.12),(0.146,.08),(0.226,.04)]:
        place(track,direct,delay,gain)
    return track * envelope(timeline(len(track)/RATE),len(track)/RATE,.008,.12)


def theft(variation):
    track = np.zeros(round(1.18 * RATE),dtype=np.float32)
    place(track,strike(54-variation,.78,.32),.015,1.0)
    place(track,strike(49-variation,.72,.26),.18,.81)
    place(track,strike(46-variation,.62,.21),.37,.58)
    t = timeline(.48)
    rush = periodic_noise(.48,390,2100) * envelope(t,.48,.025,.30)
    place(track,rush,.015,.064)
    return reflections(track)


def gate(extract):
    length = 1.45 if extract else 1.15
    track = np.zeros(round(length * RATE),dtype=np.float32)
    notes = [(0.0,57),(.16,64),(.34,69),(.55,73)] if extract else [(0.0,50),(.13,57),(.31,62)]
    for index, (at,note) in enumerate(notes):
        place(track,strike(note,.86,.052),at,.83/(index+1)**.28)
    t = timeline(.6)
    air = periodic_noise(.6,290,1450) * envelope(t,.6,.23,.24)
    place(track,air,0,.037)
    return reflections(track)


def water(fill,variation):
    length = .84 if fill else .71
    track = np.zeros(round(length*RATE),dtype=np.float32)
    t = timeline(length)
    rush = periodic_noise(length,740 if fill else 510,4400)
    rush *= envelope(t,length,.045 if fill else .09,.36)
    track += rush * (.085+.042*np.sin(TAU*(13.0+variation)*t)**2)
    for index in range(4):
        size = .17-.018*index
        u = timeline(size)
        pitch = 920 + 140*index + 67*variation
        if not fill:
            pitch -= 250
        splash = np.sin(TAU*(pitch*u-940*u*u))*envelope(u,size,.008,.1)
        place(track,splash,.072+index*.102,.14-.019*index)
    if fill:
        place(track,strike(78+variation,.46,.17),.47,.21)
    return reflections(track)


def harvest(variation):
    length = .66
    track = np.zeros(round(length*RATE),dtype=np.float32)
    for offset,gain in [(.012,.14),(.095,.095),(.18,.077)]:
        t = timeline(.25)
        leaves = periodic_noise(.25,850+95*variation,4200) * envelope(t,.25,.033,.15)
        place(track,leaves,offset,gain)
    place(track,pluck(52+3*variation,.49),.105,.19)
    return reflections(track)


def research():
    track = np.zeros(round(1.83*RATE),dtype=np.float32)
    for at,note,gain in [(0,55,.49),(.10,62,.58),(.28,67,.67),(.46,69,.45)]:
        place(track,strike(note,1.14,.04),at,gain)
    t = timeline(1.43)
    warm = np.sin(TAU*frequency(43)*t) * envelope(t,1.43,.17,.74)
    place(track,warm,.05,.12)
    return reflections(track)


def write(name, samples):
    samples = samples - samples.mean()
    samples *= .72 / np.max(np.abs(samples))
    pcm = np.rint(samples*32767).astype("<i2")
    with wave.open(str(AUDIO/f"{name}.wav"),"wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(pcm.tobytes())


def main():
    AUDIO.mkdir(parents=True,exist_ok=True)
    for index in range(2):
        write(f"theft_{index+1}",theft(index))
        write(f"fill_{index+1}",water(True,index))
        write(f"water_{index+1}",water(False,index))
        write(f"harvest_{index+1}",harvest(index))
    write("gate_ready",gate(False))
    write("extract_ready",gate(True))
    write("research_complete",research())


if __name__ == "__main__":
    main()
