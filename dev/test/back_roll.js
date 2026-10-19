// v0.11.0 (yard-30): the roll, every class. Solo: V rolls 2 tiles straight back from the aim when standing still and the
// way you're moving otherwise, the cooldown holds
// for 3 s, a wall stops it, a bullet misses during the roll's safe window and hits outside it, and you can't shoot
// while rolling. Online: a guest's roll travels on the host (the host lets it through its speed check), a second roll
// inside the cooldown is refused by the host, and the guest sees the host roll. node back_roll.js
const { chromium } = require('playwright'), assert = require('node:assert/strict'), fs = require('node:fs'), { ready, frames, synced } = require('./lib');
const Q = 'peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1', PORT = process.env.PORT || 8080, URL = `http://localhost:${PORT}/debug.html?${Q}`;
const sleep = ms => new Promise(r => setTimeout(r, ms));
// an open lane: 3 tiles clear west of the spot, nothing solid, no wall
const OPEN = () => { const P = __pal; for (let j = 4; j < P.N - 4; j++) for (let i = 6; i < P.N - 4; i++) { let ok = true; for (let k = -4; k <= 1 && ok; k++) for (const dj of [-1, 0, 1]) { const a = i + k, b = j + dj; if (P.solidTileHook(a, b) || P.walls[a + b * P.N]) ok = false } if (ok) return [i + .5, j + .5] } return null };
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--disable-features=WebRtcHideLocalIpsWithMdns'] });
  const errors = [], out = {};
  const p = await b.newPage({ viewport: { width: 1280, height: 760 } }); p.on('pageerror', e => errors.push('S ' + e.message));
  await p.goto(URL); await ready(p);
  await p.click('[data-go=solo]'); await p.click('#startBtn'); await frames(p, 3);
  await p.evaluate(() => { const P = __pal; window.hold = setInterval(() => { P.player.hp = Math.max(P.player.hp, 1); P.core.hp = P.core.max }, 30) });
  const spot = await p.evaluate(OPEN); assert.ok(spot, 'an open lane');
  const place = () => p.evaluate(s => { const q = __pal.player; q.x = s[0]; q.y = s[1]; q.dgCd = 0; q.dgE = -1 }, spot);
  // V: aim east (mouse to the right of the soldier), roll west
  await place();
  await p.evaluate(() => { const q = __pal.player, s = __pal.scr(q.x + 3, q.y); __pal.setMouse(s[0], s[1], false) });
  await frames(p, 2);
  out.aim = await p.evaluate(() => __pal.player.aim);
  const x0 = await p.evaluate(() => [__pal.player.x, __pal.player.y]);
  await p.keyboard.press('v');
  out.started = await p.evaluate(() => ({ e: __pal.player.dgE, cd: __pal.player.dgCd, fire: __pal.player.fireIn }));
  await sleep(750);
  const x1 = await p.evaluate(() => [__pal.player.x, __pal.player.y, __pal.player.dgE]);
  out.travel = Math.hypot(x1[0] - x0[0], x1[1] - x0[1]);
  out.dir = [(x1[0] - x0[0]) / out.travel, (x1[1] - x0[1]) / out.travel];
  assert.ok(out.started.e >= 0 && out.started.cd > 2.9, 'V starts a roll and its 3 s cooldown ' + JSON.stringify(out.started));
  assert.ok(Math.abs(out.travel - 2) < .06, `2 tiles (${out.travel.toFixed(3)})`);
  assert.ok(out.dir[0] * out.aim.x + out.dir[1] * out.aim.y < -.98, 'straight back from the aim ' + JSON.stringify(out));
  assert.equal(x1[2], -1, 'the roll is over after 0.55 s');
  // the cooldown: V again does nothing until it runs out
  await p.keyboard.press('v');
  out.blocked = await p.evaluate(() => ({ e: __pal.player.dgE, cd: __pal.player.dgCd }));
  assert.equal(out.blocked.e, -1, 'no second roll inside the cooldown');
  // the right mouse button rolls too (cooldown cleared)
  await place(); await frames(p, 1);
  await p.evaluate(() => { const q = __pal.player, s = __pal.scr(q.x + 3, q.y); __pal.setMouse(s[0], s[1], false) }); await frames(p, 2);
  const s = await p.evaluate(() => __pal.scr(__pal.player.x + 3, __pal.player.y));
  await p.mouse.click(s[0], s[1], { button: 'right' });
  out.rightButton = await p.evaluate(() => __pal.player.dgE >= 0);
  assert.ok(out.rightButton, 'the right mouse button rolls');
  await sleep(700);
  // moving, the roll goes the way you walk, not back from the aim. Aim west (a back roll would go east) and
  // walk up-left on screen (mostly west on the map): the roll follows the walk, toward the aim
  await place(); await frames(p, 1);
  await p.evaluate(() => { const q = __pal.player, s = __pal.scr(q.x - 3, q.y); __pal.setMouse(s[0], s[1], false) }); await frames(p, 2);
  await p.keyboard.down('a'); await p.keyboard.down('w'); await sleep(200);
  const m0 = await p.evaluate(() => [__pal.player.x, __pal.player.y]);
  await p.keyboard.press('v');
  out.moving = await p.evaluate(() => ({ e: __pal.player.dgE, d: [__pal.player.dgX, __pal.player.dgY], walk: __pal.player.moveDir, aim: __pal.player.aim }));
  await p.waitForFunction(() => __pal.player.dgE < 0, null, { timeout: 5000 });   // the game clock runs on frames: wait for the landing
  const m1 = await p.evaluate(() => [__pal.player.x, __pal.player.y]);
  await p.keyboard.up('w'); await p.keyboard.up('a');
  const ml = Math.hypot(m1[0] - m0[0], m1[1] - m0[1]), md = [(m1[0] - m0[0]) / ml, (m1[1] - m0[1]) / ml];
  assert.ok(out.moving.e >= 0, 'V rolls while walking ' + JSON.stringify(out.moving));
  assert.ok(out.moving.d[0] * out.moving.walk.x + out.moving.d[1] * out.moving.walk.y > .99, 'the roll takes the walking direction ' + JSON.stringify(out.moving));
  assert.ok(md[0] * out.moving.walk.x + md[1] * out.moving.walk.y > .97 && md[0] * out.moving.aim.x + md[1] * out.moving.aim.y > 0 && ml > 1.9,
    `and travels that way, toward the aim, not back from it (${ml.toFixed(2)} tiles, ${JSON.stringify(md)})`);
  await sleep(300);
  // a wall one tile behind stops it, with no catching up
  await place();
  await p.evaluate(() => { const P = __pal, q = P.player, i = Math.floor(q.x) - 1, j = Math.floor(q.y); P.walls[i + j * P.N] = P.makeWallHook(2, false); window.wx = i });
  const w0 = await p.evaluate(() => __pal.player.x);
  await p.evaluate(() => __pal.localRoll()); await sleep(750);
  out.wall = { from: w0, to: await p.evaluate(() => __pal.player.x), wallRight: await p.evaluate(() => window.wx + 1) };
  assert.ok(out.wall.to > out.wall.wallRight + .2 && w0 - out.wall.to < .5, 'the wall stops the roll ' + JSON.stringify(out.wall));
  await p.evaluate(() => { const P = __pal; P.walls[window.wx + Math.floor(P.player.y) * P.N] = null });
  // bullets: a raider's round misses inside the safe window and hits outside it
  const shot = inWindow => p.evaluate(async inWindow => {
    const P = __pal, q = P.player; q.dgCd = 0; const e = P.spawnEnemyAt('rifle', q.x + 1.6, q.y); e.speed = 0; e.cd = 99; clearInterval(window.hold);
    q.hp = q.max; const hp0 = q.hp;
    const keep = setInterval(() => { if (inWindow) { q.dgE = .2; q.dgX = 0; q.dgY = 0 } else q.dgE = -1; e.cd = 99 }, 5);
    if (inWindow) { q.dgE = .2; q.dgX = 0; q.dgY = 0 }
    P.fire(e, Math.atan2(q.y - e.y, q.x - e.x), 1, { dmg: 10, speed: 22, range: 9, cd: 1 });
    await new Promise(r => setTimeout(r, 300)); clearInterval(keep); q.dgE = -1;
    const hp1 = q.hp; e.hp = 0; e.dead = true; P.enemies.splice(P.enemies.indexOf(e), 1);
    window.hold = setInterval(() => { q.hp = Math.max(q.hp, 1); P.core.hp = P.core.max }, 30);
    return { safe: P.rollSafe({ dgE: .2 }), hp0, hp1 } }, inWindow);
  out.bulletRolling = await shot(true); out.bulletStanding = await shot(false);
  assert.equal(out.bulletRolling.hp1, out.bulletRolling.hp0, 'a bullet misses a rolling soldier ' + JSON.stringify(out.bulletRolling));
  assert.ok(out.bulletStanding.hp1 < out.bulletStanding.hp0, 'and hits one who is not ' + JSON.stringify(out.bulletStanding));
  // no shooting while rolling: the trigger is held, no round leaves
  await place(); await frames(p, 1);
  out.fireWhileRolling = await p.evaluate(async () => { const P = __pal, q = P.player; q.dgCd = 0; P.localRoll(); const n0 = P.bullets.length;
    const s = P.scr(q.x + 3, q.y); P.setMouse(s[0], s[1], true); await new Promise(r => setTimeout(r, 200)); const n1 = P.bullets.filter(b => b.own === q.id).length; P.setMouse(s[0], s[1], false); return { rolling: P.rolling(q) || q.dgE === -1, shots: n1 } });
  assert.equal(out.fireWhileRolling.shots, 0, 'no rounds while rolling ' + JSON.stringify(out.fireWhileRolling));
  // the HUD shows the button and the key hint
  out.hud = await p.evaluate(() => ({ btn: !document.getElementById('rollBtn').hidden, label: document.getElementById('rollN').textContent, keys: document.getElementById('keys').textContent }));
  assert.ok(out.hud.btn, 'the ROLL button');
  await p.screenshot({ path: `${__dirname}/out/back_roll_solo.png` });
  await p.close();

  // online: the guest rolls; the host lets it travel and keeps the cooldown; the guest sees the host roll
  const H = await b.newPage({ viewport: { width: 1100, height: 760 } }); H.on('pageerror', e => errors.push('H ' + e.message));
  const G = await (await b.newContext({ viewport: { width: 900, height: 700 } })).newPage(); G.on('pageerror', e => errors.push('G ' + e.message));
  await H.goto(URL); await G.goto(URL); await ready(H); await ready(G);
  await H.click('[data-nav=multi]'); await H.click('#hostBtn');
  await H.waitForFunction(() => /^[A-Z0-9]{4}$/.test(document.getElementById('lCode').textContent), null, { timeout: 15000 });
  const code = await H.textContent('#lCode');
  await G.click('[data-nav=multi]'); await G.fill('#mCode', code); await G.click('#joinBtn');
  await G.waitForFunction(() => !document.getElementById('pg-lobby').hidden, null, { timeout: 15000 });
  out.proto = await G.evaluate(() => __pal.PROTO);
  assert.equal(out.proto, 'yard-30');
  await H.evaluate(() => __pal.lobbyReadyAll()); await H.click('#lStart'); await G.waitForFunction(() => document.getElementById('menu').hidden, null, { timeout: 8000 }); await synced(H, G);
  await H.evaluate(() => { const P = __pal; window.hold = setInterval(() => { for (const q of P.players.values()) { q.max = 1e9; q.hp = Math.max(q.hp, 1e8) } P.core.max = 1e9; P.core.hp = 1e9 }, 50) });
  const gspot = await H.evaluate(OPEN);
  const gid = await G.evaluate(() => __pal.player.id);
  await G.evaluate(s => { const q = __pal.player; q.x = s[0]; q.y = s[1]; q.tp = q.tp }, gspot);
  await H.evaluate(([s, id]) => { const q = __pal.players.get(id); q.x = s[0]; q.y = s[1] }, [gspot, gid]);
  await sleep(400);
  await G.evaluate(() => { const q = __pal.player, s = __pal.scr(q.x + 3, q.y); __pal.setMouse(s[0], s[1], false) }); await frames(G, 3); await sleep(200);
  const h0 = await H.evaluate(id => { const q = __pal.players.get(id); return [q.x, q.y, q.tp] }, gid);
  await G.keyboard.press('v');
  await H.waitForFunction(id => __pal.players.get(id).dgE >= 0, gid, { timeout: 3000 });
  out.hostCd = await H.evaluate(id => __pal.players.get(id).dgCd, gid);
  // a second roll message inside the cooldown is refused by the host (it does not restart the roll)
  await sleep(120);
  await G.evaluate(() => __pal.NET.toHost({ t: 'dg', x: -1, y: 0 }));
  await sleep(120);
  out.second = await H.evaluate(id => __pal.players.get(id).dgE, gid);
  await sleep(900);
  const h1 = await H.evaluate(id => { const q = __pal.players.get(id); return [q.x, q.y, q.tp] }, gid);
  out.guestTravelOnHost = Math.hypot(h1[0] - h0[0], h1[1] - h0[1]);
  assert.ok(out.hostCd > 2.5, 'the host started the guest\'s cooldown');
  assert.ok(out.second === -1 || out.second > .15, 'a second roll inside the cooldown does not restart it (' + out.second + ')');
  assert.ok(out.guestTravelOnHost > 1.85 && out.guestTravelOnHost < 2.3, `the guest's roll travels on the host (${out.guestTravelOnHost.toFixed(2)})`);
  assert.equal(h1[2], h0[2], 'without a rejected move (tp unchanged)');
  // the host rolls; the guest sees it
  await H.evaluate(s => { const q = __pal.player; q.x = s[0] + .01; q.y = s[1] + 2; q.dgCd = 0; q.aim = { x: 1, y: 0 }; __pal.localRoll() }, gspot);
  await G.waitForFunction(() => [...__pal.players.values()].some(q => q !== __pal.player && q.dgE >= 0), null, { timeout: 3000 });
  out.guestSawHost = true;
  await G.screenshot({ path: `${__dirname}/out/back_roll_guest.png` });
  fs.writeFileSync(`${__dirname}/out/back_roll.json`, JSON.stringify({ out, errors }, null, 2));
  assert.deepEqual(errors, []);
  console.log(JSON.stringify(out)); console.log('errors: none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
