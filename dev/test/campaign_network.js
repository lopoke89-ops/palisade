// v0.9.6.4 campaign online (yard-24): the guest sees the host's map evac (CH 1 · EVAC, the ring, the clock) and its own
// result; a guest who gets out and a host who doesn't both move on to Riverbend, each with the right chapter result on both
// screens and in the guest's claim; then the Whiteout Gauntlet: the guest sees GAUNTLET · WAVE n/6 and the bosses, and the
// waves the host's crew clears count in the guest's claim. node campaign_network.js
const { chromium } = require('playwright'), assert = require('node:assert/strict');
const Q = 'peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1', PORT = process.env.PORT || 8080;
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--disable-features=WebRtcHideLocalIpsWithMdns'] });
  const errors = [], out = {};
  const H = await b.newPage({ viewport: { width: 1100, height: 760 } }); H.on('pageerror', e => errors.push('H ' + e.message));
  const G = await (await b.newContext({ viewport: { width: 1100, height: 760 } })).newPage(); G.on('pageerror', e => errors.push('G ' + e.message));
  await H.goto(`http://localhost:${PORT}/debug.html?${Q}`); await G.goto(`http://localhost:${PORT}/debug.html?${Q}`); await H.waitForTimeout(800);
  await H.click('[data-nav=multi]'); await H.click('[data-setup=rules]:visible'); await H.click('#setupSheet [data-m5=campaign]'); await H.click('#setupDone'); await H.click('#hostBtn');
  await H.waitForFunction(() => /^[A-Z0-9]{4}$/.test(document.getElementById('lCode').textContent), null, { timeout: 15000 });
  const code = await H.textContent('#lCode');
  await G.click('[data-nav=multi]'); await G.fill('#mCode', code); await G.click('#joinBtn');
  await G.waitForFunction(() => !document.getElementById('pg-lobby').hidden, null, { timeout: 15000 });
  out.proto = await G.evaluate(() => __pal.PROTO);
  await H.click('#lStart'); await G.waitForFunction(() => document.getElementById('menu').hidden, null, { timeout: 8000 }); await H.waitForTimeout(600);
  await H.evaluate(() => { const P = __pal; window.holdIt = setInterval(() => { for (const q of P.players.values()) { q.max = 1e9; q.hp = Math.max(q.hp, 1e8) } P.core.max = 1e9; P.core.hp = 1e9; P.qm.hp = 1e9 }, 50) });
  out.mode = await G.evaluate(() => __pal.game.mode);
  // 1. the map evac after raid 3: the guest gets out (the host walks it into the ring), the host stays at the core
  await H.evaluate(() => { const P = __pal, g = P.game; g.wave = 3; g.phase = 'raid'; g.queue = []; for (const e of P.enemies) e.dead = true; P.enemies.length = 0 });
  await G.waitForFunction(() => __pal.game.fb && __pal.game.fb.mapEvac && __pal.game.fb.evac, null, { timeout: 5000 });
  await G.waitForFunction(() => /CH 1 · EVAC/.test(document.getElementById('phaseLab').textContent), null, { timeout: 3000 });
  out.guestEvac = await G.evaluate(() => { const F = __pal.game.fb; return { t: Math.round(F.t), r: F.evac.r, ch: F.ch, label: document.getElementById('phaseLab').textContent } });
  await H.evaluate(() => { const P = __pal, F = P.game.fb, E = F.evac, gid = [...P.players.keys()].find(id => id !== P.player.id);
    window.walkIn = setInterval(() => { const q = P.players.get(gid); if (!q || q.out || !P.game.fb) return; q.x = E.x; q.y = E.y; q.tp++; P.player.x = P.core.i + .5; P.player.y = P.core.j + .5 }, 30) });
  await G.waitForFunction(() => __pal.game.map === 'river', null, { timeout: 20000 }); await H.evaluate(() => clearInterval(walkIn)); await G.waitForTimeout(700);
  out.after = await G.evaluate(() => { const P = __pal, me = P.player, host = [...P.players.values()].find(q => q !== me); return { map: P.game.map, me: me.chEvac, host: host && host.chEvac, claim: P.runClaim(3, false, 0).claim.ch_evac } });
  out.hostView = await H.evaluate(() => { const P = __pal; return { me: P.player.chEvac, hpPct: Math.round(100 * P.player.hp / P.player.max) } });
  assert.equal(out.proto, 'yard-24'); assert.equal(out.mode, 'campaign');
  assert.deepEqual({ ...out.guestEvac, t: out.guestEvac.t <= 15 && out.guestEvac.t >= 13 }, { t: true, r: 1.5, ch: 0, label: 'CH 1 · EVAC' });
  assert.deepEqual(out.after, { map: 'river', me: [1], host: [0], claim: [true, null, null] }); assert.deepEqual(out.hostView.me, [0]);
  // 2. the Whiteout Gauntlet: the guest sees the wave label and the bosses; a cleared wave counts in the guest's claim
  await H.evaluate(() => { const P = __pal, g = P.game; P.changeChapter(3); g.wave = 12; g.phase = 'build'; g.timer = .05 });
  await G.waitForFunction(() => __pal.game.fb && __pal.game.fb.gauntlet && __pal.enemies.filter(e => e.type === 'boss').length >= 3, null, { timeout: 8000 });
  await G.waitForFunction(() => /GAUNTLET · WAVE 1\/6/.test(document.getElementById('phaseLab').textContent), null, { timeout: 3000 });
  out.guestGauntlet = await G.evaluate(() => ({ map: __pal.game.map, wave: __pal.game.fb.wave, bosses: __pal.enemies.filter(e => e.type === 'boss').map(e => e.boss).sort() }));
  await H.evaluate(() => { const P = __pal; for (const e of P.enemies) if (e.type === 'boss' && !e.dead) P.hurtEnemyHook(e, 1e9, P.player.id) });
  await G.waitForFunction(() => (__pal.game.gKill || [])[0] === 3, null, { timeout: 5000 });
  out.guestClaim = await G.evaluate(() => { const c = __pal.runClaim(13, false, 0).claim; return { g_cleared: c.g_cleared, cv: c.cv } });
  assert.equal(out.guestGauntlet.map, 'frost'); assert.equal(out.guestGauntlet.wave, 1);
  assert.equal(out.guestGauntlet.bosses.filter(k => k === 'rime').length, 2);
  assert.deepEqual(out.guestClaim, { g_cleared: 1, cv: 4 });
  await H.evaluate(() => clearInterval(holdIt));
  assert.deepEqual(errors, []); console.log(JSON.stringify(out)); console.log('errors: none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
