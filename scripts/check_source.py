from pathlib import Path
import plistlib
import re
p=Path(__file__).resolve().parents[1]
files=list((p/'Sculptor').rglob('*.swift'))
assert len(files)>=7, 'missing Swift sources'
plist=plistlib.loads((p/'Sculptor/Info.plist').read_bytes())
assert plist['NSMicrophoneUsageDescription']
assert plist['NSSpeechRecognitionUsageDescription']
assert plist['CFBundleDisplayName']=='Скульптор речи'
wf=(p/'.github/workflows/macos-build.yml').read_text()
assert 'macos-15' in wf and 'xcodebuild' in wf
source='\n'.join(f.read_text() for f in files)
for name in ('AVAudioRecorder','SFSpeechURLRecognitionRequest','AudioAnalyzer','Scoring.makeReport','AIReview.generate','StudioSettings'):
    assert name in source, name
print(f'OK: {len(files)} Swift files; plist, workflow, audio, scoring, optional AI connector present')
