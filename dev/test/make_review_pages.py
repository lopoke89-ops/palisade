from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'dev' / 'test' / 'out'
BASELINE = 'b93face'
CANDIDATE = '566e30e'

changed = subprocess.check_output(
    ['git', 'diff', '--name-only', f'{BASELINE}..{CANDIDATE}'], cwd=ROOT, text=True
).splitlines()
expected = {'dev/src/js/20-locker-ui.js', 'dev/src/style.css'}
if set(changed) != expected:
    raise SystemExit(f'Unexpected intervening changes: {changed}')

def at(ref, path):
    return subprocess.check_output(
        ['git', 'show', f'{ref}:{path}'], cwd=ROOT
    ).decode('utf-8')

paths = subprocess.check_output(
    ['git', 'ls-tree', '-r', '--name-only', CANDIDATE, '--', 'dev/src/js'],
    cwd=ROOT, text=True
).splitlines()
paths = [path for path in paths if path.endswith('.js')]

def make(ref, label):
    page = at(ref, 'dev/src/page.html')
    css = at(ref, 'dev/src/style.css')
    js = '\n'.join(
        at(ref, path) for path in paths
    )
    page = page.replace('/*@@STYLE@@*/', css.rstrip('\n'))
    page = page.replace('/*@@SCRIPT@@*/', js.rstrip('\n'))
    page = re.sub(r'<link rel="(?:preconnect|stylesheet)"[^>]+>\n', '', page, count=3)
    page = '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover,user-scalable=no"><base href="/"><title>PALISADE benchmark</title></head><body>' + page + '</body></html>'
    dest = OUT / ('review-' + label + '.html')
    dest.write_text(page, encoding='utf-8')
    print(dest)

OUT.mkdir(parents=True, exist_ok=True)
make(BASELINE, 'baseline')
make(CANDIDATE, 'candidate')
