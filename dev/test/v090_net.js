// v0.9.0 online: what the host changes reaches the guest: floods, pits, a rammed bridge, boss states (raft, burrow),
// the new raiders and their thrown bottles and slabs, rock slabs, and which bosses fell. node v090_net.js
const { chromium } = require('playwright');
const assert = require('assert');
const Q = 'peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1', PORT = process.env.PORT || 8080;
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--disable-features=WebRtcHideLocalIpsWithMdns'] });
  const errors = [], out = {};
  const open = async () => { const p = await b.newPage({ viewport: { width: 1100, height: 760 } }); p.on('pageerror', e => errors.push(e.message)); await p.goto(`http://localhost:${PORT}/debug.html?${Q}`); await p.waitForTimeout(1000); return p };
  const play = async map => {
    const H = await open(), G = await open();
    await H.click('[data-nav=multi]'); await H.click(`[data-mmap=${map}]`); await H.click('#hostBtn');
    await H.waitForFunction(() => /^[A-Z0-9]{4}$/.test(document.getElementById('lCode').textContent), null, { timeout: 15000 });
    const code = await H.textContent('#lCode');
    await G.click('[data-nav=multi]'); await G.fill('#mCode', code); await G.click('#joinBtn'); await G.waitForSelector('#pg-lobby:not([hidden])', { timeout: 15000 }); await H.waitForTimeout(500);
    await H.click('#lStart'); await G.waitForFunction(() => document.getElementById('menu').hidden, null, { timeout: 8000 }); await H.waitForTimeout(600);
    await H.evaluate(() => { const P = __pal; window.imm = () => { for (const q of P.players.values()) { q.max = 1e9; q.hp = 1e9 } P.core.max = 1e9; P.core.hp = 1e9; P.qm.hp = 1e9 };
      window.holdIt = setInterval(imm, 50) });
    return [H, G];
  };
  // Riverbend: flood, the Ferryman on his raft, a bridge rammed
  {
    const [H, G] = await play('river');
    await H.evaluate(() => { const P = __pal; P.game.wave = 2; P.startRaid(); P.game.queue = []; for (const e of P.enemies) e.dead = true;
      const d = P.spawnEnemyAt('rifle', P.N - .5, .5); d.speed = 0; d.hp = d.max = 1e9; d.cd = 1e9; P.game.flood.t = 13.5 });
    await H.waitForTimeout(1500);
    out.flood = await G.evaluate(() => __pal.floodOn);
    await H.evaluate(() => { const P = __pal; P.spawnBoss('ferryman'); const f = P.enemies.find(e => e.boss === 'ferryman'); f.hp = f.max * .45 });
    await G.waitForFunction(() => __pal.enemies.some(e => e.boss === 'ferryman'), null, { timeout: 5000 });
    out.raft = await G.evaluate(() => __pal.enemies.find(e => e.boss === 'ferryman').raft);
    await H.waitForFunction(() => __pal.terr.filter(t => t === 2).length === 2, null, { timeout: 15000 });
    await H.waitForTimeout(800);
    out.bridgeOnGuest = await G.evaluate(() => __pal.terr.filter(t => t === 2).length);
    await H.evaluate(() => { const P = __pal, f = P.enemies.find(e => e.boss === 'ferryman'); P.hurtEnemyHook(f, 1e7, P.player.id) });
    await H.waitForTimeout(800);
    out.bossLogGuest = await G.evaluate(() => __pal.game.bossLog);
    const sameGround = await H.evaluate(() => [...__pal.terr].join('')) === await G.evaluate(() => [...__pal.terr].join(''));
    out.sameGroundRiver = sameGround;
    await H.close(); await G.close();
  }
  // Ashfall Quarry: a pit, the Foreman underground, a firebrand's bottle and a slab in flight, a slab wall
  {
    const [H, G] = await play('quarry');
    await H.evaluate(() => { const P = __pal; P.game.wave = 4; P.startRaid(); P.game.queue = []; for (const e of P.enemies) e.dead = true;
      const k = P.terr.indexOf(4); P.explode(k % P.N + .5, ((k / P.N) | 0) + .5, 2.1, 1.6);
      P.spawnBoss('foreman'); const f = P.enemies.find(e => e.boss === 'foreman'); f.ab = 0;
      const c = P.core; P.lobs.push({ x0: c.i + 6, y0: c.j, x1: c.i + 2.5, y1: c.j - 2.5, t: 0, T: 3, R: 1, power: 1, k: 1 }, { x0: c.i + 6, y0: c.j, x1: c.i + 3.5, y1: c.j - 3.5, t: 0, T: 3, R: .8, power: 1, k: 2 });
      for (const t of ['shield', 'medic', 'spotter', 'fire']) P.spawnEnemyAt(t, P.N - 1.5, 4.5) });
    await H.waitForTimeout(1200);
    out.quarryGuest = await G.evaluate(() => { const P = __pal; return { pits: P.terr.filter(t => t === 5).length, lobKinds: P.lobs.map(l => l.k).sort().join(), types: [...new Set(P.enemies.map(e => e.type))].sort().join(),
      burrow: P.enemies.some(e => e.boss === 'foreman' && e.burrow) } });
    await H.waitForTimeout(3500);
    out.slabOnGuest = await G.evaluate(() => __pal.walls.some(w => w && w.slab));
    out.slabOnHost = await H.evaluate(() => __pal.walls.some(w => w && w.slab));
    await G.screenshot({ path: __dirname + '/out/v090_net_guest.png' });
    await H.close(); await G.close();
  }
  console.log(JSON.stringify(out, null, 1));
  assert.equal(out.flood, true); assert.equal(out.raft, true); assert.equal(out.bridgeOnGuest, 2); assert.deepEqual(out.bossLogGuest, ['ferryman']); assert.ok(out.sameGroundRiver);
  assert.equal(out.quarryGuest.pits > 0, true); assert.equal(out.quarryGuest.lobKinds, '1,2'); assert.match(out.quarryGuest.types, /fire.*medic.*shield.*spotter/);
  assert.equal(out.quarryGuest.burrow, true); assert.equal(out.slabOnGuest, out.slabOnHost); assert.equal(out.slabOnHost, true);
  console.log('errors:', errors.length ? errors : 'none');
  await b.close();
})().catch(e => { console.log('Error:', e.message); process.exit(1) });
