// v0.9.3 meter (not pass/fail): what six Gold milestone outfits cost next to six standard ones, on the phone-sized,
// software-drawn canvas bench.js uses. Two scenes:
//   raid6: a busy night raid with six players around a walled stake (render ms per frame, median and p90)
//   stage6: the lobby with a full party of six (CPU ms per second, like bench.js's party6)
// node goldbench.js [label]   GOLD=0 measures the same scenes in standard outfits (for an older build: PORT=…)
const { chromium } = require('playwright');
const label = process.argv[2] || 'build', gold = process.env.GOLD !== '0';
const GOLDS = (process.env.SKINS || 'butcher4,demo4,storm4,ferry4,foreman4,gsoldier').split(',');
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--disable-gpu', '--disable-accelerated-2d-canvas'] });
  const out = { label, gold }, url = `http://localhost:${process.env.PORT || 8080}/${process.env.PAGE || 'debug.html'}?debug=1`;
  const p = await b.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, hasTouch: true, isMobile: true });
  await p.goto(url); await p.waitForTimeout(800);
  await p.evaluate(({ gold, GOLDS }) => { const L = __pal.locker; if (gold) { L.owned.push('skin:' + GOLDS[0]); L.eq.skin = GOLDS[0] } }, { gold, GOLDS });
  await p.evaluate(() => { __pal.showPage('solo') }); await p.click('#startBtn'); await p.waitForTimeout(300);
  out.raid6 = await p.evaluate(({ gold, GOLDS }) => {
    const P = __pal; let s = 7; Math.random = () => (s = (s * 16807) % 2147483647) / 2147483647;
    const N = 16, c = P.core; let k = 0;
    for (let j = 0; j < N; j++) for (let i = 0; i < N; i++) { const d = Math.max(Math.abs(i - c.i), Math.abs(j - c.j)); if ((d === 3 || d === 4) && !P.walls[j * N + i]) { P.walls[j * N + i] = P.makeWall(k % 3, false, 1); k++ } }
    const cls = ['sniper', 'grenadier', 'quartermaster', 'soldier', 'sniper'];
    for (let i = 0; i < 5; i++) { const q = P.makePlayer('bot' + i, 'Bot' + i, cls[i], i + 1, gold ? GOLDS[i + 1] + '|class|std|none' : 'std|class|std|none', ''); q.x = c.i + .5 + (i - 2) * .8; q.y = c.j + 2; P.players.set('bot' + i, q) }
    P.player.x = c.i + .5; P.player.y = c.j + 2.5; P.game.wave = 4; P.startRaid();
    for (let i = 0; i < 400; i++) P.update(1 / 60);
    const g = P.ctx, flush = () => g.getImageData(0, 0, 1, 1);
    for (let i = 0; i < 20; i++) { P.update(1 / 60); P.render(1 / 60); flush() }
    const ts = []; for (let i = 0; i < 120; i++) { P.update(1 / 60); const t = performance.now(); P.render(1 / 60); flush(); ts.push(performance.now() - t) }
    ts.sort((a, b) => a - b); return { players: P.players.size, median: +ts[60].toFixed(2), p90: +ts[108].toFixed(2) };
  }, { gold, GOLDS });
  await p.close();
  const q = await b.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, hasTouch: true, isMobile: true });
  await q.goto(url); await q.waitForTimeout(1200);
  const cdp = await q.context().newCDPSession(q); await cdp.send('Performance.enable');
  await q.evaluate(({ gold, GOLDS }) => { const P = __pal, L = P.locker; if (gold) { L.owned.push('skin:' + GOLDS[0]); L.eq.skin = GOLDS[0] }
    P.NET.mode = 'host'; P.NET.code = 'BNCH'; P.NET.roster = ['soldier', 'sniper', 'grenadier', 'quartermaster', 'soldier', 'sniper'].map((c, n) => ({ id: n ? 'g' + n : P.NET.myId || 'host', name: 'P' + n, cls: c, cos: (gold ? GOLDS[n] : 'std') + '|class|std|none' })); P.showPage('lobby') }, { gold, GOLDS });
  await q.waitForTimeout(1000);
  const m0 = (await cdp.send('Performance.getMetrics')).metrics.find(m => m.name === 'TaskDuration').value; await q.waitForTimeout(5000);
  const m1 = (await cdp.send('Performance.getMetrics')).metrics.find(m => m.name === 'TaskDuration').value;
  out.stage6_cpu_ms_per_s = +((m1 - m0) / 5 * 1000).toFixed(0);
  console.log(JSON.stringify(out)); await b.close();
})();
