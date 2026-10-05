"""Prepare the music; FFMPEG selects a binary. Source files are read only.
ONLY=casino_1,casino_2 (or ONLY=casino) re-encodes just those tracks and keeps the rest of the manifest."""
import hashlib, json, os, shutil, subprocess, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
FFMPEG = os.environ.get('FFMPEG') or shutil.which('ffmpeg')
if not FFMPEG:
    raise SystemExit('Set FFMPEG to an installed ffmpeg binary.')
TRACKS = [
    ('main_menu', 'Pali Mix', Path('pali_mix.mp3'), 0),   # v0.9.7.2: Big U's mix (the uploaded file; not kept in the repo)
    ('between_raids', 'Cold', Path('H:/vapeor/luxury elite - blind date - 02 cold.wav'), 0),
    ('raid_attitude', 'Attitude', Path('H:/vapeor/Luxury Elite - World Class - 04 Attitude.wav'), 0),
    ('raid_cool', 'Cool', Path('H:/vapeor/Luxury Elite - World Class - 12 Cool.wav'), 0),
    ('raid_express', 'Express', Path('H:/vapeor/Luxury Elite - World Class - 09 Express.wav'), 0),
    ('final_blitz', 'Everything She Wants', Path('H:/vapeor/23 - Everything She Wants - Wham!.mp3'), 0),
    ('results', 'Sacrifices', Path('H:/music/Drake - More Life (2017) [Mp3~320kbps]/Drake – More Life (2017)/12 Sacrifices (feat. 2 Chainz & Young Thug).mp3'), 164),
]
# v0.10.1: the casino's own playlist (Big U's 'casino music' folder at the repo root), shuffled and crossfaded in 03-audio.js
TRACKS += [(f'casino_{n}', f'Ambience {n}', ROOT.parent.parent/'casino music'/f'ambience {n}.mp3', 0) for n in range(1, 12)]
ONLY = [k for k in os.environ.get('ONLY', '').split(',') if k]
if ONLY: TRACKS = [t for t in TRACKS if any(t[0] == k or t[0].startswith(k+'_') for k in ONLY)]

def run(args):
    subprocess.run([FFMPEG, '-hide_banner', '-loglevel', 'error', '-y', *map(str, args)], check=True)

def frames(path):
    with tempfile.TemporaryDirectory(dir=ROOT) as folder:
        pcm = Path(folder)/'measure.pcm'
        run(['-i', path, '-map', '0:a:0', '-ar', 48000, '-ac', 2, '-f', 'f32le', pcm])
        return pcm.stat().st_size//8

manifest = {'sampleRate': 48000, 'channels': 2, 'resultsOriginalCueSeconds': 164, 'tracks': {}}
if ONLY: manifest = json.loads((ROOT/'music-manifest.json').read_text(encoding='utf-8'))
for key, name, source, cue in TRACKS:
    count = frames(source)
    entry = {'title': name, 'source': str(source.relative_to(ROOT.parent.parent)) if source.is_relative_to(ROOT.parent.parent) else str(source), 'sourceSHA256': hashlib.sha256(source.read_bytes()).hexdigest(),
             'sourceFrames': count, 'sourceSeconds': count/48000, 'trimStartSeconds': cue,
             'releaseFrames': count-cue*48000, 'loopSeconds': count/48000-cue, 'formats': {}}
    for ext, codec, bitrate in [('m4a', 'aac', '160k'), ('ogg', 'libopus', '128k')]:
        dest = ROOT/f'{key}.{ext}'
        args = ['-i', source]
        if cue: args += ['-ss', cue]
        args += ['-map', '0:a:0', '-map_metadata', '-1', '-vn', '-ar', 48000, '-ac', 2, '-c:a', codec, '-b:a', bitrate]
        if ext == 'm4a': args += ['-movflags', '+faststart']
        run([*args, dest])
        entry['formats'][ext] = {'bytes': dest.stat().st_size, 'SHA256': hashlib.sha256(dest.read_bytes()).hexdigest(), 'decodedFrames': frames(dest)}
    manifest['tracks'][key] = entry
    print(key, round(entry['loopSeconds'], 6), flush=True)
(ROOT/'music-manifest.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
