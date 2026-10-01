"""Compare seeded states and screenshot sequences; never resize the evidence."""
from pathlib import Path
import json
import numpy as np
from PIL import Image

root = Path(__file__).parent / 'out' / 'render-perf'
report = {}
for backend in ('software', 'default'):
    before = root / f'baseline-{backend}.json'
    after = root / f'candidate-{backend}.json'
    if not before.exists() or not after.exists():
        continue
    a, b = json.loads(before.read_text()), json.loads(after.read_text())
    for scene in a['scenes']:
        x, y = a['scenes'][scene], b['scenes'][scene]
        states_equal = x['states'] == y['states']
        diffs = []
        for frame in range(6):
            p = np.asarray(Image.open(root / f'baseline-{backend}-{scene}-{frame}.png')).astype(int)
            q = np.asarray(Image.open(root / f'candidate-{backend}-{scene}-{frame}.png')).astype(int)
            d = np.abs(p - q)
            diffs.append({'frame': frame, 'changedPixels': int(np.count_nonzero(np.max(d, axis=2))), 'maxChannelDelta': int(d.max())})
        improvement = (1 - y['renderWithBarrierMs']['median'] / x['renderWithBarrierMs']['median']) * 100
        report[f'{backend}-{scene}'] = {'renderMedianImprovementPercent': round(improvement, 2), 'simulationStatesEqual': states_equal, 'motionFrames': diffs}
        assert states_equal, f'Simulation changed: {backend}/{scene}'
        print(f'{backend}/{scene}: render median {improvement:.1f}% faster, states equal, pixel diffs {diffs}')
(root / 'comparison.json').write_text(json.dumps(report, indent=2) + '\n')
cache_diffs = []
for before in sorted(root.glob('cache-baseline-*.png')):
    after = root / before.name.replace('cache-baseline-', 'cache-candidate-', 1)
    if not after.exists():
        continue
    p, q = np.asarray(Image.open(before)).astype(int), np.asarray(Image.open(after)).astype(int)
    d = np.abs(p - q)
    changed = int(np.count_nonzero(np.max(d, axis=2)))
    cache_diffs.append({'scene': before.stem.removeprefix('cache-baseline-'), 'changedPixels': changed, 'pixelCount': int(p.shape[0] * p.shape[1]), 'maxChannelDelta': int(d.max()), 'meanChannelDelta': float(d.mean())})
if cache_diffs:
    (root / 'cache-pixel-comparison.json').write_text(json.dumps(cache_diffs, indent=2) + '\n')
    print(f"Cache visual checks: {len(cache_diffs)}, exact: {sum(x['changedPixels'] == 0 for x in cache_diffs)}, max channel delta: {max(x['maxChannelDelta'] for x in cache_diffs)}")
    # Skia's resampling matrices use finite precision. Reusing integer-translated
    # samples may differ at a few high-contrast edge pixels from a fresh large
    # image resample. Reject shifted/missing/stale geometry and meaningful color
    # changes; retain exact counts so a reviewer can assess the tolerance.
    assert all(x['maxChannelDelta'] <= 16 and x['changedPixels'] / x['pixelCount'] < .001 and x['meanChannelDelta'] < .005 for x in cache_diffs), 'Cache changed visible artwork beyond sparse edge interpolation'
