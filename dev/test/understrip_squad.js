// THE UNDERSTRIP online with four players: one host and three guests go down the whole run together, all ten levels. On
// every level each phone builds the same tiles from the host's seed; each boss's gate seals, its stage and its warnings
// (the Custodian's doors, what's on the floor) reach the guests; one life comes back for each region cleared; and the run
// ends on OUT OF AREA 67 on all four phones.
// node understrip_squad.js
const { chromium } = require('playwright'), assert = require('node:assert/strict'), { ready } = require('./lib');
const Q = 'peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1', PORT = process.env.PORT || 8080;
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--disable-features=WebRtcHideLocalIpsWithMdns'] });
  const errors = [], out = { levels: [] };
  const H = await b.newPage({ viewport: { width: 900, height: 640 } }); H.on('pageerror', e => errors.push('H ' + e.message));
  const Gs = [];
  for (let n = 0; n < 3; n++) { const G = await (await b.newContext({ viewport: { width: 700, height: 520 } })).newPage(); G.on('pageerror', e => errors.push('G' + n + ' ' + e.message)); Gs.push(G) }
  const all = [H, ...Gs];
  for (const p of all) { await p.goto(`http://localhost:${PORT}/debug.html?${Q}`); await ready(p) }
  await H.click('[data-nav=multi]'); await H.click('[data-setup=rules]:visible'); await H.click('#setupSheet [data-m5=understrip]'); await H.click('#setupDone'); await H.click('#hostBtn');
  await H.waitForFunction(() => /^[A-Z0-9]{4}$/.test(document.getElementById('lCode').textContent), null, { timeout: 15000 });
  const code = await H.textContent('#lCode');
  for (const G of Gs) { await G.click('[data-nav=multi]'); await G.fill('#mCode', code); await G.click('#joinBtn'); await G.waitForFunction(() => !document.getElementById('pg-lobby').hidden, null, { timeout: 15000 }) }
  await H.waitForFunction(() => __pal.NET.conns.size === 3, null, { timeout: 15000 });
  await H.evaluate(() => __pal.lobbyReadyAll()); await H.click('#lStart');
  for (const G of Gs) await G.waitForFunction(() => document.getElementById('menu').hidden && __pal.game && __pal.game.us && __pal.players.size === 4, null, { timeout: 15000 });
  // nobody dies in this test: it's about the squad going down together
  await H.evaluate(() => { window.hold = setInterval(() => { for (const q of __pal.players.values()) if (q.alive) { q.max = 1e6; q.hp = Math.max(q.hp, 1e5) } }, 50) });
  const lv = p => p.evaluate(() => { const P = __pal; return [P.game.us.level, P.usTileHash(P.usLevel()), P.MAPS.understrip.name] });
  const move = (x, y) => H.evaluate(([x, y]) => { let n = 0; for (const q of __pal.players.values()) { const a = n++ * 1.57; q.x = x + Math.cos(a) * .45 * (n > 1); q.y = y + Math.sin(a) * .45 * (n > 1); q.tp++ } }, [x, y]);
  for (let level = 0; level < 10; level++) {
    await H.waitForFunction(l => __pal.game.us.level === l && __pal.game.us.lift <= 0, level, { timeout: 20000 });
    for (const G of Gs) await G.waitForFunction(l => __pal.game.us.level === l, level, { timeout: 20000 });
    const seen = await Promise.all(all.map(lv)), row = { level, same: seen.every(s => s[1] === seen[0][1] && s[0] === level), map: seen[0][2], lives: await H.evaluate(() => __pal.game.us.lives) };
    await H.evaluate(() => { for (const e of __pal.enemies) e.dead = true });
    const boss = await H.evaluate(() => __pal.US_PLAN[__pal.game.us.level][2]);
    if (boss) {
      const A = await H.evaluate(() => { const A = __pal.game.lay.arena; return [A.x + A.w / 2, A.y + A.h - 3] }); await move(A[0], A[1]);
      await H.waitForFunction(() => __pal.game.us.gate === 2 && __pal.enemies.some(e => e.type === 'boss' && !e.dead), null, { timeout: 15000 });
      for (const G of Gs) await G.waitForFunction(k => __pal.game.us.gate === 2 && __pal.enemies.some(e => e.type === 'boss' && e.boss === k), boss, { timeout: 15000 });
      // let it fight a few seconds: its warnings reach every phone
      await H.waitForTimeout(4000);
      row.guestSaw = await Promise.all(Gs.map(G => G.evaluate(() => { const U = __pal.game.us; return { bfx: (U.bfx || []).length, blast: (U.blast || []).join(''), st: __pal.enemies.filter(e => e.type === 'boss').map(e => e.st) } })));
      row.hostBfx = await H.evaluate(() => (__pal.game.us.bfx || []).map(f => f.k));
      // stage 2 on every phone, then down
      await H.evaluate(() => { const P = __pal, B = P.enemies.find(e => e.type === 'boss' && !e.dead); P.hurtEnemy(B, B.hp - B.max * .49, P.player.id) });
      for (const G of Gs) await G.waitForFunction(() => __pal.game.us.bossStage >= 1, null, { timeout: 8000 });
      await H.waitForTimeout(3600);
      if (boss === 'gatekeeper') { await H.waitForFunction(() => __pal.enemies.some(e => e.pilot && !e.dead), null, { timeout: 8000 }); for (const G of Gs) await G.waitForFunction(() => __pal.enemies.some(e => e.pilot), null, { timeout: 8000 }) }
      await H.evaluate(() => { const P = __pal; for (const e of P.enemies) if (e.type === 'boss' && !e.dead) { e.inv = 0; P.hurtEnemy(e, 1e9, P.player.id) } });
      await H.waitForFunction(() => __pal.game.us.bossDown, null, { timeout: 8000 });
      for (const G of Gs) await G.waitForFunction(() => __pal.game.us.bossDown && __pal.game.us.gate === 0, null, { timeout: 8000 });
      row.down = true;
    }
    await H.evaluate(() => { for (const e of __pal.enemies) e.dead = true });
    const ex = await H.evaluate(() => __pal.game.lay.exit); await move(ex[0], ex[1]);
    if (level < 9) await H.waitForFunction(() => __pal.game.us.lift > 0, null, { timeout: 10000 });
    out.levels.push(row);
  }
  for (const p of all) await p.waitForFunction(() => __pal.game.phase === 'over', null, { timeout: 15000 });
  out.end = await Promise.all(all.map(p => p.evaluate(async () => { await new Promise(z => setTimeout(z, 1200)); return [__pal.game.won, document.getElementById('overTitle').textContent] })));
  console.log(JSON.stringify(out, null, 1));
  for (const r of out.levels) assert.ok(r.same, 'level ' + r.level + ': the same level on all four phones');
  assert.deepEqual(out.levels.map(r => r.map), ['THE FLOOD TUNNELS', 'THE FLOOD TUNNELS', 'THE FLOOD TUNNELS', 'SHELTER 7', 'SHELTER 7', 'SHELTER 7', 'AREA 67', 'AREA 67', 'AREA 67', 'AREA 67']);
  assert.deepEqual(out.levels.map(r => r.lives), [3, 3, 3, 4, 4, 4, 5, 5, 5, 6], 'a life for each region cleared (the Gatekeeper clears region 3)');
  for (const r of out.levels.filter(r => r.down)) { assert.ok(r.guestSaw.every(s => s.st.length >= 1), 'level ' + r.level + ': every guest sees the boss');
    if (r.level === 5) assert.ok(r.guestSaw.every(s => s.blast.length === 4), 'the Custodian\'s doors reach the guests') }
  assert.equal(out.levels.filter(r => r.down).length, 4, 'four bosses down');
  assert.deepEqual(out.end, [[true, 'OUT OF AREA 67'], [true, 'OUT OF AREA 67'], [true, 'OUT OF AREA 67'], [true, 'OUT OF AREA 67']]);
  console.log('errors:', errors.length ? errors : 'none'); await b.close(); if (errors.length) process.exit(1);
})();
