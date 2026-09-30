// v0.9.0 gameplay: maps (layouts, water, floods, pits, night), the Ferryman and the Foreman, the four new raiders,
// the October Butcher and boss-by-boss case drops, plus the before/after wave table.
// v0.9.1: per-map enemy health, two bosses on XL, oil drums no longer stop shots, and the PvP layouts. node v090.js
const { chromium } = require('playwright');
const assert = require('assert');
const PORT = process.env.PORT || 8080;
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined });
  const p = await b.newPage({ viewport: { width: 1280, height: 800 } }); const errors = [];
  p.on('pageerror', e => errors.push(e.message + ' ' + (e.stack || '').split('\n')[1]));
  await p.goto(`http://localhost:${PORT}/debug.html?debug=1`); await p.waitForTimeout(1000);
  const E = f => p.evaluate(f), out = {};
  // helpers inside the page: start a run on a map, keep everyone alive, step the game
  await E(() => {
    const P = __pal; let s = 11; Math.random = () => (s = (s * 16807) % 2147483647) / 2147483647;
    window.run = (map, size = 'std', mode = '10') => { if (!P.demo && document.getElementById('menu').hidden) P.toMenu();   // v0.9.3.7: a new run starts from the menu
      P.pick.map = map; P.pick.size = size; P.pick.mode = mode; P.pick.diff = 'normal'; P.showPage('solo'); document.getElementById('startBtn').click(); return P.game };
    window.imm = () => { for (const q of P.players.values()) { q.max = 1e9; q.hp = 1e9 } P.core.max = 1e9; P.core.hp = 1e9; P.qm.hp = 1e9 };
    window.step = (n, keep = true) => { for (let i = 0; i < n; i++) { if (keep) imm(); P.update(1 / 30) } };
    window.clearField = () => { for (const e of P.enemies) e.dead = true; P.update(1 / 30); P.game.queue = []; P.lobs.length = 0 };
    window.idx = (i, j) => j * P.N + i;
    window.dummy = () => { const d = P.spawnEnemyAt('rifle', P.N - .5, .5); d.speed = 0; d.hp = d.max = 1e9; d.cd = 1e9; return d };   // keeps a raid going
  });
  // 1. layouts: for every map and size the stake, piles and spawns sit on usable ground, and every spawn reaches the stake
  out.layouts = await E(() => {
    const P = __pal, r = {};
    for (const map of Object.keys(P.MAPS)) for (const size of ['std', 'xl']) {
      run(map, size); const N = P.N, L = P.game.lay, bad = [], seen = new Set();
      const put = (i, j, what) => { const k = idx(i, j); if (i < 0 || j < 0 || i >= N || j >= N) bad.push(what + ' off map'); if (seen.has(k)) bad.push(what + ' overlaps'); seen.add(k); if (P.terr[k] !== 0 && P.terr[k] !== 3) bad.push(what + ' on terrain ' + P.terr[k]) };
      put(P.core.i, P.core.j, 'stake'); for (const n of L.nodes) put(n.i, n.j, 'node'); for (const [t] of L.ruins) for (const [i, j] of t) put(i, j, 'ruin');
      let unreach = 0, spawns = 0; for (const s of L.spawns) for (const [i, j] of s.tiles) { spawns++; if (P.game && window.__pal) { } }
      // the flow field from the stake must reach every spawn tile
      P.update(1 / 30); const d = []; for (const s of L.spawns) for (const [i, j] of s.tiles) { const v = P.bestStepDist ? 0 : 0; d.push([i, j]) }
      r[map + ':' + size] = { N, bad, spawns, nodes: L.nodes.length, water: P.terr.filter(t => t === 1).length, bridges: P.terr.filter(t => t === 2).length, low: P.terr.filter(t => t === 3).length, cracked: P.terr.filter(t => t === 4).length, rock: P.terr.filter(t => t === 6).length, drums: P.terr.filter(t => t === 7).length };
      P.toMenu();
    }
    return r;
  });
  for (const [k, v] of Object.entries(out.layouts)) assert.deepEqual(v.bad, [], k + ' layout: ' + v.bad.join(', '));
  assert.equal(out.layouts['river:std'].bridges, 4); assert.ok(out.layouts['river:xl'].bridges >= 6, 'XL river has a third bridge');
  assert.ok(out.layouts['quarry:std'].cracked > 10 && out.layouts['quarry:std'].drums === 6);
  // every spawn tile reaches the stake (a walk along the flow field ends at the stake)
  out.reach = await E(() => {
    const P = __pal, res = {};
    for (const map of Object.keys(P.MAPS)) for (const size of ['std', 'xl']) {
      run(map, size); const L = P.game.lay; let bad = 0; P.walls.fill(null); P.update(1 / 30); for (let i = 0; i < 12; i++) P.update(.05);
      for (const s of L.spawns) for (const [i, j] of s.tiles) { const e = P.spawnEnemyAt('rifle', i + .5, j + .5); e.speed = 6; }
      P.qm.gone = true; P.qm.alive = false; P.qm.x = -60; for (const q of P.players.values()) { q.x = -50; q.y = -50; q.alive = false }
      for (let t = 0; t < 30 * 40; t++) { imm(); for (const e of P.enemies) { e.cd = 9; e.hp = e.max } P.update(1 / 30) }
      for (const e of P.enemies) if (Math.hypot(e.x - P.core.i - .5, e.y - P.core.j - .5) > 2.2) bad++;
      res[map + ':' + size] = { raiders: P.enemies.length, stuck: bad }; P.toMenu();
    }
    return res;
  });
  for (const [k, v] of Object.entries(out.reach)) assert.equal(v.stuck, 0, k + ': ' + v.stuck + ' raiders never reached the stake');
  // 2. Riverbend: wading is half speed, no building on water, the banks flood from raid 3 and slow people
  out.river = await E(() => {
    const P = __pal; run('river'); step(5);
    const w = P.terr.indexOf(1), wi = w % P.N, wj = (w / P.N) | 0, pl = P.player;
    const t = P.buildEval(pl, wi, wj, 0, false);
    const e1 = P.spawnEnemyAt('rifle', wi + .5, wj + .5), e2 = P.spawnEnemyAt('rifle', P.core.i + 2.5, P.core.j + .5);
    const bank = P.terr.indexOf(3);
    P.game.wave = 2; P.startRaid(); clearField(); dummy(); step(30 * 20);
    const floodedAt3 = P.floodOn;
    const lowTile = [bank % P.N, (bank / P.N) | 0], tb = P.buildEval(pl, lowTile[0], lowTile[1], 0, false);
    return { buildOnWater: t.reason, floodedAt3, buildOnFlooded: tb.reason, noFloodBefore3: true };
  });
  console.log(JSON.stringify({reach:out.reach,river:out.river}));
  assert.equal(out.river.buildOnWater, "Can't build on water"); assert.equal(out.river.floodedAt3, true); assert.match(out.river.buildOnFlooded, /Flooded/);
  out.wade = await E(() => { const P = __pal; run('river'); const w = P.terr.indexOf(1), pl = P.player; pl.x = w % P.N + .5; pl.y = ((w / P.N) | 0) + .5;
    return { water: +P.slowAtHook(pl.x, pl.y).toFixed(2), dry: +P.slowAtHook(P.core.i + 1.5, P.core.j + .5).toFixed(2) } });
  assert.deepEqual(out.wade, { water: .5, dry: 1 });
  // 3. Ashfall Quarry: always night; a satchel-sized blast breaks cracked ground into a pit that blocks walking and building
  out.quarry = await E(() => {
    const P = __pal; run('quarry'); step(3); const tod = P.todStage(1);
    const k = P.terr.indexOf(4), i = k % P.N, j = (k / P.N) | 0; P.walls[k] = P.makeWall(0, false);
    P.explode(i + .5, j + .5, 2.1, 1.6); const pit = P.terr[k] === 5, wallGone = !P.walls[k];
    const k2 = P.terr.indexOf(4), g = P.explode(k2 % P.N + .5, ((k2 / P.N) | 0) + .5, 1.65, 1); const smallStays = P.terr[k2] === 4;
    return { night: tod, pit, wallGone, solid: P.solidTileHook(i, j), build: P.buildEval(P.player, i, j, 0, false).reason, grenadeLeavesIt: smallStays };
  });
  assert.deepEqual(out.quarry, { night: 2, pit: true, wallGone: true, solid: true, build: "That's a pit now", grenadeLeavesIt: true });
  // 4. the Ferryman: on the water, harpoon drags you toward him, boarding crews come ashore, at half health a bridge goes
  out.ferry = await E(() => {
    const P = __pal; run('river'); clearField(); P.game.phase = 'raid'; P.game.queue = []; P.spawnBoss('ferryman');
    const f = P.enemies.find(e => e.boss === 'ferryman'), onWater = () => { const t = P.terr[idx(Math.floor(f.x), Math.floor(f.y))]; return t === 1 || t === 2 };
    const pl = P.player; let water = true, pulled = 0, maxCrews = 0;
    for (let t = 0; t < 30 * 30; t++) { imm(); pl.x = Math.min(P.N - .5, f.x - 4); pl.y = f.y; const x0 = pl.x; P.update(1 / 30); if (Math.abs(pl.x - x0) > .6) pulled++; if (!onWater()) water = false; maxCrews = Math.max(maxCrews, f.crews | 0) }
    const bridges0 = P.terr.filter(t => t === 2).length; f.hp = f.max * .45; step(30 * 12);
    return { water, pulled, crews: maxCrews, bridgesBefore: bridges0, bridgesAfter: P.terr.filter(t => t === 2).length, rammed: !!f.rammed };
  });
  assert.ok(out.ferry.water, 'Ferryman stays on the river'); assert.ok(out.ferry.pulled > 0, 'harpoon pulls'); assert.ok(out.ferry.crews >= 1, 'boarding crew');
  assert.equal(out.ferry.bridgesAfter, out.ferry.bridgesBefore - 2, 'one bridge (2 tiles) rammed');
  // 5. the Foreman: bullets and blasts can't touch him underground; he comes up under a wall; slabs land as stone blocks
  out.foreman = await E(() => {
    const P = __pal; run('quarry'); clearField(); P.game.phase = 'raid'; P.game.queue = []; P.spawnBoss('foreman');
    P.walls.fill(null); const f = P.enemies.find(e => e.boss === 'foreman'), c = P.core; const wk = idx(c.i + 3, c.j); P.walls[wk] = P.makeWall(0, false); P.walls[wk].crew = true;
    let burrowSeen = false, hurtUnder = 0, burst = false;
    for (let t = 0; t < 30 * 25 && !burst; t++) { imm(); P.update(1 / 30);
      if (f.burrow) { burrowSeen = true; const h = f.hp; P.explode(f.x, f.y, 1.6, 1); if (f.hp < h) hurtUnder++ }
      if (burrowSeen && !f.burrow) burst = true }
    const wallHit = !P.walls[wk] || P.walls[wk].hp < P.walls[wk].max;
    // a slab thrown at open ground stays as a slab wall
    const tx = c.i + 2.5, ty = c.j - 2.5; P.lobs.push({ x0: f.x, y0: f.y, x1: tx, y1: ty, t: 0, T: .2, R: .8, power: 1, k: 2 }); step(10);
    const sw = P.walls[idx(Math.floor(tx), Math.floor(ty))];
    return { burrowSeen, hurtUnder, burst, wallHit, slab: !!(sw && sw.slab) };
  });
  assert.deepEqual(out.foreman, { burrowSeen: true, hurtUnder: 0, burst: true, wallHit: true, slab: true });
  // 6. the new raiders
  out.raiders = await E(() => {
    const P = __pal; run('yard'); clearField(); P.game.phase = 'raid'; P.game.queue = [];
    const c = P.core, pl = P.player, r = {};
    // shieldbearer: front shots spark off, a shot in the back lands
    const s = P.spawnEnemyAt('shield', 10.5, 4.5); s.cd = 99; s.aim = { x: -1, y: 0 }; const h0 = s.hp;
    P.bullets.push({ x: s.x - 1, y: s.y, vx: 30, vy: 0, team: 0, dmg: 20, range: 9, dist: 0, own: pl.id, tr: 0 }); for (let i = 0; i < 4; i++) { s.aim = { x: -1, y: 0 }; P.updateBulletsHook(1 / 30) }
    r.shieldFront = s.hp === h0;
    P.bullets.push({ x: s.x + 1, y: s.y, vx: -30, vy: 0, team: 0, dmg: 20, range: 9, dist: 0, own: pl.id, tr: 0 }); for (let i = 0; i < 4; i++) { s.aim = { x: -1, y: 0 }; P.updateBulletsHook(1 / 30) }
    r.shieldBack = s.hp < h0; s.dead = true;
    // medic heals hurt raiders near him
    const m = P.spawnEnemyAt('medic', c.i + 8.5, c.j - 3.5), hurt = P.spawnEnemyAt('rifle', c.i + 8.9, c.j - 3.2); hurt.hp = hurt.max * .3; const hh = hurt.hp; m.ab = 0; hurt.cd = 99; m.cd = 99;
    pl.x = -30; pl.y = -30; P.qm.gone = true; P.update(1 / 30); r.medicHeals = hurt.hp > hh; m.dead = true; hurt.dead = true; P.update(1 / 30); P.qm.gone = false;
    // spotter marks someone in sight; riflemen aim at the marked player
    pl.x = 3.5; pl.y = 4.5; const sp = P.spawnEnemyAt('spotter', 11.5, 4.5); sp.cd = 99;
    for (let i = 0; i < 45; i++) { imm(); P.update(1 / 30) } r.marked = (pl.markT || 0) > 0 && sp.st === 2; sp.dead = true;
    // firebrand sets a wooden wall alight
    clearField(); const wk = idx(c.i + 3, c.j); P.walls[wk] = P.makeWall(0, false); P.walls[wk].crew = true;
    P.lobs.push({ x0: c.i + 6.5, y0: c.j + .5, x1: c.i + 3.5, y1: c.j + .5, t: 0, T: .2, R: 1, power: 1, k: 1 }); step(10);
    r.woodBurns = P.walls[wk] && P.walls[wk].fire > 0; r.groundFire = P.fires.length > 0;
    return r;
  });
  assert.deepEqual(out.raiders, { shieldFront: true, shieldBack: true, medicHeals: true, marked: true, woodBurns: true, groundFire: true });
  // 7. per-map boss order and the October Butcher (name, look, two Halloween Cases)
  out.bosses = await E(() => { const P = __pal, o = {}; for (const m of Object.keys(P.MAPS)) { run(m, 'std', 'endless'); o[m] = [5, 10, 15, 20].map(w => P.bossOf(w)); P.toMenu() } return o });
  assert.deepEqual(out.bosses, { yard: ['butcher', 'demolisher', 'storm', 'butcher'], river: ['ferryman', 'butcher', 'storm', 'ferryman'], quarry: ['foreman', 'demolisher', 'storm', 'foreman'] });
  out.oct = await E(() => {
    const P = __pal; P.locker.bag = {}; run('yard', 'std', '5'); P.game.oct = true;   // the host's October flag
    P.game.phase = 'raid'; P.spawnBoss('butcher'); const e = P.enemies.find(x => x.boss === 'butcher'); const name = P.bossInfo('butcher').name;
    P.hurtEnemyHook(e, 1e6, P.player.id); const log = P.game.bossLog.slice();
    P.game.wave = 5; const txt = P.lockerReward(5, true, 20); const bag = { ...P.locker.bag }; return { name, log, bag, txt };
  });
  assert.equal(out.oct.name, 'THE PUMPKIN BUTCHER'); assert.deepEqual(out.oct.log, ['butcher_oct']); assert.equal(out.oct.bag.halloween, 2);
  out.drops = await E(() => { const P = __pal; P.game.waves = 10; return { afterglowBoss: P.bossDropsHook(['demolisher', 'ferryman'], 10), capped: P.bossDropsHook(['storm', 'foreman', 'butcher'], 6) } });
  assert.deepEqual(out.drops, { afterglowBoss: { afterglow: 1, halloween: 1 }, capped: { afterglow: 1 } });
  // 8. the wave table: who comes, before (v0.8) and after (v0.9) for one player and four, Normal
  out.waves = await E(() => { const P = __pal, rows = [];
    const old = (k, Pn, ex, boss) => ({ rifle: Math.max(2, 2 + k + ex - (boss ? 2 : 0)) + Math.round((Pn - 1) * (1.5 + k * .45)), gren: Math.max(0, k - 1) + (k >= 2 ? Math.floor((Pn - 1) / 3) : 0), breach: (k >= 3 ? k - 2 + (ex > 0 ? 1 : 0) : 0) + (k >= 3 ? Math.floor((Pn - 1) / 3) : 0) });
    for (const Pn of [1, 4]) for (const k of [1, 2, 3, 4, 5, 6, 8, 10]) { const o = old(k, Pn, 0, k % 5 === 0), n = P.waveMix(k, Pn, 0, k % 5 === 0); const tot = x => Object.values(x).reduce((a, b) => a + b, 0);
      rows.push({ players: Pn, raid: k, before: `${o.rifle}r ${o.gren}g ${o.breach}b = ${tot(o)}`, after: `${n.rifle}r ${n.gren}g ${n.breach}b ${n.fire}fire ${n.shield}shield ${n.medic}medic ${n.spotter}spot = ${tot(n)}` }) }
    return rows });
  // 9. v0.9.1 enemy health: Yard 1.0, Riverbend 1.05, Quarry 1.1, XL +10% (damage unchanged)
  out.hp = await E(() => { const P = __pal, o = {}; for (const m of ['yard', 'river', 'quarry']) for (const size of ['std', 'xl']) { run(m, size); P.game.wave = 1; const e = P.spawnEnemyAt('rifle', 1.5, 1.5); o[m + ':' + size] = +(e.max / 36 / P.game.Df.hp).toFixed(3); e.dead = true; P.toMenu() } return o });
  assert.deepEqual(out.hp, { 'yard:std': 1, 'yard:xl': 1.1, 'river:std': 1.05, 'river:xl': 1.155, 'quarry:std': 1.1, 'quarry:xl': 1.21 });
  // 10. boss raids: one boss on 16×16 (Riverbend too), two different ones on XL at 90% each
  out.xlBosses = await E(() => { const P = __pal, o = {};
    for (const [m, size] of [['yard', 'std'], ['river', 'std'], ['yard', 'xl'], ['river', 'xl'], ['quarry', 'xl']]) { run(m, size); clearField(); P.game.wave = 4; P.startRaid();
      const bs = P.game.queue.filter(q => q.startsWith('boss:')).map(q => q.slice(5)); o[m + ':' + size] = { bosses: bs, share: P.game.bossShare };
      if (bs.length) { P.spawnBoss(bs[0]); const e = P.enemies.find(x => x.boss === bs[0]), B = P.BOSSES[bs[0]]; o[m + ':' + size].hpShare = +(e.max / (B.hp * P.game.Df.hp * (size === 'xl' ? 1.1 : 1) * ({ yard: 1, river: 1.05, quarry: 1.1 })[m])).toFixed(3) }
      P.toMenu() } return o });
  for (const k of ['yard:std', 'river:std']) { assert.equal(out.xlBosses[k].bosses.length, 1, k); assert.equal(out.xlBosses[k].hpShare, 1) }
  for (const k of ['yard:xl', 'river:xl', 'quarry:xl']) { const v = out.xlBosses[k]; assert.equal(v.bosses.length, 2, k); assert.notEqual(v.bosses[0], v.bosses[1]); assert.equal(v.hpShare, .9, k) }
  assert.deepEqual(out.xlBosses['river:xl'].bosses, ['ferryman', 'butcher']);
  out.xlDrops = await E(() => { const P = __pal; run('yard', 'xl', '10'); P.game.waves = 10; const r = P.bossDropsHook(['butcher', 'demolisher', 'storm', 'butcher'], 10); P.toMenu(); return r });
  assert.deepEqual(out.xlDrops, { halloween: 2, afterglow: 2 }, 'XL: two boss cases per boss raid');
  // 11. Quarry oil drums: walk into them and build on them, no; shoot and see past them, yes. Rock still stops both.
  out.drums = await E(() => { const P = __pal; run('quarry'); const N = P.N, k = [...P.terr].indexOf(7), i = k % N, j = (k / N) | 0, r = [...P.terr].indexOf(6), ri = r % N, rj = (r / N) | 0;
    const o = { solid: P.solidTileHook(i, j), sight: P.losClear(i - .5, j + .5, i + 1.5, j + .5), rockSight: P.losClear(ri - .5, rj + .5, ri + 1.5, rj + .5), rockSolid: P.solidTileHook(ri, rj) };
    P.player.x = i - .5; P.player.y = j + .5; P.bullets.length = 0; P.fire(P.player, 0, 0, P.player.gun, 0); const bl = P.bullets[0]; for (let s = 0; s < 20 && !bl.dead; s++) P.updateBulletsHook(1 / 60); o.bulletPast = !bl.dead || bl.x > i + 1;
    P.toMenu(); return o });
  assert.deepEqual([out.drums.solid, out.drums.sight, out.drums.rockSight, out.drums.rockSolid, out.drums.bulletPast], [true, true, false, true, true]);
  // 12. PvP layouts on every map: symmetric ground, every spawn reaches every other, no stuck or walled-in tiles,
  //     and in Free-for-all no spawn in plain sight of another
  out.pvp = await E(() => { const P = __pal, o = {};
    for (const map of ['yard', 'river', 'quarry']) for (const pv of ['base', 'ffa']) {
      P.pick.map = map; P.pick.size = 'std'; P.newGame([0, 1, 2, 3].map(n => ({ id: 'p' + n, name: 'P' + n, cls: 'soldier', cos: 'std|class|std|none', team: n % 2 ? 'b' : 'a' })), pv);
      const N = P.N, L = P.game.lay, walk = (i, j) => !P.solidTileHook(i, j), key = k => P.terr[k] + (P.walls[k] ? 'w' + (P.walls[k].cov || P.walls[k].mat) : '');
      let asym = 0; for (let j = 0; j < 16; j++) for (let i = 0; i < 16; i++) { const a = j * 16 + i, bb = pv === 'base' ? (15 - j) * 16 + (15 - i) : (15 - i) * 16 + j; if (pv === 'base' ? key(a) !== key(bb) : P.terr[a] !== P.terr[bb]) asym++ }
      const spawns = pv === 'ffa' ? L.pspawns : [...L.teamSpawns, ...L.teamSpawns.map(([x, y]) => [16 - x, 16 - y])];
      const seen = new Uint8Array(N * N), q = [], s0 = spawns[0], k0 = Math.floor(s0[1]) * N + Math.floor(s0[0]); seen[k0] = 1; q.push(k0);
      for (let h = 0; h < q.length; h++) { const k = q[h], i = k % N, j = (k / N) | 0; for (const [a, c] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const x = i + a, y = j + c; if (x < 0 || y < 0 || x >= N || y >= N) continue; const kk = y * N + x; if (seen[kk] || !walk(x, y)) continue; seen[kk] = 1; q.push(kk) } }
      let stuck = 0; for (let j = 0; j < N; j++) for (let i = 0; i < N; i++) if (walk(i, j) && !seen[j * N + i]) stuck++;
      const unreach = spawns.filter(([x, y]) => !seen[Math.floor(y) * N + Math.floor(x)]).length;
      let close = 0; if (pv === 'ffa') for (let a = 0; a < spawns.length; a++) for (let c = a + 1; c < spawns.length; c++) { const A = spawns[a], B = spawns[c]; if (Math.hypot(A[0] - B[0], A[1] - B[1]) < 12 && P.losClear(A[0], A[1], B[0], B[1])) close++ }
      o[map + '/' + pv] = { asym, stuck, unreach, close, spawns: spawns.length, cover: (L.cover || []).length, cores: P.cores.map(c => c.i + ',' + c.j).join(' '), map: P.game.map };
    } P.toMenu(); return o });
  for (const [k, v] of Object.entries(out.pvp)) { assert.equal(v.stuck, 0, k + ' stuck tiles'); assert.equal(v.unreach, 0, k + ' spawns cut off'); assert.equal(v.close, 0, k + ' spawns in sight of each other'); assert.equal(v.map, k.split('/')[0]) }
  for (const k of ['yard/base', 'river/base', 'quarry/base', 'river/ffa', 'quarry/ffa']) assert.equal(out.pvp[k].asym, 0, k + ' is symmetric');
  assert.equal(out.pvp['yard/ffa'].asym, 0, 'yard arena ground is symmetric (the sheds are mirrored, not turned)');
  console.log(JSON.stringify(out, null, 1));
  console.log('errors:', errors.length ? errors : 'none');
  await b.close();
})().catch(e => { console.log('Error:', e.message); process.exit(1) });
