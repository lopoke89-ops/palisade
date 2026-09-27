// Stress profile (not a pass/fail test). node stress.js [page]   default page: debug.html
// Phone-sized screen with software drawing. Three loads:
//   A. Endless raid 20 against a walled base (solo)
//   B. a 6-player crew (5 bots firing at the nearest raider) in a boss raid
//   C. a long Endless session: 30 simulated minutes, checking memory and list sizes as it goes
// Reports update (simulation) and render time per frame, and, with PROFILE=1, the functions using the most time.
const { chromium } = require('playwright');
const page = process.argv[2] || 'debug.html';
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--disable-gpu', '--disable-accelerated-2d-canvas', '--enable-precise-memory-info', '--js-flags=--expose-gc'] });
  const out = { page };
  const open = async () => {
    const p = await b.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, hasTouch: true, isMobile: true });
    await p.goto(`http://localhost:${process.env.PORT || 8080}/${page}?debug=1`); await p.waitForTimeout(900);
    await p.evaluate(() => { document.querySelector('[data-go=solo]').click() }); await p.waitForTimeout(100);
    await p.evaluate(() => { const m = document.querySelector('[data-mm=endless]'); if (m) m.click(); document.getElementById('startBtn').click() });
    await p.waitForTimeout(400); return p;
  };
  const prof = async (p, fn, arg) => {
    if (!process.env.PROFILE) return p.evaluate(fn, arg);
    const cdp = await p.context().newCDPSession(p); await cdp.send('Profiler.enable'); await cdp.send('Profiler.setSamplingInterval', { interval: 200 }); await cdp.send('Profiler.start');
    const r = await p.evaluate(fn, arg); const { profile } = await cdp.send('Profiler.stop');
    const self = {}, dt = profile.timeDeltas, byId = {}; for (const n of profile.nodes) byId[n.id] = n;
    for (let i = 0; i < profile.samples.length; i++) { const n = byId[profile.samples[i]], k = (n.callFrame.functionName || '(anon)') + ':' + n.callFrame.lineNumber; self[k] = (self[k] || 0) + (dt[i] || 0) / 1000 }
    const tot = Object.values(self).reduce((a, b) => a + b, 0);
    r.hot = Object.entries(self).sort((a, b) => b[1] - a[1]).slice(0, 14).map(([k, v]) => `${k} ${(100 * v / tot).toFixed(1)}%`);
    return r;
  };
  // shared in-page helpers
  const setup = () => {
    const P = __pal; let s = 7; Math.random = () => (s = (s * 16807) % 2147483647) / 2147483647;
    window.__wallUp = () => { const N = 16, c = P.core, mats = [0, 1, 2]; let k = 0;
      for (let j = 0; j < N; j++) for (let i = 0; i < N; i++) { const d = Math.max(Math.abs(i - c.i), Math.abs(j - c.j));
        if ((d === 3 || d === 4) && !P.walls[j * N + i]) { const w = P.makeWall(mats[k % 3], k % 11 === 0, [1, .6, .25][k % 3]); if (k % 9 === 0) { w.fire = 4; w.char = .5 } P.walls[j * N + i] = w; k++ } } };
    window.__immortal = () => { for (const p of P.players.values()) { p.max = 1e9; p.hp = 1e9 } P.core.max = 1e9; P.core.hp = 1e9; P.qm.max = 1e9; P.qm.hp = 1e9 };
    window.__bots = () => { for (const p of P.players.values()) { let best = null, bd = 1e9; for (const e of P.enemies) { if (e.dead) continue; const d = Math.hypot(e.x - p.x, e.y - p.y); if (d < bd) { bd = d; best = e } }
      if (best) { const l = bd || 1; p.aim = { x: (best.x - p.x) / l, y: (best.y - p.y) / l }; p.fireIn = bd < 10; p.autoFire = true; p.pullIn = (p.pullIn | 0) + 1; p.pullT = P.game.time } else p.fireIn = false } };
    window.__time = (n, render) => { const g = P.ctx, flush = () => g.getImageData(0, 0, 1, 1), up = [], rn = [];
      for (let i = 0; i < n; i++) { __bots(); let t = performance.now(); P.update(1 / 60); up.push(performance.now() - t);
        if (render) { t = performance.now(); P.render(1 / 60); flush(); rn.push(performance.now() - t) } }
      const q = (a, f) => { const s = a.slice().sort((x, y) => x - y); return +s[Math.floor(s.length * f)].toFixed(2) };
      P.profOn(true); for (let i = 0; i < 30; i++) { P.render(1 / 60); g.getImageData(0, 0, 1, 1) } const st = P.prof(); for (const k in st) st[k] = +(st[k] / 30).toFixed(2);
      return { stages: st, update_med: q(up, .5), update_p90: q(up, .9), update_max: q(up, .99), render_med: rn.length ? q(rn, .5) : null, render_p90: rn.length ? q(rn, .9) : null } };
  };
  // A. Endless raid 20, walled base
  {
    const p = await open(); await p.evaluate(setup);
    out.A_endless20 = await prof(p, () => { const P = __pal; __wallUp(); __immortal(); P.player.x = P.core.i + .5; P.player.y = P.core.j + 2.5;
      P.game.wave = 19; P.startRaid(); for (let i = 0; i < 900; i++) P.update(1 / 60); __immortal();
      const r = __time(240, true); r.enemies = P.enemies.filter(e => !e.dead).length; r.queue = P.game.queue.length; r.parts = P.parts.length; r.bullets = P.bullets.length; return r });
    await p.close();
  }
  // B. 6 players + boss raid
  {
    const p = await open(); await p.evaluate(setup);
    out.B_six_boss = await prof(p, () => { const P = __pal; __wallUp();
      const cls = ['sniper', 'grenadier', 'quartermaster', 'soldier', 'sniper'];
      for (let i = 0; i < 5; i++) { const q = P.makePlayer('bot' + i, 'Bot' + i, cls[i], i + 1, '', ''); q.x = P.core.i + .5 + (i - 2) * .8; q.y = P.core.j + 2; P.players.set('bot' + i, q) }
      __immortal(); P.game.wave = 9; P.startRaid(); for (let i = 0; i < 600; i++) { __bots(); P.update(1 / 60) } __immortal();
      const r = __time(240, true); r.enemies = P.enemies.filter(e => !e.dead).length; r.bosses = P.enemies.filter(e => e.type === 'boss').length; r.parts = P.parts.length; r.bullets = P.bullets.length; r.players = P.players.size; return r });
    await p.close();
  }
  // D. 6 players in Endless raid 20 (the biggest crowds the game makes)
  {
    const p = await open(); await p.evaluate(setup);
    out.D_six_endless20 = await prof(p, () => { const P = __pal; __wallUp();
      const cls = ['sniper', 'grenadier', 'quartermaster', 'soldier', 'sniper'];
      for (let i = 0; i < 5; i++) { const q = P.makePlayer('bot' + i, 'Bot' + i, cls[i], i + 1, '', ''); q.x = P.core.i + .5 + (i - 2) * .8; q.y = P.core.j + 2; P.players.set('bot' + i, q) }
      __immortal(); P.game.wave = 19; P.startRaid(); let peak = 0; for (let i = 0; i < 1500; i++) { __bots(); P.update(1 / 60); peak = Math.max(peak, P.enemies.filter(e => !e.dead).length) } __immortal();
      const r = __time(240, true); r.enemies = P.enemies.filter(e => !e.dead).length; r.peakEnemies = peak; r.parts = P.parts.length; r.bullets = P.bullets.length; return r });
    await p.close();
  }
  // C. long Endless: 30 simulated minutes (update only, a rendered frame every simulated second), memory every 5 minutes
  {
    const p = await open(); await p.evaluate(setup);
    const cdp = await p.context().newCDPSession(p);
    await p.evaluate(() => { __wallUp(); __immortal(); __pal.player.x = __pal.core.i + .5; __pal.player.y = __pal.core.j + 2.5 });
    out.C_long = [];
    for (let m = 0; m <= 30; m += 5) {
      if (m) await p.evaluate(() => { const P = __pal; for (let s = 0; s < 300; s++) { __immortal(); for (let f = 0; f < 60; f++) { __bots(); P.update(1 / 60) } P.render(1 / 60); for (const e of P.enemies) { e.age = (e.age || 0) + 1; if (e.age > 25 && e.type !== 'boss') e.dead = true } if (P.game.phase === 'build') P.startRaid() } });
      await cdp.send('HeapProfiler.collectGarbage');
      const heap = (await cdp.send('Runtime.getHeapUsage')).usedSize / 1048576;
      const st = await p.evaluate(() => { const P = __pal; return { wave: P.game.wave, enemies: P.enemies.length, parts: P.parts.length, bullets: P.bullets.length, rockets: P.rockets.length, fires: P.fires.length, zaps: P.zaps.length, slashes: P.slashes.length } });
      const t = await p.evaluate(() => __time(120, true));
      out.C_long.push({ min: m, heapMB: +heap.toFixed(1), ...st, update_med: t.update_med, render_med: t.render_med, render_p90: t.render_p90 });
    }
    await p.close();
  }
  console.log(JSON.stringify(out, null, 1));
  await b.close();
})().catch(e => { console.log('Error:', e.message); process.exit(1) });
