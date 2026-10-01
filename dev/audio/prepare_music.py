"""Prepare v0.9.6.2 music; FFMPEG selects a binary. Source files are read only."""
import hashlib, json, os, shutil, subprocess, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
FFMPEG = os.environ.get('FFMPEG') or shutil.which('ffmpeg')
if not FFMPEG:
    raise SystemExit('Set FFMPEG to an installed ffmpeg binary.')
TRACKS = [
    ('main_menu', 'Heartbeat', Path('H:/vapeor/luxury elite - blind date - 01 heartbeat.wav'), 0),
    ('between_raids', 'Cold', Path('H:/vapeor/luxury elite - blind date - 02 cold.wav'), 0),
    ('raid_attitude', 'Attitude', Path('H:/vapeor/Luxury Elite - World Class - 04 Attitude.wav'), 0),
    ('raid_cool', 'Cool', Path('H:/vapeor/Luxury Elite - World Class - 12 Cool.wav'), 0),
    ('raid_express', 'Express', Path('H:/vapeor/Luxury Elite - World Class - 09 Express.wav'), 0),
    ('final_blitz', 'Everything She Wants', Path('H:/vapeor/23 - Everything She Wants - Wham!.mp3'), 0),
    ('results', 'Sacrifices', Path('H:/music/Drake - More Life (2017) [Mp3~320kbps]/Drake – More Life (2017)/12 Sacrifices (feat. 2 Chainz & Young Thug).mp3'), 164),
]

def run(args):
    subprocess.run([FFMPEG, '-hide_banner', '-loglevel', 'error', '-y', *map(str, args)], check=True)

def frames(path):
    with tempfile.TemporaryDirectory(dir=ROOT) as folder:
        pcm = Path(folder)/'measure.pcm'
        run(['-i', path, '-map', '0:a:0', '-ar', 48000, '-ac', 2, '-f', 'f32le', pcm])
        return pcm.stat().st_size//8

manifest = {'sampleRate': 48000, 'channels': 2, 'resultsOriginalCueSeconds': 164, 'tracks': {}}
for key, name, source, cue in TRACKS:
    count = frames(source)
    entry = {'title': name, 'source': str(source), 'sourceSHA256': hashlib.sha256(source.read_bytes()).hexdigest(),
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
