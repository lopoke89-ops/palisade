// THE UNDERSTRIP M3: screenshots for the milestone's evidence folder (a tool, not in the suite). A seeded solo run jumped to
// Shelter 7 and Area 67: the hazards, the three new bosses in both stages with their warnings, the Collector's stock, the
// results card in the lift, and the end screen with the case's pay.
// node understrip_capture_m3.js OUT_DIR        (a server on PORT, default 8080, serving the built site)
const { chromium } = require('playwright'), fs = require('node:fs'), path = require('node:path');
const OUT = process.argv[2] || path.join(__dirname, 'out/understrip-m3-shots'), PORT = process.env.PORT || 8080;
fs.mkdirSync(OUT, { recursive: true });
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), errors = [];
  const p = await b.newPage({ viewport: { width: 1280, height: 800 }, deviceScaleFactor: 2 }); p.on('pageerror', e => errors.push(e.message));
  await p.goto(`http://localhost:${PORT}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal && __pal.ready);
  await p.evaluate(async () => { let s = 7; Math.random = () => (s = (s * 16807) % 2147483647) / 2147483647; const P = __pal; P.pick.mode = 'understrip'; P.showPage('solo'); document.getElementById('startBtn').click(); await new Promise(z => setTimeout(z, 500)); P.game.paused = true; P.player.max = P.player.hp = 1e7;
    window.step = (sec, each) => { for (let t = 0; t < sec; t += 1 / 30) { if (each) each(); P.game.paused = false; P.update(1 / 30); P.game.paused = true } };
    window.go = lv => { P.usChangeLevel(lv); for (const e of P.enemies) e.dead = true; step(.2) };
    window.arena = () => { const A = P.game.lay.arena, pl = P.player; pl.x = A.x + A.w / 2; pl.y = A.y + A.h - 3; pl.tp++; step(5.5) };
    window.near = (dx, dy) => { const B = P.enemies.find(e => e.type === 'boss' && !e.pilot), pl = P.player; pl.x = B.x + dx; pl.y = B.y + dy; pl.tp++ };
    window.hush = () => { for (const t of document.querySelectorAll('#toast,.toast'))t.hidden = true } });
  // draw a frozen moment: set it up, then render without play
  const draw = async (fn, frames = 16) => { await p.evaluate(async ([fn, frames]) => { const P = __pal, pl = P.player, U = P.game.us, L = P.game.lay, B = P.enemies.find(e => e.type === 'boss' && !e.pilot); eval(fn); for (let k = 0; k < frames; k++) { P.render(1 / 60); P.hud(1 / 60) } await new Promise(z => setTimeout(z, 200)) }, [fn, frames]) };
  const shot = async n => { await p.evaluate(() => { const t = document.getElementById('toast'); if (t) t.hidden = true }); await p.screenshot({ path: path.join(OUT, n + '.png') }); console.log(n) };
  // Shelter 7: a vent leaking by a radiation pocket
  await p.evaluate(() => { const P = __pal; for (let sd = 0; sd < 40; sd++) { P.US_RUN.seed = 900 + sd; go(3 + (sd & 1)); if (P.game.lay.vents.length) break } const L = P.game.lay, v = L.vents[0], pl = P.player; pl.x = v.cx + 1.5; pl.y = v.cy + 2.2; pl.tp++; pl.aim = { x: -.6, y: -.8 }; step(.5); P.game.us.vents[0].s = 2; P.game.us.vents[0].t = 5 });
  await draw(`for(const e of P.enemies)e.speed=0`); await shot('shelter7-gas');
  // Area 67: low gravity, tanks and an alarm's drones
  await p.evaluate(() => { const P = __pal; P.US_RUN.seed = 77; go(6); const H = P.US_HAZ, pl = P.player; for (let k = 0; k < H.length; k++)if (H[k] === 3) { pl.x = k % P.N + .5; pl.y = ((k / P.N) | 0) + 2; pl.tp++; break } pl.aim = { x: .7, y: -.7 }; step(.3); P.usDronePack(pl.x + 2.5, pl.y - 1.5, 4); for (const e of P.enemies) e.speed = 0; step(.2) });
  await draw(``); await shot('area67-drones');
  // the Custodian: the mop's wedge and an amber door; then stage 2's red light, gas quarter and turret line
  await p.evaluate(() => { go(5); arena(); near(2.2, 1.2); step(.3) });
  await draw(`B.st=63;B.stT=B.stM=.9;B.lx=pl.x;B.ly=pl.y;P.usBlastSet(0,1);P.usBlastSet(2,2)`); await shot('custodian-stage1');
  await p.evaluate(() => { const P = __pal, B = P.enemies.find(e => e.type === 'boss'); P.hurtEnemy(B, B.hp - B.max * .49, P.player.id); step(3.4) });
  await draw(`near(3,1);const A=L.arena;U.bfx=[{k:'gas',x:A.x+1,y:A.y+1,x1:A.x+12,y1:A.y+12,t:3,warn:2,T:10},{k:'turret',x:A.x+12,y:A.y+12,x1:pl.x,y1:pl.y,t:.3,warn:.8,T:.85},{k:'water',x:B.x,y:B.y,a:1,r:3,half:1.1,t:1,warn:0,T:3}]`); await shot('custodian-stage2');
  // the Gatekeeper: shield up and rockets falling; then the pilot's line and the suit's ground pound
  await p.evaluate(() => { go(8); arena(); near(3, 1); step(.3) });
  await draw(`B.ub=1;B.shT=4;B.aim={x:.7,y:.7};P.lobs.push({x0:B.x,y0:B.y,x1:pl.x+1,y1:pl.y,t:.4,T:1.1,R:1.2,power:.5},{x0:B.x,y0:B.y,x1:pl.x-1,y1:pl.y+1,t:.4,T:1.1,R:1.2,power:.5})`); await shot('gatekeeper-stage1');
  await p.evaluate(() => { const P = __pal, B = P.enemies.find(e => e.type === 'boss'); B.ub = 0; P.hurtEnemy(B, B.hp - B.max * .49, P.player.id); step(3.6) });
  await draw(`near(3,2);const pi=P.enemies.find(e=>e.pilot);if(pi){pi.x=B.x+2;pi.y=B.y-1;pi.st=74;pi.stT=pi.stM=.6;pi.lx=pl.x;pi.ly=pl.y};U.bfx=[{k:'circle',x:pl.x,y:pl.y,r:3,t:.6,warn:1.2,T:1.5}]`); await shot('gatekeeper-pilot');
  // the Visitor: a psychic ring and a tank's shadow; then the blackout, the well, a blink's flash and drones
  await p.evaluate(() => { go(9); arena(); near(2.5, 2); step(.3) });
  await draw(`U.bfx=[{k:'ring',x:B.x,y:B.y,t:1.1,warn:.8,T:2.3},{k:'circle',x:pl.x+1,y:pl.y+.5,r:1.3,t:.7,warn:1.2,T:1.5,tank:true}]`); await shot('visitor-stage1');
  await p.evaluate(() => { const P = __pal, B = P.enemies.find(e => e.type === 'boss'); P.hurtEnemy(B, B.hp - B.max * .49, P.player.id); step(3.4); P.usDronePack(B.x, B.y, 4); for (const e of P.enemies) if (e.type === 'drone') e.speed = 0 });
  await draw(`near(3,1.5);U.bfx=[{k:'well',x:B.x,y:B.y,t:1.5,warn:1,T:4},{k:'blink',x:pl.x-2,y:pl.y+1,t:.5,warn:.9,T:.9}]`); await shot('visitor-blackout');
  // the Collector's stock on the trade screen
  await p.evaluate(async () => { const P = __pal; P.US_RUN.seed = 7; for (let lv = 0; lv < 9; lv++) { go(lv); if (P.game.lay.merchants.some(m => m.kind === 'collector')) break } const m = P.game.lay.merchants.find(q => q.kind === 'collector'), pl = P.player; pl.x = m.x; pl.y = m.y + 1; pl.tp++; pl.sal = 900; step(.1); P.usInteract(pl, true); await new Promise(z => setTimeout(z, 400)) });
  await shot('collector'); await p.click('#armClose'); await p.evaluate(() => { __pal.game.paused = true });
  // the results card while the lift goes down
  await p.evaluate(() => { const P = __pal; go(4); const L = P.game.lay, pl = P.player; pl.x = L.exit[0]; pl.y = L.exit[1]; pl.tp++; step(3.4); step(1) });
  await draw(`P.usCardHud()`); await shot('lift-card');
  // the end: out of Area 67, and the case's pay (no account)
  await p.evaluate(async () => { const P = __pal; go(9); arena(); const B = P.enemies.find(e => e.type === 'boss'); for (let k = 0; k < 6 && !P.game.us.bossDown; k++) { for (const e of P.enemies) if (e.type === 'boss' && !e.dead) { e.inv = 0; P.hurtEnemy(e, e.max * .3, P.player.id) } step(3.5) }
    P.game.us.log = [[0, 12, 300, 2], [1, 14, 320, 1], [2, 9, 410, 3], [3, 16, 330, 2], [4, 11, 300, 1], [5, 8, 380, 2], [6, 18, 340, 2], [7, 12, 310, 1], [8, 9, 420, 3]]; P.game.us.stats.time = 3300; P.game.time = 3300; P.game.us.regions = 3;
    const L = P.game.lay, pl = P.player; for (const e of P.enemies) e.dead = true; pl.x = L.exit[0]; pl.y = L.exit[1]; pl.tp++; step(3.4); await new Promise(z => setTimeout(z, 2200)) });
  await shot('the-end');
  console.log('errors:', errors.length ? errors : 'none'); await b.close();
})();
