// v0.9.4.0 Blitzkrieg Rush online (yard-19): the guest sees the host's mode, Final Blitz clock, Blitzkrieg bosses, arcs and
// napalm, the evac site and extract progress; each player's own evacuation decides their result (guest out = EVACUATED,
// host left behind = LEFT BEHIND), the guest's no-account locker gets its Blitzkrieg Cases, and an extracted player who
// drops and comes back is still out. node blitz_network.js
const { chromium } = require('playwright'), assert = require('node:assert/strict'), fs = require('node:fs'), { ready, frames, synced } = require('./lib');
const Q = 'peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1', PORT = process.env.PORT || 8080;
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--disable-features=WebRtcHideLocalIpsWithMdns'] });
  const errors = [], out = {};
  const H = await b.newPage({ viewport: { width: 1100, height: 760 } }); H.on('pageerror', e => errors.push('H ' + e.message));
  const G = await (await b.newContext({ viewport: { width: 900, height: 700 } })).newPage(); G.on('pageerror', e => errors.push('G ' + e.message));
  await H.goto(`http://localhost:${PORT}/debug.html?${Q}`); await G.goto(`http://localhost:${PORT}/debug.html?${Q}`); await ready(H); await ready(G);
  await H.click('[data-nav=multi]'); await H.click('[data-setup=rules]:visible'); await H.click('#setupSheet [data-m5=blitz]'); await H.click('#setupDone'); await H.click('#hostBtn');
  await H.waitForFunction(() => /^[A-Z0-9]{4}$/.test(document.getElementById('lCode').textContent), null, { timeout: 15000 });
  const code = await H.textContent('#lCode');
  await G.click('[data-nav=multi]'); await G.fill('#mCode', code); await G.click('#joinBtn');
  await G.waitForFunction(() => !document.getElementById('pg-lobby').hidden, null, { timeout: 15000 });
  out.proto = await G.evaluate(() => __pal.PROTO || null);
  await H.evaluate(()=>__pal.lobbyReadyAll());await H.click('#lStart'); await G.waitForFunction(() => document.getElementById('menu').hidden, null, { timeout: 8000 }); await synced(H, G);
  await H.evaluate(() => { const P = __pal; window.holdIt = setInterval(() => { for (const q of P.players.values()) { q.max = 1e9; q.hp = Math.max(q.hp, 1e8) } P.core.max = 1e9; P.core.hp = 1e9; P.qm.hp = 1e9; for (const e of P.enemies) if (e.type === 'boss') e.hp = e.max }, 50) });
  out.mode = await G.evaluate(() => ({ mode: __pal.game.mode, waves: __pal.game.waves }));
  assert.deepEqual(out.mode, { mode: 'blitz', waves: 15 });
  // the Final Blitz: clock, bosses, an arc and napalm on the guest's screen
  await H.evaluate(() => { const P = __pal, g = P.game; g.wave = 14; g.phase = 'build'; g.timer = .05 });
  await H.waitForFunction(() => __pal.game.fb && __pal.enemies.some(e => e.type === 'boss'), null, { timeout: 8000 });
  await H.evaluate(() => { const P = __pal, e = P.enemies.find(x => x.type === 'boss'); e.lx = e.x - 6; e.ly = e.y; P.launchArc(e, P.game.Df); P.napalmLand({ x1: 6.5, y1: 6.5 }) });
  await G.waitForFunction(() => __pal.game.fb && __pal.arcs.length > 0 && __pal.fires.some(f => f.nap), null, { timeout: 5000 });
  // the HUD label is redrawn by the frame loop, a moment after the snapshot lands
  await G.waitForFunction(() => /BLITZ/.test(document.getElementById('phaseLab').textContent), null, { timeout: 5000 }).catch(() => {});
  out.fb = await G.evaluate(() => { const P = __pal, h = P.game.fb; return { t: Math.round(h.t), n: h.n, max: h.max, bosses: P.enemies.filter(e => e.type === 'boss').map(e => e.boss), label: document.getElementById('phaseLab').textContent } });
  const ht = await H.evaluate(() => Math.round(__pal.game.fb.t));
  assert.ok(Math.abs(out.fb.t - ht) <= 1, 'clock in step'); assert.ok(out.fb.bosses.includes('bluebutcher')); assert.equal(out.fb.max, 10); assert.match(out.fb.label, /BLITZ/);
  // the evacuation: the guest sees the site; the host puts the guest in the ring (host-authoritative) and keeps itself out
  await H.evaluate(() => { __pal.game.fb.t = 60.5 });
  await G.waitForFunction(() => __pal.game.fb && __pal.game.fb.evac, null, { timeout: 5000 });
  out.site = await Promise.all([H, G].map(pg => pg.evaluate(() => { const E = __pal.game.fb.evac; return [E.x, E.y, E.r].map(v => Math.round(v * 10) / 10) })));
  assert.deepEqual(out.site[0], out.site[1], 'same evac site on both');
  await H.evaluate(() => { const P = __pal, E = P.game.fb.evac, g = [...P.players.values()].find(p => p.id !== 'host'), me = P.players.get('host');
    window.pin = setInterval(() => { g.x = E.x; g.y = E.y; g.tp++; me.x = E.x + 5; me.y = E.y }, 30) });
  await G.waitForFunction(() => __pal.player.ev > 1, null, { timeout: 5000 }); out.guestEv = await G.evaluate(() => +__pal.player.ev.toFixed(1));
  await G.waitForFunction(() => __pal.player.out, null, { timeout: 6000 });
  out.guestOut = await G.evaluate(() => ({ out: __pal.player.out, alive: __pal.player.alive, label: document.getElementById('phaseVal').textContent }));
  assert.match(out.guestOut.label, /you're out/);
  // an extracted guest who drops and comes back is still out (the rejoin stash)
  out.stash = await H.evaluate(() => { const P = __pal, g = [...P.players.values()].find(p => p.id !== 'host'), c = { session: 'x'.repeat(24) };
    P.stashLeaver(c, g); const fresh = { ...g, out: false, alive: true, up: { ...g.up } }; const back = P.restoreLeaver(c, fresh); return { back, out: fresh.out, alive: fresh.alive } });
  assert.deepEqual(out.stash, { back: true, out: true, alive: false });
  // time runs out: the host is left behind, the guest made it
  await H.evaluate(() => { clearInterval(window.pin); __pal.game.fb.t = .2 });
  await H.waitForFunction(() => __pal.game.phase === 'over', null, { timeout: 5000 }); await G.waitForFunction(() => __pal.game.phase === 'over', null, { timeout: 5000 });
  await H.waitForTimeout(1200);
  out.results = await Promise.all([H, G].map(pg => pg.evaluate(() => ({ won: __pal.game.won, title: document.getElementById('overTitle').textContent, eye: document.getElementById('overEyebrow').textContent, blitz: __pal.locker.bag.blitz | 0, loot: document.getElementById('overLoot').textContent }))));
  assert.equal(out.results[0].title, 'LEFT BEHIND'); assert.equal(out.results[0].won, false); assert.match(out.results[0].eye, /1 OF 2 MADE IT OUT/);
  assert.equal(out.results[1].title, 'EVACUATED'); assert.equal(out.results[1].won, true);
  assert.ok(out.results[1].blitz >= 1, 'the guest gets the evac Blitzkrieg Case'); assert.match(out.results[0].loot, /Left behind: half your cases and shards/);
  fs.writeFileSync(__dirname + '/out/blitz_network.json', JSON.stringify({ out, errors }, null, 2)); assert.deepEqual(errors, []);
  console.log(JSON.stringify(out)); console.log('errors: none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
