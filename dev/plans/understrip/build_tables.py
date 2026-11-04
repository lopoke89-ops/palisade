# THE UNDERSTRIP M0 tables: checks the CSVs in tables/ and builds understrip-tables.xlsx from them.
# The CSVs are the source (edit them, in any spreadsheet); the workbook is generated, with two extra sheets:
# CASE ODDS (each item's chance, beside the Winter and Halloween cases') and BASELINE (the game's own numbers
# the tables are balanced against, read from dev/src and the cosmetics catalogue).
# Usage: python3 dev/plans/understrip/build_tables.py        (needs openpyxl)
import csv, json, os, re, sys
from collections import Counter
HERE = os.path.dirname(os.path.abspath(__file__)); T = os.path.join(HERE, 'tables'); ROOT = os.path.normpath(os.path.join(HERE, '../../..'))
JS = os.path.join(ROOT, 'dev/src/js')
ORDER = ['weapons', 'weapon_tiers', 'weapon_mods', 'perks', 'relics', 'consumables', 'healing', 'merchants', 'loot_sources', 'enemies', 'bosses', 'case', 'case_items']
RAR = ['c', 'r', 'e', 'l', 'g']
tab = {n: list(csv.DictReader(open(os.path.join(T, n + '.csv'), encoding='utf-8'))) for n in ORDER}
errs = []
def check(ok, msg):
    if not ok: errs.append(msg)
def weights(s): return {k: float(v) for k, v in (p.split(':') for p in s.split())}
src = lambda f: open(os.path.join(JS, f), encoding='utf-8').read()

# ids are unique and rarities real
for n, rows in tab.items():
    if rows and 'id' in rows[0]:
        c = Counter(r['id'] for r in rows); check(all(v == 1 for v in c.values()), f'{n}: duplicate ids {[k for k, v in c.items() if v > 1]}')
    for r in rows:
        if 'rarity' in r: check(r['rarity'] in RAR, f"{n} {r.get('id')}: rarity {r['rarity']!r}")
# counts the work order fixes
check(len(tab['weapons']) == 9 and Counter(r['region'] for r in tab['weapons']) == Counter({'1': 3, '2': 3, '3': 3}), 'weapons: 3 per region')
check(len(tab['perks']) == 20, f"perks: {len(tab['perks'])}, the work order asks for 20")
ci = tab['case_items']; cats = Counter(r['cat'] for r in ci)
check(cats == Counter({'skin': 10, 'hat': 5, 'trail': 5, 'fx': 5, 'bg': 5}), f'case items by category: {dict(cats)}')
check(Counter(r['rarity'] for r in ci if r['cat'] == 'skin') == Counter({'r': 3, 'e': 3, 'l': 3, 'g': 1}), 'skins: 3 rare, 3 epic, 3 legendary, 1 gold (section 9.2)')
# perk names don't reuse a skill-tree name (SECOND WIND is the skill tree's)
skill_names = set(re.findall(r"name:'([^']+)'", src('01b-mods-skills.js').split('const SKILLBY')[0].split('const SKILLS=')[1]))
for r in tab['perks']: check(r['name'] not in skill_names, f"perk {r['id']}: {r['name']} is already a skill-tree node")
# gold only from the Collector
for r in tab['merchants']: check('g' not in weights(r['rarity_weights']) or r['id'] == 'm_collector', f"{r['id']} sells gold; only the Collector does")
# case: every weighted tier has items (the server hands out a random item of any tier when a tier is empty)
case = {r['key']: r['value'] for r in tab['case']}; W = weights(case['weights']); per = Counter(r['rarity'] for r in ci)
for k, v in W.items(): check(v == 0 or per[k] > 0, f'case weight {k}:{v} has no items in that tier')
# keys and names are new
cat = json.load(open(os.path.join(ROOT, 'dev/catalog/cosmetics/catalog.json'), encoding='utf-8'))['items']
cat = list(cat.values()) if isinstance(cat, dict) else cat
have_id = {i['id'] for i in cat}; have_name = {(i['cat'], i['name'].lower()) for i in cat}
for r in ci:
    check(re.fullmatch(r'(skin|hat|trail|fx|bg):[a-z0-9]+', r['id']) is not None, f"{r['id']}: ids are cat:lowercase")
    check(r['id'] not in have_id, f"{r['id']} already exists in the catalogue")
    check((r['cat'], r['name'].lower()) not in have_name, f"{r['id']}: '{r['name']}' is already a {r['cat']}'s name")
check(case['id'] not in re.findall(r'^\s*([a-z]+):\{name:', src('18-cosmetics.js').split('const CASES={')[1].split('};')[0], re.M), 'the case id is taken')

# derived numbers
def dps(w):
    d, p, cd, mag, rl = float(w['dmg']), float(w['pellets']), float(w['cd']), float(w['mag']), float(w['reload'])
    if w['id'] == 'w_alien': d, cd = 64, cd + 1.2   # full charge
    return round(d * p / cd), round(d * p * mag / (mag * cd + rl))
for w in tab['weapons']: w['burst_dps'], w['sustained_dps'] = dps(w)
# baseline: the class guns, raiders and bosses as the game has them
s1 = src('01-setup.js'); base = []
for m in re.finditer(r"^\s*(\w+):\{name:'([A-Z]+)',hp:(\d+).*?gun:\{([^}]*)\}", s1, re.M):
    g = dict(re.findall(r'(\w+):([\d.]+)', m.group(4))); d, cd, p = float(g['dmg']), float(g['cd']), float(g.get('pellets', 1))
    base.append(['class', m.group(2), m.group(3), f"{d:g} x{p:g} every {cd:g} s", round(d * p / cd), 'burst DPS, every shot landing, no upgrades'])
s10 = src('10-phases-bosses.js'); bhp = float(re.search(r'BOSS_HP=([\d.]+)', src('10e-boss-moves.js')).group(1))
for k, v in re.findall(r"(\w+):\{hp:(\d+),speed", s10.split('const ETYPES=')[1].split(';')[0]): base.append(['raider', k, v, '', '', 'ETYPES; x map HP; x difficulty'])
for k, nm, hp in re.findall(r"^\s*(\w+):\{name:'([^']+)',hp:(\d+)", s10.split('const BOSSES={')[1].split('\n};')[0], re.M):
    base.append(['boss', nm, hp, f'effective {round(int(hp) * bhp)}', '', f'x BOSS_HP {bhp:g}; x1.35 per extra player'])

# case odds beside two existing cases
def odds(wt, items): n = Counter(i for i in items); return {k: (wt.get(k, 0) / sum(wt.values()) * 100 / n[k]) if n[k] else None for k in RAR}
ex = {}
for box in ('winter', 'halloween'):
    wm = re.search(box + r":\{[^}]*?weights:\{([^}]*)\}", src('18-cosmetics.js')); wt = {k: float(v) for k, v in re.findall(r'(\w):([\d.]+)', wm.group(1))}
    ex[box] = (wt, odds(wt, [i['r'] for i in cat if i.get('box') == box]), Counter(i['r'] for i in cat if i.get('box') == box))
us = odds(W, [r['rarity'] for r in ci])

if errs:
    print('FAIL build_tables:'); [print('  - ' + e) for e in errs]; sys.exit(1)
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment
wb = Workbook(); wb.remove(wb.active)
HEAD = PatternFill('solid', fgColor='1F2A22'); HF = Font(bold=True, color='E8E2D0')
def sheet(name, header, rows, widths=None):
    ws = wb.create_sheet(name[:31]); ws.append(header)
    for c in ws[1]: c.fill = HEAD; c.font = HF; c.alignment = Alignment(wrap_text=True, vertical='top')
    for r in rows: ws.append([float(v) if isinstance(v, str) and re.fullmatch(r'-?\d+(\.\d+)?', v) else v for v in r])
    for i, col in enumerate(ws.columns):
        L = max(len(str(c.value or '')) for c in col); ws.column_dimensions[col[0].column_letter].width = min(48, max(8, L + 2))
        for c in col[1:]: c.alignment = Alignment(wrap_text=True, vertical='top')
    ws.freeze_panes = 'B2'
for n in ORDER:
    rows = tab[n]; h = list(rows[0].keys()); sheet(n.upper().replace('_', ' '), h, [[r[k] for k in h] for r in rows])
pct = lambda v: '' if v is None else round(v, 2)
sheet('CASE ODDS', ['rarity', 'weight', 'items', 'each item %', 'Winter items', 'Winter each %', 'Halloween items', 'Halloween each %'],
      [[k, W.get(k, 0), per[k], pct(us[k]), ex['winter'][2][k], pct(ex['winter'][1][k]), ex['halloween'][2][k], pct(ex['halloween'][1][k])] for k in RAR])
sheet('BASELINE', ['kind', 'name', 'hp', 'gun / scale', 'dps', 'notes'], base)
out = os.path.join(HERE, 'understrip-tables.xlsx'); wb.save(out)
print(f"OK build_tables: {sum(len(v) for v in tab.values())} rows in {len(ORDER)} tables; {os.path.relpath(out, ROOT)}")
for w in tab['weapons']: print(f"  {w['id']:12} burst {w['burst_dps']:>4}  sustained {w['sustained_dps']:>4}")
print('  case each-item %:', {k: pct(v) for k, v in us.items()}, ' winter:', {k: pct(v) for k, v in ex['winter'][1].items()})
