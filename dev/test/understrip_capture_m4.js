// THE UNDERSTRIP M4: screenshots for the evidence folder (a tool, not in the suite): a first-time tip, and a dark Shelter 7
// room on the default brightness and on the top step (every raider marked).
// node understrip_capture_m4.js OUT_DIR        (a server on PORT, default 8080, serving the built site)
const { chromium } = require('playwright'), fs = require('node:fs'), path = require('node:path');
const OUT = process.argv[2] || path.join(__dirname, 'out/understrip-m4-shots'), PORT = process.env.PORT || 8080;
fs.mkdirSync(OUT, { recursive: true });
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), errors = [];
  const p = await b.newPage({ viewport: { width: 1280, height: 800 }, deviceScaleFactor: 2 }); p.on('pageerror', e => errors.push(e.message));
  await p.goto(`http://localhost:${PORT}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal && __pal.ready);
  await p.evaluate(async () => { localStorage.removeItem('palisade.usTips.v1'); let s = 7; Math.random = () => (s = (s * 16807) % 2147483647) / 2147483647; const P = __pal; P.pick.mode = 'understrip'; P.showPage('solo'); document.getElementById('startBtn').click(); await new Promise(z => setTimeout(z, 500)); P.game.paused = true; P.player.max = P.player.hp = 1e7;
    window.step = sec => { for (let t = 0; t < sec; t += 1 / 30) { P.game.paused = false; P.update(1 / 30); P.game.paused = true; P.hud(1 / 30) } } });
  const shot = async n => { await p.evaluate(() => { const t = document.getElementById('toast'); if (t) t.hidden = true }); await p.screenshot({ path: path.join(OUT, n + '.png') }); console.log(n) };
  // the first time near a shrine
  await p.evaluate(() => { const P = __pal, L = P.game.lay, pl = P.player; for (const e of P.enemies) e.speed = 0; step(15); const S = L.shrines.find(q => !q.arena); pl.x = S.x + 1; pl.y = S.y + 1.4; pl.tp++; pl.aim = { x: -.7, y: -.7 }; step(.4); for (let k = 0; k < 10; k++) P.render(1 / 60) });
  await shot('tip-shrine');
  // the same dark room on brightness 1 of 4 and 4 of 4
  await p.evaluate(() => { const P = __pal; P.usChangeLevel(3); const pl = P.player; for (const e of P.enemies) { e.speed = 0; if (Math.hypot(e.x - pl.x, e.y - pl.y) > 12) e.dead = true }
    for (let k = 0; k < 4; k++) { const e = P.spawnEnemyAt(k % 2 ? 'rifle' : 'shield', pl.x - 3 + k * 2, pl.y - 4 - (k % 2)); if (e && ![12, 13, 14, 15].includes(P.terr[(e.y | 0) * P.N + (e.x | 0)])) { e.us = { home: [e.x, e.y], st: 'idle', sid: 900 + k, t: 0, look: k }; e.speed = 0 } else if (e) e.dead = true }
    pl.aim = { x: .7, y: .7 }; step(1.2) });
  for (const br of [0, 3]) { await p.evaluate(br => { const P = __pal; P.cfg.usBright = br; for (let k = 0; k < 10; k++) P.render(1 / 60) }, br); await shot('brightness-' + (br + 1) + '-of-4') }
  console.log('errors:', errors.length ? errors : 'none'); await b.close();
})();
