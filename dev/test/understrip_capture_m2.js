// THE UNDERSTRIP M2 screenshots (a tool, not in the suite): a weapon on the floor with its label, a perk and a relic waiting,
// an elite charger's warning with its tag, and the weapon button in the kit.
// node understrip_capture_m2.js OUT_DIR
const { chromium } = require('playwright'), fs = require('node:fs'), path = require('node:path');
const OUT = process.argv[2] || path.join(__dirname, 'out/understrip-m2-shots'), PORT = process.env.PORT || 8080;
fs.mkdirSync(OUT, { recursive: true });
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), errors = [];
  const p = await b.newPage({ viewport: { width: 1280, height: 800 }, deviceScaleFactor: 2 }); p.on('pageerror', e => errors.push(e.message));
  await p.goto(`http://localhost:${PORT}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal);
  await p.evaluate(async () => { let s = 7; Math.random = () => (s = (s * 16807) % 2147483647) / 2147483647; const P = __pal; P.pick.mode = 'understrip'; P.showPage('solo'); document.getElementById('startBtn').click(); await new Promise(z => setTimeout(z, 500)); P.game.paused = true });
  const frame = () => p.evaluate(async () => { const P = __pal; for (let k = 0; k < 30; k++) { P.game.paused = false; P.update(1 / 30); P.render(1 / 30); P.game.paused = true } P.game.paused = false; P.render(1 / 30); P.hud(1 / 30); P.game.paused = true; await new Promise(z => setTimeout(z, 150)) });
  const draw = () => p.evaluate(async () => { const P = __pal; P.game.paused = false; for (let k = 0; k < 10; k++) { P.render(1 / 60); P.hud(1 / 60) } P.game.paused = true; await new Promise(z => setTimeout(z, 120)) });
  await p.evaluate(() => { const P = __pal, pl = P.player; pl.max = pl.hp = 1e6; for (const e of P.enemies) e.dead = true;
    P.usDropLoot(pl.x + .1, pl.y + .1, { kind: 'weapon', w: { id: 'w_nailgun', r: 'l', mods: ['m_dmg', 'm_mag'] } });
    P.usDropLoot(pl.x + 1.6, pl.y + .2, { kind: 'perk', k: 'p_loaded' }); P.usDropLoot(pl.x - 1.2, pl.y + 1, { kind: 'relic', k: 'x_chip' }) });
  await p.evaluate(() => { const P = __pal, pl = P.player; P.usInteract(pl, true) }); await frame(); await p.screenshot({ path: path.join(OUT, 'weapon-in-hand.png') });
  await p.evaluate(() => { const P = __pal, pl = P.player; P.game.us.loot.length = 0; let tx = pl.x + 3, ty = pl.y; for (const [ax, ay] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { let ok = true; for (let d = 1; d <= 4; d++) { const t = P.terr[((pl.y + ay * d) | 0) * P.N + ((pl.x + ax * d) | 0)]; if (t === P.T_CONC || t === P.T_SHUT || t === P.T_JUNK) ok = false } if (ok) { tx = pl.x + ax * 4; ty = pl.y + ay * 4; break } }
    const e = P.spawnEnemyAt('shield', tx, ty); e.us = { home: [tx, ty], st: 'hunt', sid: 900, t: 0, look: 0 }; P.usMakeElite(e, () => .5); e.speed = 0; window.__el = e });
  await frame(); await p.evaluate(() => { const e = window.__el, pl = __pal.player; e.est = 1; e.estT = .8; e.ea = Math.atan2(pl.y - e.y, pl.x - e.x); e.lx = e.x + Math.cos(e.ea) * 6; e.ly = e.y + Math.sin(e.ea) * 6 }); await draw();
  await p.screenshot({ path: path.join(OUT, 'elite-charger.png') });
  // the label, on a fresh page with the game running (prompts are drawn by the game's own loop)
  const q = await b.newPage({ viewport: { width: 1280, height: 800 }, deviceScaleFactor: 2 }); q.on('pageerror', e => errors.push(e.message));
  await q.goto(`http://localhost:${PORT}/debug.html?debug=1`); await q.waitForFunction(() => window.__pal);
  await q.evaluate(async () => { let s = 7; Math.random = () => (s = (s * 16807) % 2147483647) / 2147483647; const P = __pal; P.pick.mode = 'understrip'; P.showPage('solo'); document.getElementById('startBtn').click(); await new Promise(z => setTimeout(z, 500));
    const pl = P.player; pl.max = pl.hp = 1e6; for (const e of P.enemies) e.dead = true; P.usDropLoot(pl.x + .1, pl.y + .1, { kind: 'weapon', w: { id: 'w_nailgun', r: 'l', mods: ['m_dmg', 'm_mag'] } });
    P.usDropLoot(pl.x + 1.6, pl.y + .2, { kind: 'perk', k: 'p_loaded' }); P.usDropLoot(pl.x - 1.2, pl.y + 1, { kind: 'relic', k: 'x_chip' }); await new Promise(z => setTimeout(z, 900)) });
  await q.screenshot({ path: path.join(OUT, 'loot-label.png') });
  console.log('errors:', errors.length ? errors : 'none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
