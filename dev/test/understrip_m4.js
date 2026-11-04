// THE UNDERSTRIP M4 polish: first-time tips (a shrine, a merchant, the boss gate, your dropped salvage) each once per
// device, skippable, gone by themselves, never with the Tips setting off, and on a guest too; Reduce Motion steadies the
// flickering lights and softens shakes; the top brightness step marks every raider above the darkness; raiders' health by
// region and squad; drones at half speed in your light; Area 67's hum on the music volume, and none elsewhere.
const { chromium } = require('playwright'), assert = require('node:assert/strict');
(async () => {
 const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), errors = [];
 const ctx = await b.newContext({ viewport: { width: 1100, height: 760 }, reducedMotion: 'reduce' }), p = await ctx.newPage(); p.on('pageerror', e => errors.push(e.message));
 await p.goto(`http://localhost:${process.env.PORT || 8080}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal && __pal.ready);
 const r = await p.evaluate(async () => {
  let s = 3; Math.random = () => (s = (s * 16807) % 2147483647) / 2147483647; localStorage.removeItem('palisade.usTips.v1');
  const P = __pal; P.pick.mode = 'understrip'; P.showPage('solo'); document.getElementById('startBtn').click(); await new Promise(z => setTimeout(z, 500));
  const g = () => P.game, U = () => P.game.us, L = () => P.game.lay, pl = P.player, r = {}; g().paused = true; pl.max = pl.hp = 1e6;
  const shown = [], tip = () => document.getElementById('tip').hidden ? '' : document.getElementById('tipText').textContent;
  let last = '', since = 0, longest = 0;
  const step = (sec) => { for (let t = 0; t < sec; t += 1 / 30) { g().paused = false; P.update(1 / 30); g().paused = true; P.hud(1 / 30); const now = tip();
    if (now !== last) { if (last && !/Lucky Juice/.test(last)) longest = Math.max(longest, since); if (now) shown.push(now.split(':')[0].split(' ').slice(0, 2).join(' ')); last = now; since = 0 } else since += 1 / 30 } };
  const tp = (x, y) => { pl.x = x; pl.y = y; pl.tp++ };
  for (const e of P.enemies) e.dead = true;
  r.opening = tip(); step(15); r.openingGone = tip() === '';
  const S = L().shrines.find(q => !q.arena); tp(S.x + 1, S.y + 1); step(20); tp(S.x + 1.2, S.y + 1); step(10);   // the shrine (and the Keeper beside it), twice
  const M = L().merchants[0]; tp(M.x, M.y + 1.2); step(.3); step(10);
  pl.sal = 40; P.usDrop(pl); tp(S.x + 1, S.y + 1); step(.3); r.beforeSkip = tip(); document.getElementById('tip').click(); r.skipped = tip() === ''; step(10);
  P.usChangeLevel(2); for (const e of P.enemies) e.dead = true; const G = L().gate[0]; tp(G[0] + .5, G[1] + 2.5); step(10);
  r.shown = shown; r.longest = +longest.toFixed(1);
  r.seen = JSON.parse(localStorage.getItem('palisade.usTips.v1') || '[]').sort();
  // Tips off: nothing
  localStorage.removeItem('palisade.usTips.v1'); P.usTipsLoad && 0; P.cfg.tips = false; step(10); tp(G[0] + .5, G[1] + 2.4); step(.3); r.tipsOff = tip(); P.cfg.tips = true;
  // Reduce Motion: Shelter 7's tubes stay on, Area 67's failing lights hold steady, shakes are a third
  r.rm = matchMedia('(prefers-reduced-motion: reduce)').matches;
  P.usChangeLevel(4); const lamps2 = new Set(); for (let k = 0; k < 40; k++) { g().time += .13; lamps2.add(P.usLampOn(0)) } r.lamps2 = [...lamps2];
  P.usChangeLevel(7); const lamps3 = new Set(); for (let k = 0; k < 40; k++) { g().time += .13; lamps3.add(P.usLampOn(0)) } r.lamps3 = [...lamps3];
  P.shakeReset && P.shakeReset(); const sh0 = P.shake; P.addShake(pl.x, pl.y, 8); r.shake = +(P.shake - sh0).toFixed(2);
  // the top brightness step marks raiders above the darkness
  const ink = () => { const c = document.querySelector('canvas'), x = c.getContext('2d'), d = x.getImageData(0, 0, c.width, c.height).data; let n = 0; for (let k = 0; k < d.length; k += 16) if (d[k] > 200 && d[k + 1] > 90 && d[k + 1] < 150 && d[k + 2] < 120) n++; return n };
  P.usChangeLevel(3); for (const e of P.enemies) if (Math.hypot(e.x - pl.x, e.y - pl.y) > 9) e.dead = true; const keep = P.spawnEnemyAt('rifle', pl.x + 2, pl.y - 2.5); keep.us = { home: [keep.x, keep.y], st: 'idle', sid: 0, t: 0, look: 0 }; keep.speed = 0; pl.aim = { x: -1, y: 0 };
  P.render(1 / 60); const strokes = br => { P.cfg.usBright = br; return P.usBrightMarks() };
  step(1); for (let k = 0; k < 30; k++) P.render(1 / 30); r.marks = [strokes(0), strokes(2), strokes(3)]; P.cfg.usBright = 0;
  // health by region and squad
  P.usChangeLevel(0); const e1 = P.spawnEnemyAt('rifle', pl.x, pl.y); P.usChangeLevel(3); const e2 = P.spawnEnemyAt('rifle', pl.x, pl.y); P.usChangeLevel(6); const e3 = P.spawnEnemyAt('rifle', pl.x, pl.y);
  const q = P.makePlayer('bot1', 'Bot', 'soldier', 1, '', ''); P.players.set('bot1', q); const e4 = P.spawnEnemyAt('rifle', pl.x, pl.y); P.players.delete('bot1');
  r.hp = [e1, e2, e3, e4].map(e => +(e.max / P.ETYPES.rifle.hp).toFixed(3));
  // drones: half speed in your light
  P.usChangeLevel(6); for (const e of P.enemies) e.dead = true; step(.1);
  const mk = (x, y) => { P.usDronePack(x, y, 1); return P.enemies.filter(e => e.type === 'drone' && !e.dead).pop() };
  pl.aim = { x: 1, y: 0 }; const lit = mk(pl.x + 3, pl.y), x0 = lit.x; lit.litT = 0; P.usDroneTick(lit, .5); r.litMove = +Math.abs(lit.x - x0).toFixed(3);
  pl.aim = { x: -1, y: 0 }; const dk = mk(pl.x + 3, pl.y), x1 = dk.x; dk.litT = 0; P.usDroneTick(dk, .5); r.darkMove = +Math.abs(dk.x - x1).toFixed(3);
  // Area 67's hum
  P.cfg.music = .8; P.initAudio && P.initAudio(); await new Promise(z => setTimeout(z, 50)); P.usAmbience(); r.hum3 = P.US_AMB ? +P.US_AMB.want.toFixed(3) : null;
  P.usChangeLevel(3); P.usAmbience(); r.hum2 = P.US_AMB ? +P.US_AMB.want.toFixed(3) : null;
  return r });
 console.log(JSON.stringify(r, null, 1));
 assert.match(r.opening, /Lucky Juice/); assert.ok(r.openingGone, 'the opening line goes once you\'re moving');
 assert.deepEqual(r.shown.filter(t => t !== 'C drinks').sort(), ['A MERCHANT', 'NEON SHRINE', 'THE BOSS', 'YOUR SALVAGE'], 'each tip once: ' + r.shown);
 assert.ok(r.longest <= 9.2, 'each goes by itself within 9 s: ' + r.longest); assert.match(r.beforeSkip, /YOUR SALVAGE/); assert.ok(r.skipped, 'a tap skips it');
 assert.deepEqual(r.seen, ['gate', 'merchant', 'salvage', 'shrine']); assert.equal(r.tipsOff, '', 'the Tips setting turns them off');
 assert.ok(r.rm); assert.deepEqual(r.lamps2, [1], 'Shelter 7\'s tubes hold steady'); assert.deepEqual(r.lamps3, [.7], 'Area 67\'s failing lights hold steady (dimmer)');
 assert.ok(r.shake > 0 && r.shake < 8 * .5, 'shakes softened: ' + r.shake);
 assert.ok(r.marks[0] === 0 && r.marks[1] === 0 && r.marks[2] >= 1, 'only the top brightness step marks raiders: ' + r.marks);
 assert.deepEqual(r.hp, [1, 1.2, 1.4, 1.568], 'x1 / x1.2 / x1.4 by region, +12% for a second player');
 assert.ok(r.litMove > 0 && Math.abs(r.litMove * 2 - r.darkMove) < .05, `half speed in the light: ${r.litMove} vs ${r.darkMove}`);
 assert.ok(r.hum3 > 0, 'Area 67 hums'); assert.equal(r.hum2, 0, 'Shelter 7 has its music instead');
 console.log('errors:', errors.length ? errors : 'none'); await b.close(); if (errors.length) process.exit(1);
})();
