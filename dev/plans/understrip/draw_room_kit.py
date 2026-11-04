# Draws a room kit (dev/data/understrip/rooms-r<N>.json) as one picture sheet, top-down, for review.
# Usage: python3 dev/plans/understrip/draw_room_kit.py [1]     -> dev/plans/understrip/room-kit-r1.png   (needs Pillow)
import json, os, sys
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.normpath(os.path.join(HERE, '../../..'))
reg = sys.argv[1] if len(sys.argv) > 1 else '1'
kit = json.load(open(os.path.join(ROOT, f'dev/data/understrip/rooms-r{reg}.json'), encoding='utf-8'))
T = 14   # pixels a tile
GROUND = {'#': '#1b1c1a', '%': '#4a4c47', 'o': '#6b5a3a', '.': '#55574f', ',': '#3f4a48', '~': '#1f3b4c', '=': '#6f6a5c', 'K': '#8a4a2a'}
MARK = {'D': ('#55574f', None), 'G': ('#55574f', '#ff5a3a'), 'P': ('#55574f', '#7fd0ff'), 'E': ('#55574f', '#7cff6b'), 'S': ('#55574f', '#ff5ad8'),
        'M': ('#55574f', '#c78bff'), 'C': ('#55574f', '#c88a3a'), 'A': ('#55574f', '#ff3a3a'), 'B': ('#55574f', '#ff3a3a'),
        'L': ('#55574f', '#ffcc66'), 'n': ('#55574f', '#4fd2ff')}
font = ImageFont.load_default()
pieces = kit['pieces']; pad = 18; labelH = 30
# lay the pieces out in rows, up to 1400 px wide
x = y = pad; rowH = 0; spots = []; Wmax = 1400
for p in pieces:
    w, h = p['size'][0] * 8 * T, p['size'][1] * 8 * T
    if x + w + pad > Wmax: x = pad; y += rowH + labelH + pad; rowH = 0
    spots.append((p, x, y)); x += w + pad; rowH = max(rowH, h)
H = y + rowH + labelH + pad + 150
img = Image.new('RGB', (Wmax, H), '#0e0f0d'); d = ImageDraw.Draw(img)
for p, ox, oy in spots:
    g = p['grid']
    for j, row in enumerate(g):
        for i, c in enumerate(row):
            x0, y0 = ox + i * T, oy + labelH + j * T
            base, dot = MARK.get(c, (GROUND.get(c, '#ff00ff'), None))
            d.rectangle([x0, y0, x0 + T - 1, y0 + T - 1], fill=base)
            if c in ',': d.line([x0 + 2, y0 + T - 4, x0 + T - 3, y0 + T - 4], fill='#5d6e6a')
            if c == '%': d.rectangle([x0 + 2, y0 + 2, x0 + T - 3, y0 + T - 3], outline='#7a7c75')
            if c == 'K': d.line([x0, y0 + T // 2, x0 + T, y0 + T // 2], fill='#ffb070', width=2)
            if c in 'DG': d.rectangle([x0, y0, x0 + T - 1, y0 + T - 1], outline=dot or '#9a9a8a')
            elif dot: d.ellipse([x0 + 3, y0 + 3, x0 + T - 4, y0 + T - 4], fill=dot)
    # cell lines
    for k in range(1, p['size'][0]): d.line([ox + k * 8 * T, oy + labelH, ox + k * 8 * T, oy + labelH + len(g) * T], fill='#2c2e2a')
    for k in range(1, p['size'][1]): d.line([ox, oy + labelH + k * 8 * T, ox + len(g[0]) * T, oy + labelH + k * 8 * T], fill='#2c2e2a')
    d.text((ox, oy + 2), p['id'], fill='#e8e2d0', font=font)
    d.text((ox, oy + 15), f"{p['role']} · {p['size'][0]}x{p['size'][1]} · light {p['light']}", fill='#9a958a', font=font)
# key
ky = H - 140; d.text((pad, ky), f"{kit['name']} room kit (region {reg}): top-down, north up, one square a tile, 8 x 8 tiles a cell", fill='#e8e2d0', font=font)
key = [('#', 'wall'), ('%', 'pillar'), ('o', 'low cover'), ('.', 'floor'), (',', 'low floor (floods)'), ('~', 'water'), ('=', 'grate bridge'), ('K', 'shortcut door'),
       ('D', 'doorway'), ('G', 'boss gate'), ('P', 'player start'), ('E', 'exit'), ('S', 'shrine'), ('M', 'merchant'), ('C', 'chest'), ('A', 'ambush'), ('B', 'boss'), ('L', 'lamp'), ('n', 'neon')]
for n, (c, name) in enumerate(key):
    kx, kyy = pad + (n % 7) * 190, ky + 22 + (n // 7) * 26
    base, dot = MARK.get(c, (GROUND.get(c), None)); d.rectangle([kx, kyy, kx + T, kyy + T], fill=base)
    if c in 'DG': d.rectangle([kx, kyy, kx + T, kyy + T], outline=dot or '#9a9a8a')
    elif dot: d.ellipse([kx + 3, kyy + 3, kx + T - 3, kyy + T - 3], fill=dot)
    if c == 'K': d.line([kx, kyy + T // 2, kx + T, kyy + T // 2], fill='#ffb070', width=2)
    d.text((kx + T + 8, kyy + 2), f"{c}  {name}", fill='#c8c3b8', font=font)
out = os.path.join(HERE, f"room-kit-r{reg}.png"); img.save(out); print(os.path.relpath(out, ROOT), img.size)
