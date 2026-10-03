// v0.9.7 City Black Out online (yard-26): the guest sees the host's mode and city, the run's clock and stage, which POI is
// under attack, POIs lost (and the dark city), only the raiders near them (bosses always), and the POI summary comes back
// after the guest's own copy is wiped (what a rejoin relies on), and the READY UP stage waits for both players (v0.9.7.1).
// node blackout_network.js
const { chromium } = require('playwright'), assert = require('node:assert/strict'), fs = require('node:fs');
const Q = 'peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1', PORT = process.env.PORT || 8080;
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--disable-features=WebRtcHideLocalIpsWithMdns'] });
  const errors = [], out = {};
  const H = await b.newPage({ viewport: { width: 1100, height: 760 } }); H.on('pageerror', e => errors.push('H ' + e.message));
  const G = await (await b.newContext({ viewport: { width: 900, height: 700 } })).newPage(); G.on('pageerror', e => errors.push('G ' + e.message));
  await H.goto(`http://localhost:${PORT}/debug.html?${Q}`); await G.goto(`http://localhost:${PORT}/debug.html?${Q}`); await H.waitForTimeout(800);
  await H.click('[data-nav=multi]'); await H.click('[data-setup=rules]:visible'); await H.click('#setupSheet [data-m5=blackout]'); await H.click('#setupDone'); await H.click('#hostBtn');
  await H.waitForFunction(() => /^[A-Z0-9]{4}$/.test(document.getElementById('lCode').textContent), null, { timeout: 15000 });
  const code = await H.textContent('#lCode');
  await G.click('[data-nav=multi]'); await G.fill('#mCode', code); await G.click('#joinBtn');
  await G.waitForFunction(() => !document.getElementById('pg-lobby').hidden, null, { timeout: 15000 });
  out.proto = await G.evaluate(() => __pal.PROTO);
  await H.evaluate(()=>__pal.lobbyReadyAll());await H.click('#lStart'); await G.waitForFunction(() => document.getElementById('menu').hidden, null, { timeout: 8000 }); await H.waitForTimeout(600);
  await H.evaluate(() => { const P = __pal; window.holdIt = setInterval(() => { for (const q of P.players.values()) { q.max = 1e9; q.hp = Math.max(q.hp, 1e8) } P.core.max = 1e9; P.core.hp = 1e9; P.qm.hp = 1e9 }, 50) });
  out.mode = await G.evaluate(() => ({ mode: __pal.game.mode, map: __pal.game.map, N: __pal.N, cores: __pal.cores.length }));
  assert.equal(out.proto, 'yard-27'); assert.deepEqual(out.mode, { mode: 'blackout', map: 'city', N: 64, cores: 9 });
  // gathering ends: the first attack, on the same POI on both phones
  await H.evaluate(() => { __pal.game.timer = .05 });
  await G.waitForFunction(() => __pal.game.bo && __pal.game.bo.stage === 'attack', null, { timeout: 8000 });
  await G.waitForFunction(() => /ATTACK/.test(document.getElementById('phaseLab').textContent), null, { timeout: 5000 }).catch(() => {});
  out.attack = await Promise.all([H, G].map(pg => pg.evaluate(() => { const B = __pal.game.bo; return { ci: B.cur.ci, flags: __pal.cores.map(c => c.attack ? 1 : 0).join(''), label: document.getElementById('phaseLab').textContent } })));
  assert.equal(out.attack[0].ci, out.attack[1].ci); assert.equal(out.attack[0].flags, out.attack[1].flags); assert.match(out.attack[1].label, /ATTACK/);
  // what's near: a raider next to the guest arrives, one across the city doesn't; the boss always does
  await H.evaluate(() => { const P = __pal, g = [...P.players.values()].find(p => p.id !== 'host'); window.gid = g.id;
    const near = P.spawnEnemyAt('rifle', g.x + 2, g.y), far = P.spawnEnemyAt('rifle', g.x > 32 ? 3.5 : 60.5, g.y > 32 ? 3.5 : 60.5); window.nearId = near.id; window.farId = far.id;
    near.speed = 0; far.speed = 0 });
  await G.waitForTimeout(800);
  out.near = await G.evaluate(([n, f]) => ({ near: __pal.enemies.some(e => e.id === n), far: __pal.enemies.some(e => e.id === f), boss: __pal.enemies.some(e => e.type === 'boss') }), await H.evaluate(() => [window.nearId, window.farId]));
  assert.deepEqual(out.near, { near: true, far: false, boss: true });
  // the POI falls: lost on the guest too; the Power Station going dark darkens the guest's city
  await H.evaluate(() => { const P = __pal, B = P.game.bo; P.cores[B.cur.ci].hp = 0 });
  await G.waitForFunction(() => __pal.cores.some(c => c.lost), null, { timeout: 5000 });
  await H.evaluate(() => { __pal.game.dark = true });
  await G.waitForFunction(() => __pal.game.dark === true, null, { timeout: 5000 });
  out.lost = await Promise.all([H, G].map(pg => pg.evaluate(() => ({ lost: __pal.cores.map(c => c.lost ? 1 : 0).join(''), stage: __pal.game.bo.stage, held: __pal.game.bo.held, lostN: __pal.game.bo.lost }))));
  assert.deepEqual(out.lost[0], out.lost[1]); assert.equal(out.lost[1].stage, 'gap'); assert.equal(out.lost[1].lostN, 1);
  // the guest's copy wiped (a rejoin starts from nothing): the next snapshots put it all back
  await G.evaluate(() => { __pal.game.bo = null; for (const c of __pal.cores) c.lost = false; __pal.game.dark = false });
  await G.waitForFunction(() => __pal.game.bo && __pal.cores.some(c => c.lost) && __pal.game.dark, null, { timeout: 5000 });
  out.restored = await G.evaluate(() => ({ lost: __pal.cores.map(c => c.lost ? 1 : 0).join(''), stage: __pal.game.bo.stage }));
  assert.equal(out.restored.lost, out.lost[0].lost);
  // the clocks agree
  const [ht, gt] = await Promise.all([H, G].map(pg => pg.evaluate(() => __pal.game.bo.t)));
  assert.ok(Math.abs(ht - gt) < 1.2, 'quiet clock in step ' + ht + ' ' + gt);
  // the final push and the Destroyer reach the guest
  await H.evaluate(() => { const B = __pal.game.bo; B.order.length = B.n; B.t = .05 });
  // v0.9.7.1: READY UP first; nobody can force it, the push starts when both are ready
  await G.waitForFunction(() => __pal.game.bo.stage === 'ready', null, { timeout: 6000 });
  await H.evaluate(() => __pal.boReadyPress()); await G.waitForTimeout(700);
  out.readyHalf = await Promise.all([H, G].map(pg => pg.evaluate(() => ({ stage: __pal.game.bo.stage, count: __pal.boReadyCount().join('/'), label: document.getElementById('phaseVal').textContent }))));
  assert.equal(out.readyHalf[0].stage, 'ready', 'one of two ready: still waiting'); assert.equal(out.readyHalf[1].count, '1/2', 'the guest sees 1/2');
  await G.evaluate(() => __pal.boReadyPress());
  await G.waitForFunction(() => __pal.game.bo.stage === 'push', null, { timeout: 6000 });
  await H.evaluate(() => { __pal.game.bo.push.t = 120.2 });
  await G.waitForFunction(() => __pal.enemies.some(e => e.boss === 'destroyer'), null, { timeout: 6000 });
  out.push = await G.evaluate(() => ({ stage: __pal.game.bo.stage, dest: __pal.game.bo.push.dest }));
  assert.deepEqual(out.push, { stage: 'push', dest: true });
  fs.writeFileSync(__dirname + '/out/blackout_network.json', JSON.stringify({ out, errors }, null, 2)); assert.deepEqual(errors, []);
  console.log(JSON.stringify(out)); console.log('errors: none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
