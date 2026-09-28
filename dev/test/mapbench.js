// Frame cost on the v0.9.1 scenes (not pass/fail): XL boss raids with both bosses up, and each PvP layout with six
// players. Phone-sized, software drawing (like bench.js). node mapbench.js
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--disable-gpu', '--disable-accelerated-2d-canvas'] }), out = {};
  const scenes = [['yard', 'xl', ''], ['river', 'xl', ''], ['quarry', 'xl', ''], ['yard', 'std', 'base'], ['river', 'std', 'base'], ['quarry', 'std', 'base'], ['yard', 'std', 'ffa'], ['river', 'std', 'ffa'], ['quarry', 'std', 'ffa']];
  for (const [map, size, pv] of scenes) {
    const p = await b.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, hasTouch: true, isMobile: true });
    await p.goto(`http://localhost:${process.env.PORT || 8080}/debug.html?debug=1`); await p.waitForTimeout(700);
    out[map + ':' + size + (pv ? ':' + pv : '')] = await p.evaluate(([map, size, pv]) => {
      const P = __pal; let s = 7; Math.random = () => (s = (s * 16807) % 2147483647) / 2147483647; P.demo = false; P.pick.map = map; P.pick.size = size; P.pick.mode = '10';
      P.newGame(['soldier', 'sniper', 'grenadier', 'quartermaster', 'soldier', 'sniper'].map((c, n) => ({ id: n ? 'b' + n : 'me', name: 'P' + n, cls: c, cos: 'std|class|std|none', team: n % 2 ? 'b' : 'a' })), pv); P.enterGameHook();
      const keep = () => { for (const q of P.players.values()) { q.hp = q.max; q.prot = 0 } for (const c of P.cores) c.hp = c.max };
      if (!pv) { P.game.wave = 9; P.startRaid(); for (const q of P.game.queue.filter(q => q.startsWith('boss:'))) P.spawnBoss(q.slice(5)) } else if (pv === 'base') { P.game.phase = 'raid' }
      for (let i = 0; i < 400; i++) { keep(); for (const q of P.players.values()) if (q.id !== 'me') { q.fireIn = true; q.aim = { x: Math.cos(i / 20 + q.slot), y: Math.sin(i / 20 + q.slot) } } P.update(1 / 60) }
      const g = P.ctx, flush = () => g.getImageData(0, 0, 1, 1); for (let i = 0; i < 15; i++) { keep(); P.update(1 / 60); P.render(1 / 60); flush() }
      const ts = [], us = []; for (let i = 0; i < 90; i++) { keep(); let t = performance.now(); P.update(1 / 60); us.push(performance.now() - t); t = performance.now(); P.render(1 / 60); flush(); ts.push(performance.now() - t) }
      ts.sort((a, b) => a - b); us.sort((a, b) => a - b);
      return { N: P.N, enemies: P.enemies.length, bosses: P.enemies.filter(e => e.type === 'boss').map(e => e.boss).join('+'), update_med: +us[45].toFixed(2), render_med: +ts[45].toFixed(2), render_p90: +ts[81].toFixed(2) };
    }, [map, size, pv]);
    await p.close();
  }
  console.log(JSON.stringify(out, null, 1)); await b.close();
})();
