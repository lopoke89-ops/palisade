// v0.9.6.4 the Whiteout Gauntlet (campaign wave 13): 3:30 on the clock; a wave of 2 Rime Colossi + 1 pool boss every 30 s
// (6 waves, no repeats in a row, no ordinary raiders); at most 8 bosses up; each lands after a 1 s ring, apart from the
// others and off the core; 110% health; the evac opens at 0:30 and no boss lands after it; at 0:00 they retreat; each
// soldier's claim counts the waves whose three bosses all fell. node campaign_gauntlet.js
const { chromium } = require('playwright'), assert = require('node:assert/strict');
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), errors = [], out = {};
  const p = await b.newPage({ viewport: { width: 1280, height: 800 } }); p.on('pageerror', e => errors.push(e.message));
  await p.goto(`http://localhost:${process.env.PORT || 8080}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal);
  const fresh = (kill) => p.evaluate(async kill => { const P = __pal; if (P.toMenu) P.toMenu(); P.pick.mode = 'campaign'; P.pick.size = 'std'; P.showPage('solo'); document.getElementById('startBtn').click(); await new Promise(r => setTimeout(r, 300));
    let s = 11; Math.random = () => (s = (s * 16807) % 2147483647) / 2147483647;
    window.step = dt => { P.game.paused = false; P.update(dt); if (P.game.phase !== 'over') P.game.paused = true };
    const g = P.game; g.paused = true; g.chapter = 3; P.changeChapter(3); g.wave = 12; g.phase = 'build'; g.timer = .01; step(1 / 30);   // into wave 13
    window.imm = () => { const pl = P.player; pl.max = 1e9; pl.hp = 1e9; P.core.hp = P.core.max = 1e9; P.qm.hp = P.qm.max = 1e9; if (P.qm.alive === false) P.qm.alive = true };
    return { fb: !!g.fb, gauntlet: !!(g.fb && g.fb.gauntlet), t: g.fb && g.fb.t, wave: g.wave, map: g.map } }, kill);
  // 1. the clock, the waves, the cap, health and spacing (nobody shoots back: bosses pile up)
  out.start = await fresh();
  assert.deepEqual(out.start, { fb: true, gauntlet: true, t: 210, wave: 13, map: 'frost' });
  out.run = await p.evaluate(() => { const P = __pal, g = P.game, F = g.fb, W = [], landed = [], maxUp = { n: 0 }, ids = new Set(), raiders = new Set();
    const normal = k => { const B = P.BOSSES[k]; return B.hp * g.Df.hp * P.mapHp() };   // one player, wave 13: the usual multipliers
    let evacAt = null, landedAfterEvac = 0;
    for (let i = 0; i < 30 * 211 && g.phase !== 'over'; i++) { imm(); P.player.x = P.core.i + .5; P.player.y = P.core.j + .5;
      const before = F.wave; step(1 / 30);
      if (F.wave > before) W.push({ wave: F.wave, t: Math.round(F.t), keys: F.pend.slice(-3).map(q => q.k) });
      let up = 0; for (const e of P.enemies) { if (e.dead) continue; if (e.type === 'boss') { up++; if (!ids.has(e.id)) { ids.add(e.id); landed.push({ k: e.boss, hp: +(e.max / normal(e.boss)).toFixed(3), x: e.x, y: e.y, t: F.t, onCore: P.coreKs.has(Math.floor(e.y) * P.N + Math.floor(e.x)) }); if (F.evac) landedAfterEvac++ } } else raiders.add(e.type) }
      maxUp.n = Math.max(maxUp.n, up); if (F.evac && evacAt === null) evacAt = Math.round(F.t) }
    return { W, landed: landed.length, maxUp: maxUp.n, raiders: [...raiders], evacAt, landedAfterEvac, hp: [...new Set(landed.map(l => l.hp))], onCore: landed.filter(l => l.onCore).length,
      firstWave: landed.slice(0, 3).map(l => [l.x, l.y]), phase: g.phase, res: P.player.res, done: F.done, cleared: P.gauntletCleared() } });
  assert.deepEqual(out.run.W.map(w => w.t), [210, 180, 150, 120, 90, 60], 'a wave every 30 s from 3:30 to 1:00');
  for (const w of out.run.W) { assert.equal(w.keys.filter(k => k === 'rime').length, 2, 'two Rimes ' + w.keys); assert.ok(['whitebutcher', 'whiteforeman', 'tempest', 'bulldozer', 'bluebutcher', 'arsonist'].includes(w.keys.find(k => k !== 'rime')), 'pool boss ' + w.keys) }
  const extras = out.run.W.map(w => w.keys.find(k => k !== 'rime')); for (let i = 1; i < extras.length; i++) assert.notEqual(extras[i], extras[i - 1], 'no repeat in a row');
  assert.equal(out.run.maxUp, 8, 'never more than 8 up'); assert.ok(out.run.landed >= 8 && out.run.landed < 18, 'with nobody falling, later bosses wait: ' + out.run.landed);
  assert.deepEqual(out.run.raiders, [], 'no ordinary raiders'); assert.equal(out.run.evacAt, 30); assert.equal(out.run.landedAfterEvac, 0);
  assert.deepEqual(out.run.hp, [1.375], '110% of normal health, on top of the +25% every boss has since v0.9.6.5'); assert.equal(out.run.onCore, 0);
  const [a, c, d] = out.run.firstWave; assert.ok(Math.min(Math.hypot(a[0] - c[0], a[1] - c[1]), Math.hypot(a[0] - d[0], a[1] - d[1]), Math.hypot(c[0] - d[0], c[1] - d[1])) >= 3, 'first wave lands 3+ tiles apart');
  assert.equal(out.run.phase, 'over'); assert.equal(out.run.res, 'left', 'still on the field at 0:00'); assert.equal(out.run.cleared, 0);
  // 2. killing each wave as it lands: every wave counts as cleared; reaching the evac wins; the claim carries it
  await fresh();
  out.kill = await p.evaluate(() => { const P = __pal, g = P.game, F = g.fb;
    for (let i = 0; i < 30 * 211 && g.phase !== 'over'; i++) { imm(); for (const e of P.enemies) if (e.type === 'boss' && !e.dead && e.hp > 0) P.hurtEnemyHook(e, 1e9, P.player.id);
      if (F.evac) { P.player.x = F.evac.x; P.player.y = F.evac.y } step(1 / 30) }
    const { claim } = P.runClaim(13, true, 0); return { cleared: P.gauntletCleared(), gKill: g.gKill, fbLog: g.fbLog.length, rimes: g.fbLog.filter(k => k === 'rime').length, out: !!P.player.out, won: g.won, claim: { g_cleared: claim.g_cleared, cv: claim.cv, evac: claim.evac, fb: claim.fb_keys.length } } });
  assert.equal(out.kill.cleared, 6); assert.deepEqual(out.kill.gKill, [3, 3, 3, 3, 3, 3]); assert.equal(out.kill.fbLog, 18); assert.equal(out.kill.rimes, 12);
  assert.ok(out.kill.out); assert.equal(out.kill.won, true); assert.deepEqual(out.kill.claim, { g_cleared: 6, cv: 4, evac: 'evac', fb: 18 });
  assert.deepEqual(errors, []); console.log(JSON.stringify(out)); console.log('errors: none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
