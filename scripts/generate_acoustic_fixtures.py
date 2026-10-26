#!/usr/bin/env python3
"""Generate deterministic non-speech acoustics; no personal recordings."""
import math, struct, wave
from pathlib import Path
p=Path("build/acoustic-fixtures");p.mkdir(parents=True,exist_ok=True)
def wav(name,segments,rate=16000):
    with wave.open(str(p/name),"wb") as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate)
        data=bytearray()
        for kind,seconds,hz in segments:
            for i in range(int(seconds*rate)):
                value=0 if kind=="silence" else int(12000*math.sin(2*math.pi*hz*i/rate))
                data.extend(struct.pack("<h",value))
        w.writeframes(data)
wav("silence.wav",[("silence",8,0)])
wav("continuous_180hz.wav",[("tone",12,180)])
wav("two_bursts.wav",[("tone",4,180),("silence",1,0),("tone",4,180)])
wav("variable_pitch.wav",[("tone",5,140),("tone",5,210),("tone",5,165)])
print("Generated four deterministic acoustic test WAV files")
