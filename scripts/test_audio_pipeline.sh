#!/bin/bash
set -euo pipefail
mkdir -p build/audio-fixtures
python3 - <<'PY'
import wave, math, struct
from pathlib import Path
p=Path("build/audio-fixtures")
for rate,channels in ((16000,1),(44100,2),(48000,2)):
    with wave.open(str(p/f"tone-{rate}-{channels}.wav"),"wb") as w:
        w.setnchannels(channels);w.setsampwidth(2);w.setframerate(rate)
        buf=bytearray()
        for i in range(rate*2):
            sample=int(8000*math.sin(2*math.pi*185*i/rate))
            buf.extend(struct.pack("<h",sample)*channels)
        w.writeframes(buf)
PY
for path in build/audio-fixtures/*.wav; do
  base="${path%.wav}"
  afconvert -f caff -d 'LEI16@22050' "$path" "${base}.caf"
  afconvert -f AIFF -d 'BEI16@44100' "$path" "${base}.aiff"
  afconvert -f m4af -d aac -b 128000 "$path" "${base}.m4a"
done
swiftc -O -o build/audio-regression \
    Sculptor/Models/AnalysisCore.swift \
    Sculptor/Services/AudioPreparation.swift \
    Sculptor/Services/AudioAnalyzer.swift \
    Tests/AudioPipelineRegression.swift
build/audio-regression build/audio-fixtures/*.wav build/audio-fixtures/*.caf build/audio-fixtures/*.aiff build/audio-fixtures/*.m4a
