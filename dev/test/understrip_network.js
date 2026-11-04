// THE UNDERSTRIP online (yard-31): two phones, one run. The guest builds the same level from the host's seed (the same tiles
// and the same layout, every level), sees the same raiders; the guest's Lucky Juice, shrine rest, shortcut door and trade go
// through the host; a guest left down bleeds out and their salvage stays where they fell (on both phones); the squad's fall
// costs one shared life on both; the lift takes both to the next level; the boss's gate, stage and fall reach the guest.
// An older copy (yard-30) can't join an UNDERSTRIP room, but still joins other modes.
// node understrip_network.js
const { chromium } = require('playwright'), assert = require('node:assert/strict'), { ready, synced } = require('./lib');
const Q = 'peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1', PORT = process.env.PORT || 8080;
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--disable-features=WebRtcHideLocalIpsWithMdns'] });
  const errors = [], out = {};
  const H = await b.newPage({ viewport: { width: 1100, height: 760 } }); H.on('pageerror', e => errors.push('H ' + e.message));
  const G = await (await b.newContext({ viewport: { width: 900, height: 700 } })).newPage(); G.on('pageerror', e => errors.push('G ' + e.message));
  await H.goto(`http://localhost:${PORT}/debug.html?${Q}`); await G.goto(`http://localhost:${PORT}/debug.html?${Q}`); await ready(H); await ready(G);
  await H.click('[data-nav=multi]'); await H.click('[data-setup=rules]:visible'); await H.click('#setupSheet [data-m5=understrip]'); await H.click('#setupDone'); await H.click('#hostBtn');
  await H.waitForFunction(() => /^[A-Z0-9]{4}$/.test(document.getElementById('lCode').textContent), null, { timeout: 15000 });
  const code = await H.textContent('#lCode');
  await G.click('[data-nav=multi]'); await G.fill('#mCode', code); await G.click('#joinBtn');
  await G.waitForFunction(() => !document.getElementById('pg-lobby').hidden, null, { timeout: 15000 });
  out.proto = await G.evaluate(() => [__pal.PROTO, __pal.NET.mode]);
  const hostVer = await H.evaluate(() => [...__pal.NET.conns.values()].map(c => c.v));
  assert.deepEqual(out.proto, ['yard-31', 'guest']); assert.deepEqual(hostVer, ['yard-31'], 'the host reads the guest\'s v2');
  // an older copy (yard-30): refused while the room is set to THE UNDERSTRIP, let in for any other mode (the host's own check, fed a hello on a stand-in connection)
  out.oldRefused = await H.evaluate(() => { const P = __pal, sent = []; const c = { r: { open: true, send: m => sent.push(m) }, heard: 0 }; P.NET.conns.set('old', c);
    P.hostData('old', { t: 'hello', name: 'OLD', cls: 'soldier', cos: '', v: 'yard-30', sk: '', uid: '', session: 'zz' }); P.NET.conns.delete('old');
    const was = P.pick.mode; P.pick.mode = '5'; const sent2 = []; const c2 = { r: { open: true, send: m => sent2.push(m) }, heard: 0 }; P.NET.conns.set('old2', c2);
    P.hostData('old2', { t: 'hello', name: 'OLD', cls: 'soldier', cos: '', v: 'yard-30', sk: '', uid: '', session: 'zz' }); P.NET.conns.delete('old2'); P.pick.mode = was;
    return { understrip: sent.some(m => m.t === 'kick'), otherMode: !sent2.some(m => m.t === 'kick') } });
  assert.deepEqual(out.oldRefused, { understrip: true, otherMode: true });
  await H.evaluate(() => __pal.lobbyReadyAll()); await H.click('#lStart'); await G.waitForFunction(() => document.getElementById('menu').hidden, null, { timeout: 8000 }); await synced(H, G);
  await H.evaluate(() => { window.hold = setInterval(() => { for (const q of __pal.players.values()) if (q.alive && !window.letDie) { q.max = 1e6; q.hp = Math.max(q.hp, 1e5) } }, 50) });
  const lvl = pg => pg.evaluate(() => { const P = __pal, L = P.game.lay; return { mode: P.game.mode, level: P.game.us.level, N: P.N, hash: P.usTileHash(P.usLevel()), seed: P.game.us.seed, shrines: L.shrines.length, merchants: L.merchants.length, doors: L.doors.length, exit: L.exit, stock: L.merchants.map(m => m.stock.map(s => s.k + s.n).join()).join('|') } });
  out.level0 = await Promise.all([lvl(H), lvl(G)]);
  assert.equal(out.level0[1].mode, 'understrip'); assert.deepEqual(out.level0[0], out.level0[1], 'the same level from the same seed');
  await G.waitForTimeout(600);
  out.raiders = await Promise.all([H, G].map(pg => pg.evaluate(() => __pal.enemies.filter(e => e.type !== 'boss').length)));
  // (the guest only hears about raiders near it; the host has them all)
  assert.ok(out.raiders[0] > 0);
  // the guest drinks: the host takes the charge and heals
  const gid = await G.evaluate(() => __pal.player.id);
  await H.evaluate(gid => { const g = __pal.players.get(gid); g.max = 100; g.hp = 30; window.letDie = true }, gid);
  await G.waitForFunction(() => __pal.player.hp < 50, null, { timeout: 5000 });
  await G.keyboard.press('c'); await G.waitForTimeout(1500);
  out.drink = await H.evaluate(gid => { const g = __pal.players.get(gid); return { uj: g.uj, hp: Math.round(g.hp) } }, gid);
  out.drinkGuest = await G.evaluate(() => __pal.player.uj);
  assert.equal(out.drink.uj, 2); assert.ok(out.drink.hp >= 70, 'healed 45%'); assert.equal(out.drinkGuest, 2);
  await H.evaluate(() => { window.letDie = false });
  // the guest rests at the shrine (raiders cleared from round it on the host)
  await H.evaluate(() => { const P = __pal, S = P.game.lay.shrines.find(q => !q.arena); for (const e of P.enemies) if (e.us && Math.hypot(e.x - S.x, e.y - S.y) < 12) e.dead = true });
  // (moves longer than a few tiles are the host's to make: it sets the guest's spot and the guest snaps to it)
  const tpG = (x, y) => H.evaluate(([gid, x, y]) => { const g = __pal.players.get(gid); g.x = x; g.y = y; g.tp++ }, [gid, x, y]);
  { const S = await H.evaluate(() => { const q = __pal.game.lay.shrines.find(q => !q.arena); return [q.x, q.y] }); await tpG(S[0], S[1] + .6) }
  await G.waitForTimeout(500); await G.keyboard.press('e'); await G.waitForTimeout(800);
  out.rest = await Promise.all([H, G].map(pg => pg.evaluate(() => ({ ix: __pal.game.us.rest.ix, lit: __pal.game.us.lit }))));
  assert.ok(out.rest[0].ix >= 0 && out.rest[0].lit > 0); assert.deepEqual(out.rest[0], out.rest[1]);
  // the guest opens the shortcut from its side: the tiles open on both phones
  { const at = await H.evaluate(() => { const P = __pal, D = P.game.lay.doors[0], sd = { N: [0, -1], S: [0, 1], E: [1, 0], W: [-1, 0] }[D.side], cx = D.tiles.reduce((a, t) => a + t[0] + .5, 0) / D.tiles.length, cy = D.tiles.reduce((a, t) => a + t[1] + .5, 0) / D.tiles.length; return [cx + sd[0] * 1.1, cy + sd[1] * 1.1] }); await tpG(at[0], at[1]) }
  await G.waitForTimeout(500); await G.keyboard.press('e'); await G.waitForTimeout(800);
  out.door = await Promise.all([H, G].map(pg => pg.evaluate(() => { const P = __pal, t = P.game.lay.doors[0].tiles[0]; return { open: P.terr[t[1] * P.N + t[0]] !== P.T_SHUT, bit: P.game.us.opened } })));
  assert.deepEqual(out.door, [{ open: true, bit: 1 }, { open: true, bit: 1 }]);
  // the guest trades: a grenade through the host
  await H.evaluate(gid => { const g = __pal.players.get(gid); g.sal = 100; g.nades = 0 }, gid);
  { const m = await H.evaluate(() => { const q = __pal.game.lay.merchants[0]; return [q.x, q.y] }); await tpG(m[0], m[1] + 1) }
  await G.waitForTimeout(700);
  await G.evaluate(() => { const P = __pal, st = P.game.lay.merchants[0].stock, i = st.findIndex(s => s.k === 'c_nade'); P.NET.toHost({ t: 'ub', m: 0, s: i }) });
  await G.waitForTimeout(800);
  out.trade = await Promise.all([H.evaluate(gid => { const g = __pal.players.get(gid); return [g.nades, g.sal] }, gid), G.evaluate(() => [__pal.player.nades, __pal.player.sal])]);
  assert.deepEqual(out.trade[0], [1, 85]); assert.deepEqual(out.trade[1], [1, 85]);
  // M2: a weapon from the host reaches the guest (the kit rides the player info); the guest's 1 and 2 swap it on the host
  await H.evaluate(gid => { const P = __pal, g = P.players.get(gid); P.usGiveWeapon(g, { id: 'w_smg', r: 'r', mods: ['m_dmg'] }) }, gid);
  await G.waitForFunction(() => __pal.player.w2 && __pal.player.w2.id === 'w_smg', null, { timeout: 5000 });
  await G.keyboard.press('1'); await G.waitForTimeout(600);
  out.swap = await Promise.all([H.evaluate(gid => __pal.players.get(gid).wSel, gid), G.evaluate(() => [__pal.player.wSel, __pal.player.w2.r, __pal.player.w2.mods.join()])]);
  assert.equal(out.swap[0], 0); assert.deepEqual(out.swap[1], [0, 'r', 'm_dmg']);
  // the guest down and left: bleeds out, salvage stays where they fell (seen on both)
  await H.evaluate(gid => { const P = __pal, g = P.players.get(gid); window.letDie = true; g.sal = 23; P.hurtPlayer(g, 1e7); g.rt = .3 }, gid);
  await G.waitForTimeout(1200);
  out.bled = await Promise.all([H, G].map(pg => pg.evaluate(gid => { const P = __pal, g = P.players.get(gid); return { dead: !!g.usDead, alive: g.alive, drops: P.game.us.drops.map(d => d.sal) } }, gid)));
  assert.deepEqual(out.bled[0], { dead: true, alive: false, drops: [23] }); assert.deepEqual(out.bled[1], out.bled[0]);
  // the host falls too: the squad loses a life (on both) and is back at the shrine
  const lives0 = await H.evaluate(() => __pal.game.us.lives);
  await H.evaluate(() => { const P = __pal; P.hurtPlayer(P.player, 1e7) }); await H.waitForTimeout(3500); await H.evaluate(() => { window.letDie = false });
  out.wipe = await Promise.all([H, G].map(pg => pg.evaluate(gid => ({ lives: __pal.game.us.lives, guestUp: __pal.players.get(gid).alive }), gid)));
  assert.equal(out.wipe[0].lives, lives0 - 1); assert.deepEqual(out.wipe[0], out.wipe[1]); assert.ok(out.wipe[0].guestUp);
  // the lift: both in the ring, both go down a level, both build the same new level
  await H.evaluate(() => { const P = __pal; for (const e of P.enemies) e.dead = true });
  const ex = await H.evaluate(() => __pal.game.lay.exit);
  await H.evaluate(ex => { __pal.player.x = ex[0]; __pal.player.y = ex[1] }, ex); await tpG(ex[0] + .3, ex[1]);
  await G.waitForFunction(() => __pal.game.us.level === 1, null, { timeout: 15000 });
  await H.waitForTimeout(400);
  out.level1 = await Promise.all([lvl(H), lvl(G)]);
  assert.equal(out.level1[0].level, 1); assert.deepEqual(out.level1[0], out.level1[1]); assert.notEqual(out.level1[0].hash, out.level0[0].hash);
  // down to the boss: the gate, the boss and his second stage reach the guest
  await H.evaluate(() => __pal.usLevelDone()); await G.waitForFunction(() => __pal.game.us.level === 2, null, { timeout: 15000 });
  out.level2 = await Promise.all([lvl(H), lvl(G)]); assert.deepEqual(out.level2[0], out.level2[1]);
  await H.evaluate(() => { const P = __pal, A = P.game.lay.arena; P.player.x = A.x + A.w / 2; P.player.y = A.y + A.h - 3 });
  { const A = await H.evaluate(() => __pal.game.lay.arena); await tpG(A.x + A.w / 2 + .4, A.y + A.h - 3) }
  await G.waitForFunction(() => __pal.game.us.gate === 2 && __pal.enemies.some(e => e.type === 'boss'), null, { timeout: 10000 });
  await H.evaluate(() => { const P = __pal, B = P.enemies.find(e => e.type === 'boss'); P.hurtEnemy(B, B.hp - B.max * .49, P.player.id) });
  await G.waitForFunction(() => __pal.game.us.bossStage === 1, null, { timeout: 5000 });
  out.boss = await G.evaluate(() => { const P = __pal, B = P.enemies.find(e => e.type === 'boss'); return { name: B.boss, stage: P.game.us.bossStage, bar: +P.usBossFrac(B).toFixed(1), flood: !!P.game.us.floodOn } });
  assert.deepEqual(out.boss, { name: 'pitboss', stage: 1, bar: 1, flood: true });
  await H.evaluate(() => { const P = __pal, B = P.enemies.find(e => e.type === 'boss'); B.inv = 0; P.hurtEnemy(B, 1e9, P.player.id) });
  await G.waitForFunction(() => __pal.game.us.bossDown && __pal.game.us.gate === 0, null, { timeout: 5000 });
  out.bossDown = true;
  console.log(JSON.stringify(out));
  console.log('errors:', errors.length ? errors : 'none'); await b.close(); if (errors.length) process.exit(1);
})().catch(e => { console.error(e); process.exit(1) });
