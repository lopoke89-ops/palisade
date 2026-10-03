// v0.9.3.7 Nightmare + Boss Rush: each Boss Rush boss raid rolls 1 in 12 for a second in-between boss (different where
// the map allows), announced as NIGHTMARE · SECOND BOSS and paid like any in-between boss. Either modifier alone,
// odd raids and regular boss raids are unchanged. node mod_synergy.js
const { chromium } = require('playwright'), assert = require('node:assert/strict'), fs = require('node:fs');
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), errors = [], out = {};
  const p = await b.newPage({ viewport: { width: 1100, height: 760 } }); p.on('pageerror', e => errors.push(e.message));
  await p.goto(`http://localhost:${process.env.PORT || 8080}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal);
  const game = mods => p.evaluate(m => { const P = __pal; P.demo = false; P.newGame(null, '', { mods: m }); P.enterGameHook() }, mods);
  // rates and rules (host logic)
  await game(['bossrush', 'nightmare']);
  out.rules = await p.evaluate(() => { const P = __pal, n = 24000; let hit = 0, diff = 0;
    for (let i = 0; i < n; i++) { const k = P.nightmareSecond(2, 'butcher'); if (k) { hit++; if (k !== 'butcher') diff++ } }
    return { rate: +(hit / n).toFixed(4), different: diff === hit, odd: [1, 3, 7].map(w => P.nightmareSecond(w, 'butcher')).join(''), regular: P.nightmareSecond(10, 'butcher') } });
  assert.ok(Math.abs(out.rules.rate - 1 / 12) < .007, JSON.stringify(out.rules)); assert.ok(out.rules.different); assert.equal(out.rules.odd, ''); assert.equal(out.rules.regular, '');
  for (const m of [['bossrush'], ['nightmare']]) { await game(m); out['only_' + m[0]] = await p.evaluate(() => { let h = 0; for (let i = 0; i < 6000; i++) if (__pal.nightmareSecond(4, 'butcher')) h++; return h }); assert.equal(out['only_' + m[0]], 0) }
  // a forced roll: raid 2 queues two in-between bosses; both spawn, the second is announced, and both pay as in-between bosses
  await game(['bossrush', 'nightmare']);
  out.raid = await p.evaluate(async () => { const P = __pal, g = P.game; g.forceSecond = true; g.wave = 1; g.phase = 'build'; P.startRaid();
    const q = g.queue.filter(t => t.startsWith('boss:')), toasts = [];
    const tEl = document.getElementById('toast'), mo = new MutationObserver(() => toasts.push(tEl.textContent)); mo.observe(tEl, { childList: true, subtree: true, characterData: true });
    for (const p of P.players.values()) { p.max = 1e9; p.hp = 1e9 } P.core.max = 1e9; P.core.hp = 1e9;
    for (let i = 0; i < 2400 && P.enemies.filter(e => e.type === 'boss').length < 2; i++) P.update(1 / 30);
    await new Promise(r => setTimeout(r, 50)); mo.disconnect();
    const bosses = P.enemies.filter(e => e.type === 'boss'); const sb0 = g.sbN | 0; for (const e of bosses) P.hurtEnemyHook(e, 1e9, P.player.id);
    return { queue: q, bosses: bosses.map(e => [e.boss, !!e.sb]), second: toasts.some(t => /NIGHTMARE · SECOND BOSS/.test(t)) || P.toastQ.some(q => /NIGHTMARE · SECOND BOSS/.test(q.big)),   // v0.9.7.1: it may wait its turn behind the raid's message
      sbPaid: (g.sbN | 0) - sb0, bossLog: g.bossLog.length } });
  assert.equal(out.raid.queue.length, 2); assert.ok(out.raid.queue.some(t => t.endsWith(':sb2')));
  assert.equal(out.raid.bosses.length, 2); assert.ok(out.raid.bosses.every(x => x[1]), 'both are in-between bosses'); assert.ok(out.raid.second, 'announced');
  assert.equal(out.raid.sbPaid, 2); assert.equal(out.raid.bossLog, 0, 'in-between bosses stay out of the regular boss log, as before');
  out.desc = await p.evaluate(() => __pal.MODS.find(m => m.id === 'nightmare').what); assert.match(out.desc, /With Boss Rush on too/);
  fs.writeFileSync(__dirname + '/out/mod_synergy.json', JSON.stringify({ out, errors }, null, 2)); assert.deepEqual(errors, []);
  console.log(JSON.stringify(out)); console.log('errors: none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
