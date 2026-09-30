// v0.9.4.0 Blitzkrieg Rush: 15 raids with Blitzkrieg bosses on 5 and 10, then the Final Blitz (5:00, a boss every 30 s,
// at most 4 alive), the evacuation in the last minute (a 3-tile ring, 3 s on your feet), per-player results, and the
// menu, labels and game-over text. node blitz_mode.js
const { chromium } = require('playwright'), assert = require('node:assert/strict'), fs = require('node:fs');
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), errors = [], out = {};
  const p = await b.newPage({ viewport: { width: 1100, height: 760 } }); p.on('pageerror', e => errors.push(e.message));
  await p.goto(`http://localhost:${process.env.PORT || 8080}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal);
  const game = (mods = [], map = 'yard', size = 'std') => p.evaluate(([m, mp, sz]) => { const P = __pal; P.demo = false; P.pick.mode = 'blitz'; P.pick.map = mp; P.pick.size = sz; P.newGame(null, '', { mods: m }); P.enterGameHook() }, [mods, map, size]);
  // setup: 15 raids, Blitzkrieg bosses on raids 5 and 10 (the map's order), none on 15
  await game();
  out.setup = await p.evaluate(() => { const P = __pal; return { mode: P.game.mode, waves: P.game.waves, b5: P.bossOf(5), b10: P.bossOf(10), b15: P.bossOf(15), b3: P.bossOf(3) } });
  assert.deepEqual(out.setup, { mode: 'blitz', waves: 15, b5: 'bluebutcher', b10: 'arsonist', b15: '', b3: '' });
  // the Final Blitz: boss cadence and the cap of 4 (nobody gets hurt, bosses never die)
  out.fb = await p.evaluate(() => { const P = __pal, g = P.game; for (const q of P.players.values()) { q.max = q.hp = 1e9 } P.core.max = P.core.hp = 1e9; P.qm.max = P.qm.hp = 1e9;
    g.wave = 14; g.phase = 'build'; P.startRaid(); const r = { phase: g.phase, t0: g.fb && g.fb.t, times: [], maxLive: 0, evacAt: null };
    let el = 0, last = 0; for (let i = 0; i < 30 * 200; i++) { P.update(1 / 30); el += 1 / 30; for (const e of P.enemies) if (e.type === 'boss') e.hp = e.max;
      const n = g.fb.n; if (n > last) { for (let k = last; k < n; k++) r.times.push(Math.round(el)); last = n } r.maxLive = Math.max(r.maxLive, P.liveBosses());
      if (g.fb.evac && r.evacAt === null) r.evacAt = +g.fb.t.toFixed(1) }
    r.n = g.fb.n; r.live = P.liveBosses(); r.keys = P.enemies.filter(e => e.type === 'boss').map(e => e.boss); return r });
  assert.equal(out.fb.phase, 'raid'); assert.equal(out.fb.t0, 300); assert.equal(out.fb.maxLive, 4, 'never more than 4 alive');
  assert.deepEqual(out.fb.times.slice(0, 4), [0, 30, 60, 90], 'first four arrive on the 30 s beat');
  assert.equal(out.fb.n, 4, 'the rest wait while 4 are alive'); assert.equal(out.fb.evacAt, null, 'no evac before 1:00');
  // kill them as they come: 10 bosses over the 5 minutes (the last at 4:30), evac opens at 1:00 left
  await game();
  out.fb2 = await p.evaluate(() => { const P = __pal, g = P.game; for (const q of P.players.values()) { q.max = q.hp = 1e9 } P.core.max = P.core.hp = 1e9; P.qm.max = P.qm.hp = 1e9;
    g.wave = 14; g.phase = 'build'; P.startRaid(); const r = { times: [], evacAt: null, ring: 0, order: [] }; let el = 0, last = 0;
    for (let i = 0; i < 30 * 280 && g.phase === "raid"; i++) { P.update(1 / 30); el += 1 / 30;
      for (const e of P.enemies) if (e.type === 'boss' && !e.dead) { r.order.push(e.boss); P.hurtEnemyHook(e, 1e9, P.player.id) }
      if (g.fb.n > last) { r.times.push(Math.round(el)); last = g.fb.n } if (g.fb.evac && r.evacAt === null) { r.evacAt = Math.round(g.fb.t); r.ring = g.fb.evac.r } }
    r.n = g.fb.n; r.fbLog = g.fbLog.slice(); r.bossLog = g.bossLog.length; return r });
  assert.equal(out.fb2.n, 10); assert.deepEqual(out.fb2.times, [0, 30, 60, 90, 120, 150, 180, 210, 240, 270], 'a boss every 30 s');
  assert.equal(out.fb2.evacAt, 60); assert.equal(out.fb2.ring, 1.5, '3 tiles across');
  assert.deepEqual(out.fb2.fbLog.slice(0, 5), ['bluebutcher', 'arsonist', 'tempest', 'harbinger', 'bulldozer']); assert.equal(out.fb2.bossLog, 0, 'Final Blitz bosses keep their own list');
  // the evacuation: 3 s standing in the ring extracts; leaving resets; downed doesn't count and doesn't respawn
  out.evac = await p.evaluate(() => { const P = __pal, g = P.game, me = P.player, E = g.fb.evac, r = {};
    me.x = E.x + 3; me.y = E.y; for (let i = 0; i < 30; i++) P.update(1 / 30); r.outside = me.ev || 0;
    me.x = E.x; me.y = E.y; for (let i = 0; i < 60; i++) P.update(1 / 30); r.twoSec = +(me.ev || 0).toFixed(1); r.outAt2 = !!me.out;
    me.x = E.x + 3; P.update(1 / 30); r.reset = me.ev || 0;
    me.x = E.x; me.y = E.y; for (let i = 0; i < 95; i++) P.update(1 / 30); r.out = !!me.out; r.alive = me.alive; r.res = P.blitzResult(me);
    const hp = me.hp; P.hurtEnemyHook; r.phase = g.phase; r.won = g.won; return r });
  assert.equal(out.evac.outside, 0); assert.equal(out.evac.twoSec, 2); assert.equal(out.evac.outAt2, false); assert.equal(out.evac.reset, 0);
  assert.equal(out.evac.out, true); assert.equal(out.evac.alive, false); assert.equal(out.evac.res, 'evac');
  assert.equal(out.evac.phase, 'over', 'solo: everyone out ends it early'); assert.equal(out.evac.won, true);
  out.over = await p.evaluate(() => ({ title: document.getElementById('overTitle').textContent, eye: document.getElementById('overEyebrow').textContent }));
  assert.equal(out.over.title, 'EVACUATED'); assert.match(out.over.eye, /BLITZKRIEG RUSH · VICTORY · 1 OF 1 MADE IT OUT/);
  // left behind: time runs out with you outside the ring; core loss during the evac no longer decides it
  await game();
  out.left = await p.evaluate(() => { const P = __pal, g = P.game, me = P.player; for (const q of P.players.values()) { q.max = q.hp = 1e9 } P.qm.max = P.qm.hp = 1e9; P.core.max = P.core.hp = 1e9;
    g.wave = 14; g.phase = 'build'; P.startRaid(); g.fb.t = 61; for (let i = 0; i < 60; i++) P.update(1 / 30);
    const r = { evac: !!g.fb.evac }; P.core.hp = 0; P.update(1 / 30); r.coreDead = g.phase;
    me.x = g.fb.evac.x + 4; me.y = g.fb.evac.y; for (let i = 0; i < 30 * 62 && g.phase === 'raid'; i++) { P.update(1 / 30); me.x = g.fb.evac.x + 4; for (const e of P.enemies) if (e.type === 'boss') e.hp = e.max }
    r.phase = g.phase; r.won = g.won; r.res = P.blitzResult(me); r.enemies = P.enemies.length; r.title = document.getElementById('overTitle').textContent; return r });
  assert.equal(out.left.evac, true); assert.equal(out.left.coreDead, 'raid', 'core at 0 during the evac: still running');
  assert.equal(out.left.phase, 'over'); assert.equal(out.left.won, false); assert.equal(out.left.res, 'left'); assert.equal(out.left.enemies, 0, 'bosses retreat');
  assert.equal(out.left.title, 'LEFT BEHIND');
  // core loss before the evacuation: a normal squad loss
  await game();
  out.hold = await p.evaluate(() => { const P = __pal, g = P.game; g.wave = 14; g.phase = 'build'; P.startRaid(); g.fb.t = 200; P.core.hp = 0; P.update(1 / 30);
    return { phase: g.phase, won: g.won, res: P.blitzResult(P.player), title: document.getElementById('overTitle').textContent } });
  assert.deepEqual(out.hold, { phase: 'over', won: false, res: '', title: 'CLAIM LOST' });
  // downed in the evacuation: no respawn clock; a revive in time still lets you out
  await game();
  out.down = await p.evaluate(() => { const P = __pal, g = P.game, me = P.player; P.qm.max = P.qm.hp = 1e9; P.core.max = P.core.hp = 1e9;
    g.wave = 14; g.phase = 'build'; P.startRaid(); g.fb.t = 60.5; for (let i = 0; i < 30; i++) P.update(1 / 30);
    // Delgado is kept across the map, so only a respawn clock could bring you back
    me.hp = 1; P.hurtPlayer(me, 5); for (let i = 0; i < 30 * 12; i++) { P.qm.x = me.x < P.N / 2 ? P.N - 1.5 : 1.5; P.qm.y = me.y < P.N / 2 ? P.N - 1.5 : 1.5; P.update(1 / 30) } const r = { downed: me.downed, rt: me.rt > 1e5 };
    P.revivePlayer(me); me.max = me.hp = 1e9; const E = g.fb.evac; for (let i = 0; i < 100; i++) { me.x = E.x; me.y = E.y; P.update(1 / 30) } r.out = !!me.out; return r });
  assert.deepEqual(out.down, { downed: true, rt: true, out: true });
  // Double Time: every 20 s, 15 of them; Hot LZ: opens at 0:45, a third smaller
  await game(['blitzclock', 'hotlz']);
  out.mods = await p.evaluate(() => { const P = __pal, g = P.game; for (const q of P.players.values()) { q.max = q.hp = 1e9 } P.core.max = P.core.hp = 1e9; P.qm.max = P.qm.hp = 1e9;
    g.wave = 14; g.phase = 'build'; P.startRaid(); const r = { every: g.fb.every, max: g.fb.max, evacAt: null }; const me = P.player; me.x = 0.5; me.y = 0.5;
    for (let i = 0; i < 30 * 299 && g.phase === 'raid'; i++) { P.update(1 / 30); me.x = .5; me.y = .5; for (const e of P.enemies) if (e.type === 'boss') P.hurtEnemyHook(e, 1e9, me.id); if (g.fb.evac && r.evacAt === null) { r.evacAt = Math.round(g.fb.t); r.ring = g.fb.evac.r } }
    r.n = g.fb.n; return r });
  assert.deepEqual(out.mods, { every: 20, max: 15, evacAt: 45, ring: 1, n: 15 });
  // the evac spot: clear 3x3, reachable, a run from the core, on every map and size
  out.spots = await p.evaluate(() => { const P = __pal, r = {}; for (const m of ['yard', 'river', 'quarry']) for (const s of ['std', 'xl']) {
      P.pick.map = m; P.pick.size = s; P.newGame(null, '', {}); const e = P.evacSpot(), c = P.core, d = Math.hypot(e.x - c.i - .5, e.y - c.j - .5);
      let clear = true; for (let a = -1; a <= 1; a++) for (let b = -1; b <= 1; b++) { const i = Math.floor(e.x) + a, j = Math.floor(e.y) + b, t = P.terr[j * P.N + i]; if (t === 1 || t === 2 || t >= 5) clear = false }
      r[m + '_' + s] = { d: +d.toFixed(1), clear } } return r });
  for (const [k, v] of Object.entries(out.spots)) { assert.ok(v.clear, k); assert.ok(v.d >= 4, k + ' is a run from the core') }
  // menu: the BLITZKRIEG button and note, labels
  out.menu = await p.evaluate(() => { const P = __pal; P.pick.mode = '5'; const btn = document.querySelector('[data-m5="blitz"]'); btn.click();
    const note = document.querySelector('.blitzNote'); return { mode: P.pick.mode, sel: btn.classList.contains('sel'), note: !note.hidden, chips: [...document.querySelectorAll('#soloMods .modChip')].map(x => x.dataset.mod) } });
  assert.equal(out.menu.mode, 'blitz'); assert.ok(out.menu.sel); assert.ok(out.menu.note);
  fs.writeFileSync(__dirname + '/out/blitz_mode.json', JSON.stringify({ out, errors }, null, 2)); assert.deepEqual(errors, []);
  console.log(JSON.stringify(out)); console.log('errors: none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
