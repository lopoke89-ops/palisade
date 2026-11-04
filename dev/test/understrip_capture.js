// THE UNDERSTRIP: screenshots for a milestone's evidence folder (a tool, not in the suite). Plays a seeded solo run and
// stops at the moments worth seeing: the tunnels, a shrine, the trader, the lift's ring, the Pit Boss in both stages with
// their warnings, the end screen, the PLAY card, and the tunnels on a phone held upright.
// node understrip_capture.js OUT_DIR        (a server on PORT, default 8080, serving the built site)
const { chromium, devices } = require('playwright'), fs = require('node:fs'), path = require('node:path');
const OUT = process.argv[2] || path.join(__dirname, 'out/understrip-shots'), PORT = process.env.PORT || 8080;
fs.mkdirSync(OUT, { recursive: true });
const shot = async (p, name) => { await p.screenshot({ path: path.join(OUT, name + '.png') }); console.log(name) };
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), errors = [];
  const run = async (p) => {
    p.on('pageerror', e => errors.push(e.message));
    await p.goto(`http://localhost:${PORT}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal);
    await p.evaluate(async () => { let s = 7; Math.random = () => (s = (s * 16807) % 2147483647) / 2147483647; const P = __pal; P.pick.mode = 'understrip'; P.showPage('solo'); document.getElementById('startBtn').click(); await new Promise(z => setTimeout(z, 500)); P.game.paused = true });
  };
  // the scene at a spot, after a few frames of play (frozen raiders) and a settled camera
  const at = (p, fn) => p.evaluate(async (fn) => { const P = __pal, pl = P.player, L = P.game.lay; eval(fn); for (let k = 0; k < 40; k++) { P.game.paused = false; P.update(1 / 30); P.game.paused = true; P.render(1 / 30) } P.hud(1 / 30); await new Promise(z => setTimeout(z, 200)) }, fn.toString().replace(/^\(\)\s*=>\s*\{?|\}$/g, ''));
  // a warning frozen on screen: set it, then draw (no play in between, so it doesn't run out)
  const freeze = (p, fn) => p.evaluate(async (fn) => { const P = __pal, pl = P.player, L = P.game.lay; eval(fn); for (let k = 0; k < 20; k++) { P.render(1 / 60); P.hud(1 / 60) } await new Promise(z => setTimeout(z, 120)) }, fn.toString().replace(/^\(\)\s*=>\s*\{?|\}$/g, ''));
  const D = await b.newPage({ viewport: { width: 1280, height: 800 }, deviceScaleFactor: 2 }); await run(D);
  await D.evaluate(() => { const P = __pal; P.player.max = P.player.hp = 1e6; window.freeze = setInterval(() => { for (const e of P.enemies) if (e.type !== 'boss') e.speed = 0 }, 30) });
  await at(D, () => { pl.aim = { x: 1, y: 0 } }); await shot(D, 'tunnels');
  await at(D, () => { const S = L.shrines.find(q => !q.arena); for (const e of P.enemies) if (Math.hypot(e.x - S.x, e.y - S.y) < 10) e.dead = true; pl.x = S.x - .2; pl.y = S.y + .9; pl.tp++; P.usInteract(pl, true) }); await shot(D, 'shrine');
  await at(D, () => { const m = L.merchants[0]; pl.x = m.x; pl.y = m.y + 1; pl.sal = 140; pl.tp++ }); await D.evaluate(() => __pal.usInteract(__pal.player, true)); await D.waitForTimeout(400); await shot(D, 'trader'); await D.click('#armClose'); await D.evaluate(() => { __pal.game.paused = true });
  await at(D, () => { pl.x = L.exit[0]; pl.y = L.exit[1]; pl.tp++; for (const e of P.enemies) e.dead = true; P.game.us.exitT = 1.6 }); await shot(D, 'lift');
  await D.evaluate(() => { const P = __pal; P.usChangeLevel(1); P.usChangeLevel(2); for (const e of P.enemies) e.dead = true; P.game.paused = false; P.update(1 / 30); P.game.paused = true });
  await at(D, () => { const A = L.arena; pl.x = A.x + A.w / 2; pl.y = A.y + A.h - 3; pl.tp++ });
  await D.evaluate(() => { const P = __pal; P.game.paused = false; for (let k = 0; k < 150; k++)P.update(1 / 30); P.game.paused = true });
  await at(D, () => { const B = P.enemies.find(e => e.type === 'boss'); pl.x = B.x + 1.2; pl.y = B.y + 1.2; pl.tp++ });
  await freeze(D, () => { const B = P.enemies.find(e => e.type === 'boss'); B.st = 1; B.stT = B.stM = .7; B.aim = { x: .7, y: .7 }; P.lobs.push({ x0: B.x, y0: B.y, x1: B.x - 3, y1: B.y + 2, t: .3, T: 1, R: 1.4, power: .8 }) }); await shot(D, 'boss-stage1');
  await at(D, () => { const B = P.enemies.find(e => e.type === 'boss'); P.hurtEnemy(B, B.hp - B.max * .45, pl.id) });
  await D.evaluate(() => { const P = __pal; P.game.paused = false; for (let k = 0; k < 110; k++)P.update(1 / 30); P.game.paused = true });
  await at(D, () => { const B = P.enemies.find(e => e.type === 'boss'); pl.x = B.x + 4; pl.y = B.y + 1; pl.tp++ });
  await freeze(D, () => { const B = P.enemies.find(e => e.type === 'boss'); B.st = 2; B.stT = B.stM = .9; B.lx = B.x + 8; B.ly = B.y + 2; B.hp = B.max * .38 }); await shot(D, 'boss-stage2-rush');
  await freeze(D, () => { const B = P.enemies.find(e => e.type === 'boss'); B.st = 61; B.stT = B.stM = .7; B.lx = pl.x; B.ly = pl.y }); await shot(D, 'boss-stage2-spray');
  await D.evaluate(() => { const P = __pal, B = P.enemies.find(e => e.type === 'boss'); B.inv = 0; P.hurtEnemy(B, 1e9, P.player.id); P.game.paused = false; for (let k = 0; k < 12; k++)P.update(1 / 30); const L = P.game.lay; P.player.x = L.exit[0]; P.player.y = L.exit[1]; P.player.tp++; for (let k = 0; k < 120; k++)P.update(1 / 30) });
  await D.waitForTimeout(1500); await shot(D, 'results');
  // the PLAY card
  const M = await b.newPage({ viewport: { width: 1280, height: 800 }, deviceScaleFactor: 2 }); M.on('pageerror', e => errors.push(e.message));
  await M.goto(`http://localhost:${PORT}/debug.html?debug=1`); await M.waitForFunction(() => window.__pal);
  await M.evaluate(() => { const P = __pal; P.pick.mode = 'understrip'; P.showPage('solo'); document.querySelector('[data-m5=understrip]').click() }); await M.waitForTimeout(600); await shot(M, 'play-card');
  // a phone held upright
  const Ph = await b.newPage({ ...devices['iPhone 13'] }); await run(Ph);
  await Ph.evaluate(() => { const P = __pal; P.player.max = P.player.hp = 1e6; for (const e of P.enemies) e.speed = 0 });
  await at(Ph, () => { pl.aim = { x: 0, y: 1 } }); await shot(Ph, 'phone-portrait');
  console.log('errors:', errors.length ? errors : 'none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
