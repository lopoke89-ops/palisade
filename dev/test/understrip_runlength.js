// THE UNDERSTRIP: how long a run takes, estimated from the real levels (a tool for the M4 balance pass, not in the suite).
// It builds 40 runs' levels with the game's own generator and the game's own raider placement (06g, and usPopulate from
// 10h), measures each level's walk from the start to the lift (or the boss) on the tiles, and adds up the fighting from the
// raiders' and bosses' health at the M4 scaling. The movement and damage figures are assumptions, stated in ASSUME below,
// for a competent squad that clears most rooms; the director's play-test is the real measure (work order 4.2: 15-20 minutes
// a region, 50-60 a run). node understrip_runlength.js [players, default 2] [runs, default 40]
const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm'), ROOT = path.join(__dirname, '../..');
const PLAYERS = +process.argv[2] || 2, RUNS = +process.argv[3] || 40;
const ASSUME = {
  walk: 2.4,          // tiles a second on the move, cautious (full speed is 3.3)
  explore: 2.0,       // the walk again for side branches, backtracking and the shortcut
  clear: .8,          // the share of the level's raiders a squad fights (some stay asleep in the dark)
  dps: 32,            // damage a player lands each second of a fight (misses, cover and reloads counted)
  fightFloor: 2.5,    // seconds at least per raider, however weak (finding it, lining up)
  stops: 75,          // seconds a level at shrines, merchants and loot
  lift: 8,            // the lift's ring (3 s) and the ride (5 s)
  falls: [.5, .8, 1.1], // squad falls a region (each costs a replay from the last shrine, about a third of a level)
  bossUptime: .55,    // the share of a boss fight you're shooting (the rest is dodging), plus 3 s for its stage change
};
// the generator and the kits
let gen = fs.readFileSync(path.join(ROOT, 'dev/src/js/06g-understrip.js'), 'utf8');
for (const r of [1, 2, 3]) gen = gen.replace(`/*@@US_KIT_R${r}@@*/null`, fs.readFileSync(path.join(ROOT, `dev/data/understrip/rooms-r${r}.json`), 'utf8'));
// the raider placement, taken from the mode's own file
const mode = fs.readFileSync(path.join(ROOT, 'dev/src/js/10h-understrip.js'), 'utf8');
const grab = (src, start, end) => { const i = src.indexOf(start); return src.slice(i, src.indexOf(end, i)) };
const plan = grab(mode, 'const US_PLAN=', 'const US_NAMES='), mix = grab(mode, 'const US_MIX=', '\n'), pop = grab(mode, 'function usPopulate(', '\n// ---------- the run');
const ctx = vm.createContext({});
vm.runInContext(gen + '\n' + plan + '\n' + mix + '\nconst US={maxAlive:40};\n' + pop + '\nglobalThis.__u={usGenerate,usLevelSeed,usPopulate,usRng,usHash,US_KITS,US_PLAN};', ctx);
const U = ctx.__u;
const ETYPES = { rifle: 36, gren: 46, breach: 30, shield: 66, medic: 34, spotter: 30, fire: 40, drone: 10 }, ELITE = 2.5;
const BOSS = { pitboss: 1200, custodian: 1800, gatekeeper: 2400 * 1.2, visitor: 3500 };   // effective, one player on Normal (the Gatekeeper's pilot adds 20%)
const regionHp = [1, 1.2, 1.4], squadHp = 1 + .12 * (PLAYERS - 1), bossHp = 1 + .35 * (PLAYERS - 1);
function walkTiles(L, from, to) {
  const T = L.T, d = new Int32Array(T * T).fill(-1), q = [from[1] * T + from[0]]; d[q[0]] = 0;
  const ok = c => !'#%otK'.includes(c);
  for (let h = 0; h < q.length; h++) { const k = q[h], x = k % T, y = (k / T) | 0; for (const [a, b] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const X = x + a, Y = y + b; if (X < 0 || Y < 0 || X >= T || Y >= T) continue; const kk = Y * T + X; if (d[kk] >= 0 || !ok(L.tiles[Y][X])) continue; d[kk] = d[k] + 1; q.push(kk) } }
  return d[to[1] * T + to[0]];
}
const region = [[], [], []], levels = U.US_PLAN.map(() => []);
for (let run = 0; run < RUNS; run++) {
  const seed = 1000 + run * 7919; const tot = [0, 0, 0];
  U.US_PLAN.forEach(([reg, kind, boss], lv) => {
    const first = U.US_PLAN.findIndex(q => q[0] === reg), L = U.usGenerate(U.US_KITS[reg], U.usLevelSeed(seed, reg, lv - first + 1), kind, boss);
    const M = L.marks, start = M.P[0], goal = boss ? M.B[0] : M.E[0], tiles = walkTiles(L, start, goal);
    const raiders = U.usPopulate(L, U.usRng(U.usHash(L.seed, 77)), reg), hp = raiders.reduce((a, s) => a + ETYPES[s.type] * (s.elite ? ELITE : 1), 0) * regionHp[reg - 1] * squadHp;
    const n = raiders.length * ASSUME.clear, dps = ASSUME.dps * PLAYERS;
    const walk = tiles / ASSUME.walk * (1 + ASSUME.explore), fight = Math.max(hp * ASSUME.clear / dps, n * ASSUME.fightFloor);
    const bossT = boss ? BOSS[boss] * bossHp / (dps * ASSUME.bossUptime) + 3 : 0;
    const t = walk + fight + bossT + ASSUME.stops + ASSUME.lift;
    levels[lv].push({ t, tiles, raiders: raiders.length, walk, fight, bossT }); tot[reg - 1] += t;
  });
  tot.forEach((t, i) => { const lvls = U.US_PLAN.filter(q => q[0] === i + 1).length; region[i].push(t + ASSUME.falls[i] * (t / lvls) / 3) });
}
const mean = a => a.reduce((x, y) => x + y, 0) / a.length, mm = s => `${Math.floor(s / 60)}:${String(Math.round(s % 60)).padStart(2, '0')}`;
const out = { players: PLAYERS, runs: RUNS, assume: ASSUME, levels: U.US_PLAN.map((q, lv) => ({ level: lv + 1, region: q[0], kind: q[2] || q[1], tiles: Math.round(mean(levels[lv].map(l => l.tiles))), raiders: +mean(levels[lv].map(l => l.raiders)).toFixed(1),
  walk: mm(mean(levels[lv].map(l => l.walk))), fight: mm(mean(levels[lv].map(l => l.fight))), boss: q[2] ? mm(mean(levels[lv].map(l => l.bossT))) : '', total: mm(mean(levels[lv].map(l => l.t))) })),
  regions: region.map((r, i) => ({ region: i + 1, mean: mm(mean(r)), min: mm(Math.min(...r)), max: mm(Math.max(...r)) })), run: mm(mean(region[0].map((_, k) => region[0][k] + region[1][k] + region[2][k]))) };
console.log(JSON.stringify(out, null, 1));
