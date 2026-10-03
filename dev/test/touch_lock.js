// v0.9.3.7 touch aim assist: grenades and rockets on a touch screen lock onto the nearest raider 6+ tiles away with a
// clear line; closer raiders and raiders behind walls are ignored; mouse aim and PvP stay manual; a guest's locked
// throw reaches the host as an ordinary target point. node touch_lock.js
const { chromium } = require('playwright'), assert = require('node:assert/strict'), fs = require('node:fs');
const PORT = process.env.PORT || 8080, Q = 'peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1';
const layout = () => { const P = __pal, N = P.N; P.walls.fill(null); for (const e of P.enemies) e.dead = true; P.enemies.length = 0; P.game.queue = [];
  for (let j = 2; j < N - 2; j++) { const y = j + .5; if (Math.abs(j - P.core.j) < 2) continue;
    const p = { x: 1.5, y }, C = { x: 10.5, y }; if (P.lockClear(p.x, p.y, C.x, C.y) && P.lockClear(p.x, p.y, 4.5, y)) return { j, y } } return null };
const place = (L) => { const P = __pal, p = P.player; p.x = 1.5; p.y = L.y; p.alive = true; p.nades = 3;
  const mk = (x, y) => { P.spawnEnemyAt('rifle', x, y); const e = P.enemies[P.enemies.length - 1]; e.speed = 0; e.hp = 1e6; e.max = 1e6; return e };
  const near = mk(4.5, L.y);                                   // 3 tiles: too close, ignored
  P.walls[L.j * P.N + 6] = P.makeWall(0, false, 1); const hid = mk(8.5, L.y);   // 7 tiles, behind a wall: ignored
  let far = null;                                              // 7.2-7.9 tiles (in grenade and rocket reach), clear line, another row
  for (const dj of [3, -3, 4, -4, 2, -2]) { const j2 = L.j + dj; if (j2 < 1 || j2 > P.N - 2) continue;
    for (let x = 5.5; x < P.N - 1 && !far; x += .5) { const y2 = j2 + .5, d = Math.hypot(x - 1.5, y2 - L.y); if (d > 7.2 && d <= 7.9 && P.lockClear(1.5, L.y, x, y2)) far = mk(x, y2) } if (far) break }
  return { near: near.id, far: far && far.id, hid: hid.id, hidClear: P.lockClear(p.x, p.y, 8.5, L.y) } };
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--disable-features=WebRtcHideLocalIpsWithMdns'] }), errors = [], out = {};
  const p = await b.newPage({ viewport: { width: 900, height: 700 } }); p.on('pageerror', e => errors.push(e.message));
  await p.goto(`http://localhost:${PORT}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal);
  await p.click('[data-go=solo]'); await p.click('#startBtn'); await p.waitForTimeout(400);
  const L = await p.evaluate(layout); assert.ok(L, 'found a clear test row');
  const ids = await p.evaluate(place, L); out.ids = ids; assert.equal(ids.hidClear, false, 'the wall blocks the hidden raider'); assert.ok(ids.far, 'placed a clear far raider');
  out.solo = await p.evaluate(ids => { const P = __pal, p = P.player; P.game.paused = true;
    P.touchModeSet = false; const mouse = P.touchLock(p, 'nade');
    P.touchModeSet = true; const nade = P.touchLock(p, 'nade'), rocket = P.touchLock(p, 'rocket');
    P.lobs.length = 0; p.ncd = 0; P.localNade(); const lob = P.lobs[0];
    return { mouse: mouse && mouse.id, nade: nade && nade.id, rocket: rocket && rocket.id, lob: lob && [lob.x1, lob.y1], far: P.enemies.find(e => e.id === ids.far) && [P.enemies.find(e => e.id === ids.far).x, P.enemies.find(e => e.id === ids.far).y], px: [p.x, p.y] } }, ids);
  assert.equal(out.solo.mouse, null, 'mouse aim is never assisted'); assert.equal(out.solo.nade, ids.far); assert.equal(out.solo.rocket, ids.far);
  // the grenade flies toward the locked raider (clamped to throw range), along its row
  {const [lx,ly]=out.solo.lob,[fx,fy]=out.solo.far,[px,py]=out.solo.px,cross=(lx-px)*(fy-py)-(ly-py)*(fx-px);assert.ok(Math.abs(cross)<.2&&Math.hypot(lx-px,ly-py)>6,JSON.stringify(out.solo))}   // on the line to the far raider, thrown full range
  // rocket (soldier) heads at the locked raider
  out.rocket = await p.evaluate(ids => { const P = __pal, p = P.player, f = P.enemies.find(e => e.id === ids.far); P.rockets.length = 0; p.rk = 3; p.rkCd = 0; P.localAbility(); const r = P.rockets[0], l = Math.hypot(f.x - p.x, f.y - p.y); return r && +((r.vx * (f.x - p.x) + r.vy * (f.y - p.y)) / (Math.hypot(r.vx, r.vy) * l)).toFixed(3) }, ids);
  assert.ok(out.rocket > .999, 'rocket heads straight at the locked raider ' + out.rocket);
  // nothing valid (only the close raider left) -> manual aim (facing direction)
  out.none = await p.evaluate(ids => { const P = __pal; for (const e of P.enemies) if (e.id !== ids.near) e.dead = true; return P.touchLock(P.player, 'nade') }, ids);
  assert.equal(out.none, null);
  await p.screenshot({ path: __dirname + '/out/touch_lock.png' });
  // guest on a touch screen: the locked point goes to the host as an ordinary throw
  const H = await b.newPage({ viewport: { width: 900, height: 700 } }), G = await b.newPage({ viewport: { width: 900, height: 700 } });
  for (const [x, n] of [[H, 'H'], [G, 'G']]) { x.on('pageerror', e => errors.push(n + ' ' + e.message)); await x.goto(`http://localhost:${PORT}/debug.html?${Q}`); await x.waitForFunction(() => window.__pal) }
  await H.click('[data-nav=multi]'); await H.click('#hostBtn'); await H.waitForFunction(() => /^[A-Z0-9]{4}$/.test(document.getElementById('lCode').textContent), null, { timeout: 15000 });
  const code = await H.textContent('#lCode'); await G.click('[data-nav=multi]'); await G.fill('#mCode', code); await G.click('#joinBtn');
  await G.waitForSelector('#pg-lobby:not([hidden])', { timeout: 15000 }); await H.evaluate(()=>__pal.lobbyReadyAll());await H.click('#lStart'); await G.waitForFunction(() => __pal.NET.inGame && document.getElementById('menu').hidden, null, { timeout: 10000 });
  await H.waitForTimeout(600);
  const HL = await H.evaluate(layout); await H.evaluate(L => { const P = __pal, g = [...P.players.values()].find(q => q.id !== 'host'); g.x = 1.5; g.y = L.y; g.nades = 3; g.ncd = 0; P.game.phase = 'build'; P.game.timer = 999;
    P.spawnEnemyAt('rifle', 8.5, L.y); const e = P.enemies[P.enemies.length - 1]; e.speed = 0; e.hp = 1e6; e.max = 1e6; P.lobs.length = 0 }, HL);
  await G.waitForFunction(y => __pal.enemies.length >= 1 && Math.abs(__pal.player.y - y) < .3, HL.y, { timeout: 5000 });
  await G.evaluate(() => { __pal.touchModeSet = true; __pal.localNade() });
  await H.waitForFunction(() => __pal.lobs.length > 0, null, { timeout: 5000 });
  out.guest = await H.evaluate(() => { const l = __pal.lobs[0]; return [l.x0, l.y0, l.x1, l.y1].map(v => +v.toFixed(2)) });
  assert.ok(Math.abs(out.guest[3] - HL.y) < .1 && out.guest[2] > out.guest[0] + 5, JSON.stringify(out.guest));
  fs.writeFileSync(__dirname + '/out/touch_lock.json', JSON.stringify({ out, errors }, null, 2)); assert.deepEqual(errors, []);
  console.log(JSON.stringify(out)); console.log('errors: none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
