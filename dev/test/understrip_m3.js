// THE UNDERSTRIP M3: the whole descent. Regions 2 and 3 build from their own kits (Shelter 7, Area 67) with the right arena
// for each boss; their hazards hurt as written (radiation, acid, gas vents on a timer, Iron Lung halving them) and shots slow
// over low gravity; the music is muffled more in Shelter 7 (with a reverb tail) and cut in Area 67, with a raid track for each
// boss; the four merchants (the Tunnel Trader's weapons, the Shrine Keeper's and the Lift Merchant's upgrades, the Collector
// in one level of each region, guarded, the only one with gold); per-player gear; Area 67's alarms and drones (double damage
// in light); the Custodian, the Gatekeeper and the Visitor through both stages (and the Visitor's desperate one), their
// signature drops; and a solo run from the first level to OUT OF AREA 67, a life gained for each region.
const { chromium } = require('playwright'), assert = require('node:assert/strict');
(async () => {
 const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), errors = [];
 const p = await b.newPage({ viewport: { width: 1280, height: 800 } }); p.on('pageerror', e => errors.push(e.message));
 await p.goto(`http://localhost:${process.env.PORT || 8080}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal);
 const r = await p.evaluate(async () => {
  let s = 11; Math.random = () => (s = (s * 16807) % 2147483647) / 2147483647; const P = __pal; P.pick.mode = 'understrip'; P.showPage('solo'); document.getElementById('startBtn').click(); await new Promise(z => setTimeout(z, 500));
  const g = () => P.game, U = () => P.game.us, L = () => P.game.lay, r = {};let pl = P.player; g().paused = true;
  const step = (sec, each) => { for (let t = 0; t < sec; t += 1 / 30) { if (each) each(); g().paused = false; P.update(1 / 30); g().paused = true; if (g().phase === 'over') break } };
  const clear = () => { for (const e of P.enemies) e.dead = true; step(.05) };
  const tp = (x, y) => { pl.x = x; pl.y = y; pl.tp++ };
  const tileOf = h => { const H = P.US_HAZ; for (let k = 0; k < H.length; k++) if (H[k] === h) { const x = k % P.N, y = (k / P.N) | 0; if (![12, 13, 14, 15].includes(P.terr[k])) return [x + .5, y + .5] } return null };
  const solid = (x, y) => [12, 13, 14, 15].includes(P.terr[(y | 0) * P.N + (x | 0)]);
  // 1. the plan and the kits
  r.plan = P.US_PLAN.map(q => q.join(':'));
  r.levels = [];
  for (let lv = 0; lv < 10; lv++) { P.usChangeLevel(lv); const A = L().arena; r.levels.push([lv, P.US_PLAN[lv][0], L().us.rooms[0].id.slice(0, 2), A ? A.id || L().us.rooms.find(q => q.role === 'boss_arena').id : '', P.MAPS.understrip.name, L().merchants.map(m => m.kind).sort().join(',')]) }
  // the Collector: exactly one level of each region's first three
  r.collector = [1, 2, 3].map(reg => P.US_PLAN.map((q, lv) => [q, lv]).filter(([q, lv]) => q[0] === reg && lv < P.US_PLAN.findIndex(o => o[0] === reg) + 3).filter(([q, lv]) => { P.usChangeLevel(lv); return L().merchants.some(m => m.kind === 'collector') }).length);
  // 2. Shelter 7's hazards: radiation 3 HP/s, Iron Lung halves it; a vent's cloud 10 HP/s; the music
  P.usChangeLevel(3); clear(); pl.max = pl.hp = 1000;
  { const t = tileOf(1); r.radTile = !!t; if (t) { tp(t[0], t[1]); pl.hp = 1000; step(2); r.rad = Math.round(1000 - pl.hp); pl.uPerks = ['p_lung']; P.usRefit(pl); pl.max = pl.hp = 1000; step(2); r.radLung = Math.round(1000 - pl.hp); pl.uPerks = []; P.usRefit(pl); pl.max = pl.hp = 1000 } }
  r.route2 = JSON.stringify(P.usMusicRoute()); r.music2 = P.US_REG[2].music;
  // a vent: find a level with one; quiet, a warning, the cloud, quiet again
  const seed0 = P.US_RUN.seed; for (let sd = 1; sd < 60 && !L().vents.length; sd++) { P.US_RUN.seed = seed0 + sd; P.usChangeLevel(3 + (sd & 1)) }
  if (L().vents.length) { clear(); const v = L().vents[0], V = U().vents[0]; V.s = 0; V.t = .1; const seen = []; step(.2); seen.push(V.s); step(2.1); seen.push(V.s);
    const k = [...v.cloud].find(k => ![12, 13, 14, 15].includes(P.terr[k])); tp(k % P.N + .5, ((k / P.N) | 0) + .5); pl.max = pl.hp = 1000; step(2); r.gas = Math.round(1000 - pl.hp) - (P.US_HAZ[k] === 1 ? 6 : 0); step(6); seen.push(V.s); r.vent = seen } else r.vent = 'none'; P.US_RUN.seed = seed0;
  // 3. Area 67: acid 6 HP/s, low gravity slows a shot to 60%, the alarm and the drones, the music cut
  P.usChangeLevel(6); clear(); pl.max = pl.hp = 1000; r.route3 = P.usMusicRoute();
  { const t = tileOf(2); if (t) { tp(t[0], t[1]); step(2); r.acid = Math.round(1000 - pl.hp) } else r.acid = 'none'; pl.max = pl.hp = 1000 }
  { const t = tileOf(3); r.grav = t ? +P.usGravAt(t[0], t[1]).toFixed(2) : 'none'; const b1 = { x: t[0], y: t[1], vx: 10, vy: 0, dist: 0, range: 99, team: 1, dmg: 0 }; P.bullets.length = 0; P.bullets.push(b1); P.updateBullets(.05); r.gravShot = +(b1.dist / .5).toFixed(2); P.bullets.length = 0 }
  { P.usChangeLevel(6); clear(); const q = L().us.rooms.find(o => o.role === 'room'), e = P.spawnEnemyAt('rifle', q.x + q.w / 2, q.y + q.h / 2); e.us = { home: [e.x, e.y], st: 'idle', sid: 99, t: 0, look: 0 };
    tp(L().starts[0][0], L().starts[0][1]); P.usAlarm(e); r.alarm = U().alarms.length; step(3.3); const dr = P.enemies.filter(o => o.type === 'drone' && !o.dead); r.drones = dr.length;
    // in your light, twice the damage
    const d = dr[0]; if (d) { d.speed = 0; tp(d.x - 2, d.y); pl.aim = { x: 1, y: 0 }; d.hp = 10; P.hurtEnemy(d, 3, pl.id); r.droneLit = +(10 - d.hp).toFixed(1); const d2 = dr[1]; if (d2) { d2.speed = 0; d2.x = pl.x - 6; d2.y = pl.y - 6; d2.hp = 10; r.dark2 = P.usLitAt(d2.x, d2.y); if (!r.dark2) { P.hurtEnemy(d2, 3, pl.id); r.droneDark = +(10 - d2.hp).toFixed(1) } } } }
  // 4. the merchants: the Lift Merchant on every level after the first, the Keeper by the breather; upgrades only from them
  P.usChangeLevel(4); clear(); pl.sal = 2000;
  { const ms = L().merchants, tr = ms.findIndex(m => m.kind === 'trader'), lf = ms.findIndex(m => m.kind === 'lift'), kp = ms.findIndex(m => m.kind === 'keeper');
    r.merch = [tr, lf, kp].map(i => i >= 0);
    tp(ms[tr].x, ms[tr].y + 1); r.upAtTrader = P.buyUpgrade(pl, 'd'); r.traderGear = ms[tr].stock.filter(s => s.gear).map(s => s.gear.w.r);
    const gi = ms[tr].stock.findIndex(s => s.gear); const sal0 = pl.sal; r.buyGear = P.usBuy(pl, tr, gi) && pl.w2 && pl.w2.id === ms[tr].stock[gi].gear.w.id && sal0 - pl.sal === ms[tr].stock[gi].price; r.buyAgain = P.usBuy(pl, tr, gi);
    tp(ms[kp].x, ms[kp].y + 1); r.upAtKeeper = P.buyUpgrade(pl, 'd');
    tp(ms[lf].x, ms[lf].y + 1); r.upAtLift = P.buyUpgrade(pl, 'd') }
  // the Collector's stock: epic and up, perks and a relic; and his guards
  for (let lv = 0; lv < 9; lv++) { P.usChangeLevel(lv); const m = L().merchants.find(q => q.kind === 'collector'); if (!m) continue; r.collStock = m.stock.map(s => s.gear.kind + (s.gear.w ? ':' + s.gear.w.r : '')); r.guards = L().raiders.filter(q => q.id >= 8000).map(q => q.type + (q.elite ? '*' : '')); break }
  // gold anywhere but the Collector? (every trader's and lift's weapon, every level)
  r.goldElsewhere = 0; for (let lv = 0; lv < 10; lv++) { P.usChangeLevel(lv); for (const m of L().merchants) if (m.kind !== 'collector') for (const s of m.stock) if (s.gear && s.gear.w && s.gear.w.r === 'g') r.goldElsewhere++ }
  // 5. the bosses
  pl.max = pl.hp = 1e7; r.boss = {};
  for (const lv of [5, 8, 9]) {
   P.usChangeLevel(lv); clear(); const A = L().arena; tp(A.x + A.w / 2, A.y + A.h - 3); step(5.5);
   const B = P.enemies.find(e => e.type === 'boss'), o = r.boss[P.US_PLAN[lv][2]] = { boss: B && B.boss, hp: B && Math.round(B.max), sealed: U().gate === 2, track: P.usMusicRoute().k, s1: new Set(), s2: new Set(), fx1: new Set(), fx2: new Set(), doors: new Set() };
   const watch = () => { pl.hp = pl.max; const st = U().bossStage; for (const e of P.enemies) if (e.type === 'boss' && e.st) (st ? o.s2 : o.s1).add(e.st); for (const f of U().bfx || []) (st ? o.fx2 : o.fx1).add(f.k); for (const d of U().blast || []) o.doors.add(d);
     if (Math.random() < .04) { const a = Math.random() * 6.28, d = 1.2 + Math.random() * 5, x = B.x + Math.cos(a) * d, y = B.y + Math.sin(a) * d; if (!solid(x, y) && x > A.x + 1 && x < A.x + A.w - 1 && y > A.y + 1 && y < A.y + A.h - 1) tp(x, y) } };
   step(25, watch); P.hurtEnemy(B, B.hp - B.max * .49, pl.id); step(.1); o.stage2 = U().bossStage === 1; const hp2 = B.hp; P.hurtEnemy(B, 300, pl.id); o.inv = B.hp === hp2; o.bar = +P.usBossFrac(B).toFixed(2);
   o.dark = lv === 5 ? P.usDarkTint().r : lv === 9 ? P.usDarkTint().L - P.usDarkL() : 0; step(3.3); step(30, watch);
   if (lv === 9) { P.hurtEnemy(B, B.hp - B.max * .09, pl.id); step(.2); o.desperate = U().bossStage === 2; o.droneN = P.enemies.filter(e => e.type === 'drone').length; step(6, watch) }
   if (lv === 8) { const pi = P.enemies.find(e => e.pilot && !e.dead); o.pilot = pi ? Math.round(pi.max / B.max * 100) : 0; if (pi) P.hurtEnemy(pi, 1e9, pl.id) } else { B.inv = 0; P.hurtEnemy(B, 1e9, pl.id) }
   step(.5); o.down = !!U().bossDown && U().gate === 0 && P.enemies.every(e => e.type !== 'boss' || e.dead); o.sig = U().loot.filter(l => !l.for).map(l => l.kind + ':' + (l.k || l.w.id + ':' + l.w.r)); o.drops = U().loot.filter(l => l.for).length;
   o.doorsOpen = (U().blast || []).every(d => d === 0);
   for (const k of ['s1', 's2', 'fx1', 'fx2', 'doors']) o[k] = [...o[k]].sort() }
  // 6. a whole solo run, start to finish: through each level by the lift, every boss beaten, a life for each region
  P.US_RUN.level = 0; P.newGame(null, '', {}); await new Promise(z => setTimeout(z, 100)); g().paused = true; pl = P.player; pl.max = pl.hp = 1e7; const lives0 = U().lives, path = [];
  for (let n = 0; n < 12 && g().phase !== 'over'; n++) {
   clear(); const lv = U().level; path.push(lv);
   if (P.US_PLAN[lv][1] === 'boss') { const A = L().arena; tp(A.x + A.w / 2, A.y + A.h - 3); step(5.5); for (let k = 0; k < 8 && !U().bossDown; k++) { for (const e of P.enemies) if (e.type === 'boss' && !e.dead) { e.inv = 0; P.hurtEnemy(e, e.max * .3, pl.id) } step(3.5, () => { pl.hp = pl.max }) } }
   clear(); tp(L().exit[0], L().exit[1]); step(3.4); if (g().phase !== 'over') step(5.4) }
  r.run = { path, phase: g().phase, won: g().won, title: document.getElementById('overTitle').textContent, lives: U().lives - lives0, regions: U().regions };
  P.render(1 / 60); return JSON.parse(JSON.stringify(r, (k, v) => v instanceof Set ? [...v] : v)) });
 console.log(JSON.stringify(r, null, 1));
 assert.equal(r.plan.join(' '), '1:normal: 1:normal: 1:boss:pitboss 2:normal: 2:normal: 2:boss:custodian 3:normal: 3:normal: 3:boss:gatekeeper 3:boss:visitor');
 const arenas = { 2: 'r1_boss_pitboss', 5: 'r2_boss_custodian', 8: 'r3_boss_gatekeeper', 9: 'r3_boss_visitor' }, names = { 1: 'THE FLOOD TUNNELS', 2: 'SHELTER 7', 3: 'AREA 67' };
 for (const [lv, reg, kit, arena, name, merch] of r.levels) { assert.equal(kit, 'r' + reg, 'level ' + lv + ' kit'); assert.equal(name, names[reg]); if (arenas[lv]) assert.equal(arena, arenas[lv], 'level ' + lv + ' arena'); else assert.equal(arena, '');
  assert.ok(merch.includes('trader') && merch.includes('keeper'), 'level ' + lv + ': ' + merch); assert.equal(merch.includes('lift'), lv > 0, 'the Lift Merchant from the second level on') }
 assert.deepEqual(r.collector, [1, 1, 1], 'the Collector: one level in each region');
 assert.ok(r.radTile); assert.ok(Math.abs(r.rad - 6) <= 1, 'radiation 3 HP/s: ' + r.rad); assert.ok(Math.abs(r.radLung - 3) <= 1, 'Iron Lung halves it: ' + r.radLung);
 assert.match(r.route2, /casino/); assert.deepEqual(r.music2, { lp: 420, wet: .55 });
 assert.notEqual(r.vent, 'none', 'a level with a gas vent'); { assert.deepEqual(r.vent, [1, 2, 0], 'a vent warns, leaks, goes quiet'); assert.ok(Math.abs(r.gas - 20) <= 3, 'gas 10 HP/s: ' + r.gas) }
 assert.equal(r.route3, null, 'the music cuts out in Area 67');
 if (r.acid !== 'none') assert.ok(Math.abs(r.acid - 12) <= 2, 'acid 6 HP/s: ' + r.acid);
 assert.equal(r.grav, .6); assert.equal(r.gravShot, .6, 'a shot over low gravity goes 60% as far');
 assert.equal(r.alarm, 1); assert.ok(r.drones >= 3, 'the alarm brings a drone pack'); assert.equal(r.droneLit, 6, 'double damage in your light'); if (r.dark2 === false) assert.equal(r.droneDark, 3);
 assert.deepEqual(r.merch, [true, true, true]); assert.equal(r.upAtTrader, false, 'the Tunnel Trader sells no upgrades'); assert.ok(r.upAtKeeper && r.upAtLift, 'the Shrine Keeper and the Lift Merchant do');
 assert.ok(r.traderGear.length >= 1 && r.traderGear.every(x => x === 'c' || x === 'r'), 'the trader: common and rare weapons'); assert.ok(r.buyGear); assert.equal(r.buyAgain, false, 'one each');
 assert.ok(r.collStock.filter(x => x.startsWith('weapon')).every(x => ['e', 'l', 'g'].includes(x.split(':')[1])) && r.collStock.some(x => x === 'relic') && r.collStock.some(x => x === 'perk'), 'the Collector: epic and up, perks, a relic');
 assert.deepEqual(r.guards, ['shield*', 'rifle'], 'the Collector is guarded'); assert.equal(r.goldElsewhere, 0, 'gold only from the Collector');
 const B = r.boss;
 assert.equal(Math.round(B.custodian.hp), 4445); assert.equal(Math.round(B.gatekeeper.hp), 6666); assert.equal(Math.round(B.visitor.hp), 10000, 'v0.12.4: each boss 50% more than the last, the finale 10,000 solo on Normal');
 for (const k of ['custodian', 'gatekeeper', 'visitor']) { const o = B[k]; assert.equal(o.boss, k); assert.ok(o.sealed, k + ' gate'); assert.ok(o.stage2 && o.inv, k + ' stage 2, 3 s untouchable'); assert.equal(o.bar, 1, k + ' stage 2 has its own bar'); assert.ok(o.down, k + ' down'); assert.equal(o.drops, 1, k + ' one drop each') }
 assert.deepEqual([B.custodian.track, B.gatekeeper.track, B.visitor.track], ['attitude', 'cool', 'finale']);
 assert.ok(B.custodian.s1.includes(63) && B.custodian.fx1.includes('water'), 'the mop arc and its water'); assert.deepEqual(B.custodian.doors, [0, 1, 2], 'the doors open, warn, shut');
 assert.ok(['gas', 'turret'].every(k => B.custodian.fx2.includes(k)), 'stage 2: gas and the turret'); assert.equal(B.custodian.dark, 40, 'red emergency light'); assert.ok(B.custodian.doorsOpen);
 assert.deepEqual(B.custodian.sig, ['weapon:w_flare:e']);
 assert.ok(B.gatekeeper.s1.includes(76) && B.gatekeeper.s1.includes(71), 'shield wall and stomp'); assert.ok(B.gatekeeper.s2.includes(74), 'the pilot\'s sidearm'); assert.equal(B.gatekeeper.pilot, 20, 'the pilot: 20% more');
 assert.deepEqual(B.gatekeeper.sig, ['weapon:w_antigrav:l']);
 assert.ok(['ring', 'acid'].every(k => B.visitor.fx1.includes(k)), 'stage 1: the pulse and the tank'); assert.ok(['blink', 'well'].every(k => B.visitor.fx2.includes(k)), 'stage 2: blink and the well');
 assert.ok(B.visitor.dark > 0, 'the lights go out'); assert.ok(B.visitor.desperate); assert.deepEqual(B.visitor.sig, ['relic:x_eye']);
 assert.deepEqual(r.run.path, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]); assert.equal(r.run.phase, 'over'); assert.equal(r.run.won, true); assert.match(r.run.title, /OUT OF AREA 67/);
 assert.equal(r.run.lives, 3, '+1 life for each of the three regions'); assert.equal(r.run.regions, 3);
 console.log('errors:', errors.length ? errors : 'none'); await b.close(); if (errors.length) process.exit(1);
})();
