// v0.10.0 THE PALISADE FALLS CASINO, the map and the room (yard-28): a host opens a casino from the MULTIPLAYER lobby and
// a guest joins by code. The 16x16 floor, no raiders, no stake, no building; every seat at the three tables (as many as
// the server's tables have) can be walked to from the door; the seat codes travel to everyone; the host only gives a guest
// a seat that's free and right next to them, and puts them on it; no weapons; names over heads (no health bars) and the
// dealers' names; leaving puts PLAY back on the run you had picked. node casino_map.js
const { chromium } = require('playwright'), assert = require('node:assert/strict'), fs = require('node:fs'), { ready, synced } = require('./lib');
const Q = 'peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1', PORT = process.env.PORT || 8080;
(async () => {
  const E = await import('../supabase/functions/tables/engine.js');
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--disable-features=WebRtcHideLocalIpsWithMdns'] });
  const errors = [], out = {};
  const H = await b.newPage({ viewport: { width: 1280, height: 800 } }); H.on('pageerror', e => errors.push('H ' + e.message));
  const G = await (await b.newContext({ viewport: { width: 900, height: 700 } })).newPage(); G.on('pageerror', e => errors.push('G ' + e.message));
  await H.goto(`http://localhost:${PORT}/debug.html?${Q}`); await G.goto(`http://localhost:${PORT}/debug.html?${Q}`); await ready(H); await ready(G);
  // Retain legacy four-character/P2P room compatibility; dedicated relay suites check the public casino path.
  for(const p of [H,G])await p.evaluate(()=>globalThis.PALISADE_RELAY={enabled:false,url:''});
  out.picked = await H.evaluate(() => __pal.pick.mode);
  await H.evaluate(() => { __pal.pick.mode = 'casino' }); await H.click('[data-nav=multi]'); await H.click('#hostBtn');
  await H.waitForFunction(() => /^[A-Z0-9]{4}$/.test(document.getElementById('lCode').textContent), null, { timeout: 15000 });
  const code = await H.textContent('#lCode');
  await G.click('[data-nav=multi]'); await G.fill('#mCode', code); await G.click('#joinBtn');
  await G.waitForFunction(() => !document.getElementById('pg-lobby').hidden, null, { timeout: 15000 });
  await H.evaluate(() => __pal.lobbyReadyAll()); await H.click('#lStart'); await G.waitForFunction(() => document.getElementById('menu').hidden, null, { timeout: 8000 }); await synced(H, G);
  out.proto = await G.evaluate(() => __pal.PROTO); assert.equal(out.proto, 'yard-29');
  // 1. the floor: 16x16, no stake, no raiders, nothing to build, a clock that never runs out
  out.mode = await G.evaluate(() => ({ mode: __pal.game.mode, map: __pal.game.map, N: __pal.N, cores: __pal.cores.length, nodes: __pal.nodes.length }));
  assert.deepEqual(out.mode, { mode: 'casino', map: 'casino', N: 16, cores: 0, nodes: 0 });
  await H.waitForTimeout(3000);
  out.after3s = await H.evaluate(() => ({ enemies: __pal.enemies.length, phase: __pal.game.phase, timer: __pal.game.timer > 1e8, walls: __pal.walls.filter(Boolean).length, qm: __pal.qm.alive }));
  assert.deepEqual(out.after3s, { enemies: 0, phase: 'build', timer: true, walls: 0, qm: false }, 'no raiders, no building, no Delgado');
  // 2. seats: as many as the server's tables, and every one reachable on foot from the door
  out.layout = await H.evaluate(() => {
    const P = __pal, C = P.CAS, N = P.N, solid = (i, j) => i < 0 || j < 0 || i >= N || j >= N || P.solidTileHook(i, j);
    const seen = new Set(), q = [], start = C.spawn[0]; q.push([Math.floor(start[0]), Math.floor(start[1])]); seen.add(q[0].join());
    while (q.length) { const [i, j] = q.shift(); for (const [di, dj] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const a = i + di, c = j + dj, k = a + ',' + c; if (!seen.has(k) && !solid(a, c)) { seen.add(k); q.push([a, c]) } } }
    const at = ([x, y]) => !solid(Math.floor(x), Math.floor(y)) && seen.has(Math.floor(x) + ',' + Math.floor(y));
    return { spawns: C.spawn.map(([x, y]) => !solid(Math.floor(x), Math.floor(y))), seats: Object.fromEntries(C.tables.map(t => [t.game, t.seats.length])),
      reach: C.tables.flatMap(t => t.seats.map((p, k) => ({ g: t.game, k, ok: at(p) }))).concat(C.machines.map(m => ({ g: m.id, k: 0, ok: at(m.stand) }))),
      machines: C.machines.map(m => m.id), codes: [...__pal.CAS_SEAT.keys()].sort((a, b) => a - b) };
  });
  assert.ok(out.layout.spawns.every(Boolean), 'every spawn spot is on the floor');
  assert.deepEqual(out.layout.seats, { bj: E.SEATS.bj, he: E.SEATS.he, rl: E.SEATS.rl, cr: E.SEATS.cr, ba: E.SEATS.ba }, 'a seat in the room for every seat at the server\'s table');
  assert.deepEqual(out.layout.machines, [...Array.from({ length: 16 }, (_, k) => 's' + (k + 1)), 'p1'], 'sixteen slot cabinets and the Plinko board, each a station the server knows');
  const H2 = await import('../supabase/functions/tables/handler.js'); assert.ok(out.layout.machines.every(id => H2.stationOk(id[0] === 's' ? 'sl' : 'pk', id)), 'every station passes the server\'s check');
  assert.deepEqual(out.layout.codes.filter(c => c < 100), [11, 12, 13, 14, 15, 21, 22, 23, 24, 25, 26, 31, 32, 33, 34, 35, 36, 41, 42, 43, 44, 45, 46, 51, 52, 53, 54, 55, 56], 'v0.10.0 seat codes unchanged; craps 41-46, baccarat 51-56');
  assert.deepEqual(out.layout.reach.filter(s => !s.ok), [], 'every seat can be walked to from the door');
  // 3. seats on the network: the host takes blackjack seat 0; the guest can't claim it, can't claim a seat across the room,
  //    and gets the one it's standing next to (the host puts it on it)
  const seatPos = (g, k) => H.evaluate(([g, k]) => __pal.CAS.tables.find(t => t.game === g).seats[k], [g, k]);
  const [hx, hy] = await seatPos('bj', 0); await H.evaluate(([x, y]) => { const p = __pal.player; p.x = x; p.y = y; p.seat = 11 }, [hx, hy]);
  await G.waitForFunction(() => { const h = [...__pal.players.values()].find(p => p.id === 'host'); return h && h.seat === 11 }, null, { timeout: 5000 });
  const gSeat = () => H.evaluate(() => [...__pal.players.values()].find(p => p.id !== 'host').seat | 0);
  const gAt = async (x, y, seat) => { await G.evaluate(([x, y, s]) => { const p = __pal.player; p.x = x; p.y = y; p.seat = s }, [x, y, seat]); await H.waitForTimeout(500) };
  // the guest's position is checked step by step on the host, so walk it over in small steps
  const walk = async (x, y) => { for (let k = 0; k < 80; k++) { const d = await G.evaluate(([x, y]) => { const p = __pal.player, dx = x - p.x, dy = y - p.y, l = Math.hypot(dx, dy); if (l < .05) return 0; const s = Math.min(l, .12); p.x += dx / l * s; p.y += dy / l * s; return l }, [x, y]); if (!d) break; await G.waitForTimeout(45) } await H.waitForTimeout(300) };
  await walk(hx + .4, hy + .5); await gAt(hx + .4, hy + .5, 11); assert.equal(await gSeat(), 0, 'a seat someone is in can\'t be claimed');
  const [rx, ry] = await seatPos('rl', 0); await gAt(hx + .4, hy + .5, 31); assert.equal(await gSeat(), 0, 'a seat across the room can\'t be claimed');
  const [bx, by] = await seatPos('bj', 1); await walk(bx + .3, by + .3); await gAt(bx + .3, by + .3, 12);
  assert.equal(await gSeat(), 12, 'the seat it\'s standing next to');
  out.snapped = await H.evaluate(([x, y]) => { const p = [...__pal.players.values()].find(p => p.id !== 'host'); return Math.hypot(p.x - x, p.y - y) < 1e-6 }, [bx, by]); assert.ok(out.snapped, 'the host puts it on the seat');
  await H.waitForTimeout(400); out.guestSeesOwn = await G.evaluate(() => __pal.player.seat); assert.equal(out.guestSeesOwn, 12);
  out.hostSeenByGuest = await G.evaluate(() => [...__pal.players.values()].find(p => p.id === 'host').seat); assert.equal(out.hostSeenByGuest, 11);
  void rx; void ry;
  // v0.10.3: a machine is a seat too: the guest takes slot cabinet 3 (code 103) from in front of it; a made-up code is refused
  { const m = await H.evaluate(() => __pal.CAS.machines[10]); await gAt(bx + .3, by + .3, 0); await walk(2.2, 6.6); await walk(m.stand[0] + .1, m.stand[1] + .2); await gAt(m.stand[0] + .1, m.stand[1] + .2, m.code);   // around the blackjack table to cabinet 11 on the west wall
    assert.equal(await gSeat(), m.code, 'the cabinet it stands at'); await gAt(m.stand[0], m.stand[1], 0); await gAt(m.stand[0], m.stand[1], 999); assert.equal(await gSeat(), 0, 'a seat code that isn\'t in the registry is refused');
    await gAt(m.stand[0], m.stand[1], 0); await walk(2.2, 6.6); await walk(bx + .3, by + .3) }
  // 4. no weapons: the guest holds fire, nothing is shot
  await gAt(bx + .3, by + .3, 0); await walk(5, 8);
  { const n0 = await H.evaluate(() => __pal.bullets.length); await G.mouse.move(600, 300); await G.mouse.down(); await H.waitForTimeout(700); await G.mouse.up(); assert.equal(await H.evaluate(() => __pal.bullets.length), n0, 'no shots in the casino') }
  // 5. names over heads, no health bars; the dealers' names
  out.plates = await H.evaluate(() => __pal.plates.map(p => ({ who: p.who, bar: p.bar }))); assert.ok(out.plates.length >= 2 && out.plates.every(p => p.bar === false), 'names only');
  await H.screenshot({ path: __dirname + '/out/casino_map_host.png' }); await G.screenshot({ path: __dirname + '/out/casino_map_guest.png' });
  // 6. back to the menu: PLAY is the run you had picked again
  await H.evaluate(() => __pal.toMenu()); out.pickedAfter = await H.evaluate(() => __pal.pick.mode); assert.equal(out.pickedAfter, out.picked, 'PLAY goes back to the run you had picked');
  assert.deepEqual(errors, [], 'no page errors');
  fs.writeFileSync(__dirname + '/out/casino_map.json', JSON.stringify(out, null, 1)); console.log(JSON.stringify(out)); console.log('errors: none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
