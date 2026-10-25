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
if ! command -v ffmpeg >/dev/null 2>&1; then brew install ffmpeg; fi
for path in build/audio-fixtures/*.wav; do
  base="${path%.wav}"
  ffmpeg -nostdin -hide_banner -loglevel error -y -i "$path" -ac 1 -ar 22050 -c:a pcm_s16le "${base}.caf"
  ffmpeg -nostdin -hide_banner -loglevel error -y -i "$path" -ac 1 -ar 44100 -c:a pcm_s16be "${base}.aiff"
  ffmpeg -nostdin -hide_banner -loglevel error -y -i "$path" -ac 1 -ar 44100 -c:a aac -b:a 128k "${base}.m4a"
done
swiftc -O -o build/audio-regression \
    Sculptor/Models/AnalysisCore.swift \
    Sculptor/Models/SpeechContext.swift \
    Sculptor/Services/AudioPreparation.swift \
    Sculptor/Services/AudioAnalyzer.swift \
    Tests/AudioPipelineRegression.swift
build/audio-regression build/audio-fixtures/*.wav build/audio-fixtures/*.caf build/audio-fixtures/*.aiff build/audio-fixtures/*.m4a
