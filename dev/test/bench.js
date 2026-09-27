// Frame-cost benchmark (not a pass/fail test). node bench.js [label]   (PORT=8082 PAGE=index.html to measure an older build)
// Phone-sized canvas (390x844 @3x) with software drawing, so it measures CPU work, the part phones feel.
// Scenes: a busy raid by day and by night with a walled base (some walls damaged or burning), and
// CPU time used per second while sitting in the menus (the demo game runs behind them).
const { chromium } = require('playwright');
const label = process.argv[2] || 'build';
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--disable-gpu', '--disable-accelerated-2d-canvas'] });
  const out = { label };
  for (const night of [false, true]) {
    const p = await b.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, hasTouch: true, isMobile: true });
    await p.goto(`http://localhost:${process.env.PORT||8080}/${process.env.PAGE||'debug.html'}?debug=1`); await p.waitForTimeout(800);
    await p.evaluate(() => { __pal.showPage('solo') }); await p.click('#startBtn'); await p.waitForTimeout(300);
    out[night ? 'night' : 'day'] = await p.evaluate((night) => {
      const P = __pal; let s = 7; Math.random = () => (s = (s * 16807) % 2147483647) / 2147483647;
      // a walled base: a ring of mixed walls around the stake, some damaged, four burning
      const N = 16, c = P.core, mats = [0, 1, 2]; let k = 0;
      for (let j = 0; j < N; j++) for (let i = 0; i < N; i++) {
        const d = Math.max(Math.abs(i - c.i), Math.abs(j - c.j));
        if ((d === 3 || d === 4) && !P.walls[j * N + i]) { const w = P.makeWall(mats[k % 3], k % 11 === 0, [1, .6, .25][k % 3]); if (k % 9 === 0) { w.fire = 4; w.char = .5 } P.walls[j * N + i] = w; k++ }
      }
      P.player.x = c.i + .5; P.player.y = c.j + 2.5; P.game.wave = night ? 4 : 1; P.startRaid();
      for (let i = 0; i < 500; i++) P.update(1 / 60);
      const g = P.ctx, flush = () => g.getImageData(0, 0, 1, 1);
      for (let i = 0; i < 15; i++) { P.update(1 / 60); P.render(1 / 60); flush() }
      const ts = []; for (let i = 0; i < 90; i++) { P.update(1 / 60); const t = performance.now(); P.render(1 / 60); flush(); ts.push(performance.now() - t) }
      ts.sort((a, b) => a - b);
      return { walls: P.walls.filter(Boolean).length, enemies: P.enemies.length, render_ms_median: +ts[45].toFixed(2), render_ms_p90: +ts[81].toFixed(2) };
    }, night);
    await p.close();
  }
  // menus: CPU time per second with the locker page open (demo game behind it)
  const p = await b.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, hasTouch: true, isMobile: true });
  await p.goto(`http://localhost:${process.env.PORT||8080}/${process.env.PAGE||'debug.html'}?debug=1`); await p.waitForTimeout(1500);
  const cdp = await p.context().newCDPSession(p); await cdp.send('Performance.enable');
  for (const page of ['main', 'locker']) {
    await p.evaluate(pg => __pal.showPage(pg), page); await p.waitForTimeout(800);
    const m0 = (await cdp.send('Performance.getMetrics')).metrics.find(m => m.name === 'TaskDuration').value;
    await p.waitForTimeout(4000);
    const m1 = (await cdp.send('Performance.getMetrics')).metrics.find(m => m.name === 'TaskDuration').value;
    out['menu_' + page + '_cpu_ms_per_s'] = +((m1 - m0) / 4 * 1000).toFixed(0);
  }
  console.log(JSON.stringify(out));
  await b.close();
})();
