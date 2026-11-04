# Draws generated UNDERSTRIP levels (dev/src/js/06g-understrip.js), top-down, for review: path pieces, branches and the
# shortcut outlined in different colours, the markers as dots.
# Usage: python3 dev/plans/understrip/draw_levels.py OUT_DIR [seed ...]      (needs node and Pillow)
#   writes OUT_DIR/level-<kind>-<seed>.png for each seed, as a normal level and as a boss level
import json, os, subprocess, sys
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.normpath(os.path.join(HERE, '../../..'))
out_dir = sys.argv[1]; seeds = [int(s) for s in sys.argv[2:]] or [1, 2, 3]
os.makedirs(out_dir, exist_ok=True)
JS = r'''
const fs=require('fs'),vm=require('vm'),R=process.argv[1];
const kit=fs.readFileSync(R+'/dev/data/understrip/rooms-r1.json','utf8');
const src=fs.readFileSync(R+'/dev/src/js/06g-understrip.js','utf8').replace('/*@@US_KIT_R1@@*/null',kit);
const c=vm.createContext({});vm.runInContext(src+';globalThis.U={usGenerate,usLevelSeed,usTileHash,US_KITS}',c);
const out=[];for(const s of JSON.parse(process.argv[2]))for(const kind of['normal','boss']){const seed=c.U.usLevelSeed(s,1,kind==='boss'?3:1),L=c.U.usGenerate(c.U.US_KITS[1],seed,kind);L.hash=c.U.usTileHash(L);L.runSeed=s;out.push(L)}
process.stdout.write(JSON.stringify(out));
'''
levels = json.loads(subprocess.check_output(['node', '-e', JS, ROOT, json.dumps(seeds)]))
GROUND = {'#': '#141513', '%': '#4a4c47', 'o': '#6b5a3a', '.': '#55574f', ',': '#3f4a48', '~': '#1f3b4c', '=': '#6f6a5c', 'K': '#ff9a3a', 'G': '#ff5a3a', 'D': '#55574f'}
DOT = {'P': '#7fd0ff', 'E': '#7cff6b', 'S': '#ff5ad8', 'M': '#c78bff', 'C': '#c88a3a', 'A': '#ff3a3a', 'B': '#ff3a3a', 'L': '#ffcc66', 'n': '#4fd2ff'}
EDGE = {'path': '#e2b436', 'branch': '#5a8fd0', 'shortcut': '#ff9a3a'}
font = ImageFont.load_default(); T = 10
for L in levels:
    n = L['T']; img = Image.new('RGB', (n * T + 260, n * T + 20), '#0e0f0d'); d = ImageDraw.Draw(img); ox = oy = 10
    for y, row in enumerate(L['tiles']):
        for x, c in enumerate(row):
            d.rectangle([ox + x * T, oy + y * T, ox + x * T + T - 1, oy + y * T + T - 1], fill=GROUND.get(c, '#55574f'))
            if c in DOT: d.ellipse([ox + x * T + 2, oy + y * T + 2, ox + x * T + T - 3, oy + y * T + T - 3], fill=DOT[c])
    for r in L['rooms']:
        d.rectangle([ox + r['x'] * T, oy + r['y'] * T, ox + (r['x'] + r['w']) * T - 1, oy + (r['y'] + r['h']) * T - 1], outline=EDGE.get(r['tag'], '#888'))
        if r['tag'] == 'path': d.text((ox + r['x'] * T + 3, oy + r['y'] * T + 2), str(r['at']), fill='#e2b436', font=font)
    tx = n * T + 24; ty = 14
    for line in [f"{L['kind'].upper()} LEVEL", f"run seed {L['runSeed']}", f"level seed {L['seed']}", f"tile hash {L['hash']:08x}",
                 f"{L['T']}x{L['T']} tiles, {L['G']}x{L['G']} cells", f"path {L['pathLen']} pieces", f"branches {L['branchN']} ({L['branchN'] / (L['pathLen'] + L['branchN']) * 100:.0f}%)",
                 f"breather at {L['breatherAt']}", f"attempts {L['attempts']}", '', 'gold: critical path (numbered)', 'blue: branches', 'orange: shortcut route',
                 '', 'blue dots: start', 'green: exit', 'pink: shrine', 'violet: merchant', 'brown: chest', 'red: ambush / boss', 'orange bar: shortcut door', 'red bar: boss gate']:
        d.text((tx, ty), line, fill='#e8e2d0' if ty < 30 else '#c8c3b8', font=font); ty += 15
    p = os.path.join(out_dir, f"level-{L['kind']}-{L['runSeed']}.png"); img.save(p); print(os.path.relpath(p, ROOT))
