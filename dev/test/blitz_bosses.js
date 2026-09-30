// v0.9.4.0 Blitzkrieg bosses, one check each: the Harbinger's missiles land on their rings (step away and they miss),
// the Blue Butcher's arc breaks brick and hits whoever is behind it (its dust gone in about half a second), napalm burns
// 10 s and eats metal where regular fire doesn't, the Tempest's twin shot hurts double when both land, and the
// Bulldozer never digs and is dazed about 3 s after hitting a wall. node blitz_bosses.js
const { chromium } = require('playwright'), assert = require('node:assert/strict'), fs = require('node:fs');
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), errors = [], out = {};
  const p = await b.newPage({ viewport: { width: 1100, height: 760 } }); p.on('pageerror', e => errors.push(e.message));
  await p.goto(`http://localhost:${process.env.PORT || 8080}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal);
  const setup = (map = 'yard') => p.evaluate(mp => { const P = __pal; P.demo = false; P.pick.mode = 'blitz'; P.pick.map = mp; P.pick.size = 'std'; P.pick.diff = 'normal'; P.newGame(null, '', {}); P.enterGameHook();
    const g = P.game; g.phase = 'raid'; g.wave = 5; g.queue = []; P.qm.alive = false; P.qm.gone = true; P.qm.x = P.qm.y = -9; for (let k = 0; k < P.walls.length; k++) P.walls[k] = null }, map);
  // --- the Harbinger (Riverbend, on his raft): three missiles, rings shown in flight; the one who moves takes nothing
  await setup('river');
  out.harbinger = await p.evaluate(() => { const P = __pal, me = P.player; P.spawnBoss('harbinger'); const e = P.enemies.find(x => x.boss === 'harbinger'); e.hp = e.max = 1e9;
    const r = { raft: !!e.raft }; me.x = e.x - 5; me.y = Math.min(P.N - 2, e.y + 4); e.foe = me; e.cd = 0; e.st = 0; me.max = me.hp = 1000;
    for (let i = 0; i < 60 && !P.lobs.some(l => l.k === 3); i++) { e.foe = me; P.update(1 / 30); me.hp = 1000 }
    const L = P.lobs.filter(l => l.k === 3); r.n = L.length; r.flight = +Math.max(...L.map(l => l.T)).toFixed(2);
    r.onMarker = L.every(l => Math.hypot(l.x1 - me.x, l.y1 - me.y) < 2.2);
    me.x = me.x + 4.5; me.y = me.y; const hp = me.hp; for (let i = 0; i < 90; i++) { P.update(1 / 30); e.st = e.st === 1 ? 0 : e.st; e.cd = 9 }
    r.dodged = me.hp === hp; r.landed = P.lobs.filter(l => l.k === 3).length === 0; return r });
  assert.ok(out.harbinger.raft); assert.equal(out.harbinger.n, 3); assert.ok(out.harbinger.flight >= 1.45); assert.ok(out.harbinger.onMarker);
  assert.ok(out.harbinger.dodged, 'stepping off the rings: no damage'); assert.ok(out.harbinger.landed);
  // standing still under one: it hurts
  out.harbingerHit = await p.evaluate(() => { const P = __pal, me = P.player; me.max = me.hp = 1000; P.lobs.push({ x0: me.x - 3, y0: me.y, x1: me.x, y1: me.y, t: 0, T: 1.5, R: 1.35, power: 1.1, k: 3 });
    for (let i = 0; i < 50; i++) P.update(1 / 30); return 1000 - me.hp });
  assert.ok(out.harbingerHit > 20, 'a direct hit hurts: ' + out.harbingerHit);
  // the Harbinger on a map without a river: fixed at the edge, no raft
  await setup('yard');
  out.harbingerDry = await p.evaluate(() => { const P = __pal; P.spawnBoss('harbinger'); const e = P.enemies.find(x => x.boss === 'harbinger'); const x0 = e.x, y0 = e.y; for (let i = 0; i < 60; i++) P.update(1 / 30); return { raft: e.raft, moved: Math.hypot(e.x - x0, e.y - y0) > .05 } });
  assert.deepEqual(out.harbingerDry, { raft: false, moved: false });
  // --- the Blue Butcher's arc: two brick walls in a row broken, the player behind hit, dust gone in about 0.5 s
  await setup('yard');
  out.arc = await p.evaluate(() => { const P = __pal, me = P.player, N = P.N, y = 7;
    P.spawnBoss('bluebutcher'); const e = P.enemies.find(x => x.boss === 'bluebutcher'); e.x = 2.5; e.y = y + .5; e.hp = e.max = 1e9;
    const brick = i => { P.walls[y * N + i] = P.makeWallHook(1, false) }; brick(5); brick(7); P.walls[y * N + 11] = P.makeWallHook(2, false);
    me.x = 9.5; me.y = y + .5; me.max = me.hp = 1000; const hp = me.hp;
    e.lx = 12.5; e.ly = y + .5; P.launchArc(e, P.game.Df); let dustMax = 0;
    for (let i = 0; i < 40; i++) { P.updateArcs(1 / 30); for (const q of P.parts) if (q.kind === 'tealdust') dustMax = Math.max(dustMax, q.max) }
    const metal = P.walls[y * N + 11]; return { w5: !!P.walls[y * N + 5], w7: !!P.walls[y * N + 7], hit: hp - me.hp, metal: metal ? +(metal.hp / metal.max).toFixed(2) : 0, arcs: P.arcs.length, dust: +dustMax.toFixed(2) } });
  assert.equal(out.arc.w5, false); assert.equal(out.arc.w7, false); assert.ok(out.arc.hit >= 25, 'hit through the walls: ' + out.arc.hit);
  assert.ok(out.arc.metal > 0 && out.arc.metal < 1, 'metal takes a heavy hit and stops it'); assert.equal(out.arc.arcs, 0); assert.ok(out.arc.dust <= .55, 'dust fades in about 0.5 s');
  // --- napalm: 10 s, 2x regular fire's burn on metal (regular fire leaves metal alone)
  await setup('yard');
  out.napalm = await p.evaluate(() => { const P = __pal, N = P.N, g = P.game; P.player.x = P.player.y = 1.5;
    const k1 = 5 * N + 5, k2 = 5 * N + 10; P.walls[k1] = P.makeWallHook(2, false); P.walls[k2] = P.makeWallHook(2, false);
    P.napalmLand({ x1: 5.5, y1: 5.5 }); P.fires2.push({ x: 10.5, y: 5.5, t: 10, max: 10, tick: .3, r: 1 });   // napalm on one metal wall, regular fire on the other
    const T = P.fires2.find(f => f.nap).t; let life = 0; for (let i = 0; i < 30 * 12; i++) { P.update(1 / 30); if (P.fires2.some(f => f.nap)) life += 1 / 30 }
    const a = P.walls[k1], b = P.walls[k2]; return { T, life: +life.toFixed(1), napalmMetal: a ? Math.round(a.max - a.hp) : 999, fireMetal: b ? Math.round(b.max - b.hp) : 999 } });
  assert.equal(out.napalm.T, 10); assert.ok(Math.abs(out.napalm.life - 10) < .2); assert.ok(out.napalm.napalmMetal >= 150, 'napalm burns metal: ' + out.napalm.napalmMetal);
  assert.equal(out.napalm.fireMetal, 0, 'regular fire leaves metal alone');
  // --- the Tempest: both beams on you = double; one beam = single (the Stormcaller's shot, exactly)
  await setup('yard');
  out.tempest = await p.evaluate(() => { const P = __pal, me = P.player; P.spawnBoss('tempest'); const e = P.enemies.find(x => x.boss === 'tempest'); e.x = 3.5; e.y = 8.5;
    const shot = off => { me.max = me.hp = 1000; me.x = 9.5; me.y = 8.5 + off; e.lx = 9.5; e.ly = 8.5; P.twinBolt(e, P.game.Df); return Math.round(1000 - me.hp) };
    return { both: shot(0), one: shot(.55) } });
  assert.equal(out.tempest.both, 2 * out.tempest.one, JSON.stringify(out.tempest)); assert.ok(out.tempest.one >= 30);
  // --- the Bulldozer: never underground; charges; a wall stops him, breaks, and he's dazed about 3 s
  await setup('yard');
  out.bull = await p.evaluate(() => { const P = __pal, me = P.player, N = P.N; P.spawnBoss('bulldozer'); const e = P.enemies.find(x => x.boss === 'bulldozer'); e.hp = e.max = 1e9;
    e.x = 3.5; e.y = 8.5; me.x = 10.5; me.y = 8.5; me.max = me.hp = 1e9; const k = 8 * N + 7; P.walls[k] = P.makeWallHook(1, false); e.cd = 0; e.ab = 0;
    let burrowed = false, dazeStart = -1, dazeEnd = -1, t = 0;
    for (let i = 0; i < 30 * 10; i++) { e.foe = me; P.update(1 / 30); t += 1 / 30; if (e.burrow) burrowed = true; if (e.st === 6 && dazeStart < 0) dazeStart = t; if (dazeStart >= 0 && dazeEnd < 0 && e.st !== 6) dazeEnd = t }
    return { burrowed, dazed: +(dazeEnd - dazeStart).toFixed(1), wall: !!P.walls[k] } });
  assert.equal(out.bull.burrowed, false); assert.ok(Math.abs(out.bull.dazed - 3) < .15, 'dazed about 3 s: ' + out.bull.dazed); assert.equal(out.bull.wall, false, 'the brick wall breaks');
  // --- their cases: two Blitzkrieg Cases each, and they count for their base boss
  out.cases = await p.evaluate(() => { const P = __pal; return ['harbinger', 'bluebutcher', 'arsonist', 'tempest', 'bulldozer'].map(k => [k, P.BOSSES ? P.BOSSES[k].cases : 0, P.bossBase(k)]) });
  fs.writeFileSync(__dirname + '/out/blitz_bosses.json', JSON.stringify({ out, errors }, null, 2)); assert.deepEqual(errors, []);
  console.log(JSON.stringify(out)); console.log('errors: none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
