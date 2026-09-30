// v0.8.7 checks: soldier bursts, sniper hold-to-fire, class speeds + quartermaster sprint, Repair Core,
// Dell's shared upgrade and shotgun, leftover salvage -> shards, and aiming at the drawn body (hitboxes).
const { chromium } = require('playwright');
const O = __dirname + '/out';
const ok = (c, m) => { if (!c) { fails.push(m); console.log('  NOT OK:', m) } };
const fails = [];
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined });
  const errs = [];
  const open = async (cls) => {
    const p = await b.newPage({ viewport: { width: 1600, height: 900 } });
    p.on('pageerror', e => errs.push(e.message + ' ' + (e.stack || '').split('\n')[1]));
    await p.goto('http://localhost:8080/debug.html?debug=1'); await p.waitForTimeout(700);
    await p.mouse.move(800, 450);
    await p.click('[data-go=solo]'); await p.click('[data-setup=job]:visible'); await p.click(`#setupSheet [data-c=${cls}]`); await p.click('#setupDone'); await p.click('#startBtn'); await p.waitForTimeout(400);
    return p;
  };
  // records the game time of every bullet the player fires (poll each frame; bullet ids only go up)
  const recShots = p => p.evaluate(() => { window.__sh = []; let seen = 0; const P = __pal;
    const f = () => { for (const q of P.bullets) if (q.own === P.player.id && q.id > seen) { seen = q.id; window.__sh.push(+P.game.time.toFixed(3)) } requestAnimationFrame(f) }; f() });
  const bursts = t => { const g = []; let cur = []; for (let i = 0; i < t.length; i++) { if (i && t[i] - t[i - 1] > .15) { g.push(cur); cur = [] } cur.push(t[i]) } if (cur.length) g.push(cur); return g };
  // a clear patch of ground with nobody around, the player facing east (screen right-down)
  const quiet = p => p.evaluate(() => { const P = __pal; P.startRaid(); P.game.queue = []; for (const e of P.enemies) e.dead = true; P.player.x = 8.5; P.player.y = 3.5 });

  // ---- 1. Soldier burst
  {
    const p = await open('soldier'); await quiet(p); await recShots(p);
    await p.mouse.move(1250, 300); await p.mouse.down(); await p.waitForTimeout(2600); await p.mouse.up(); await p.waitForTimeout(400);
    let g = bursts(await p.evaluate(() => window.__sh));
    const sizes0 = g.map(x => x.length), gaps0 = g.slice(1).map((x, i) => +(x[0] - g[i][g[i].length - 1]).toFixed(2));
    console.log('soldier DAMAGE 0: burst sizes', sizes0.join(','), '| pause between bursts', gaps0.join(','));
    ok(sizes0.length >= 3 && sizes0.every(n => n === 3), 'level-0 bursts are 3 rounds');
    ok(gaps0.every(x => x > .36 && x < .48), 'level-0 pause ~0.40 s');
    // a single short click still fires the whole burst
    await p.evaluate(() => { window.__sh.length = 0 }); await p.waitForTimeout(600);
    await p.mouse.down(); await p.waitForTimeout(20); await p.mouse.up(); await p.waitForTimeout(700);
    const tap = (await p.evaluate(() => window.__sh)).length; console.log('one quick click fired', tap, 'rounds'); ok(tap === 3, 'a tap fires a full burst');
    await p.evaluate(() => { const pl = __pal.player; pl.up.d = 4; window.__sh.length = 0 }); await p.waitForTimeout(600);
    await p.mouse.down(); await p.waitForTimeout(3000); await p.mouse.up(); await p.waitForTimeout(1200);
    g = bursts(await p.evaluate(() => window.__sh));
    const sizes4 = g.map(x => x.length), gaps4 = g.slice(1).map((x, i) => +(x[0] - g[i][g[i].length - 1]).toFixed(2));
    console.log('soldier DAMAGE 4: burst sizes', sizes4.join(','), '| pause', gaps4.join(','));
    ok(sizes4.length >= 2 && sizes4.every(n => n === 9), 'level-4 bursts are 9 rounds');
    ok(gaps4.every(x => x > .17 && x < .28), 'level-4 pause ~0.20 s (the floor)');
    console.log('burst table', await p.evaluate(() => [0, 1, 2, 3, 4].map(d => { const q = { up: { d } }; return __pal.burstN(q) + '@' + __pal.burstGap(q).toFixed(2) }).join(' ')));
    // ---- speed: soldier baseline
    const walk = async () => { await p.evaluate(() => { const pl = __pal.player; pl.x = 3.5; pl.y = 8.5; window.__x0 = pl.x; window.__t0 = performance.now() });
      await p.keyboard.down('d'); await p.waitForTimeout(700); await p.keyboard.up('d');
      return p.evaluate(() => { const pl = __pal.player; return Math.hypot(pl.x - 3.5, pl.y - 8.5) / ((performance.now() - window.__t0) / 1000) }) };
    const sp = await walk(); console.log('soldier speed', sp.toFixed(2), 'tiles/s');
    await p.close();
    // ---- 2. Sniper hold-to-fire + speed
    const s = await open('sniper'); await quiet(s); await recShots(s);
    await s.mouse.move(1250, 300); await s.mouse.down(); await s.waitForTimeout(3000); await s.mouse.up(); await s.waitForTimeout(200);
    const st = await s.evaluate(() => window.__sh), gp = st.slice(1).map((x, i) => +(x - st[i]).toFixed(2));
    console.log('sniper holding 3 s:', st.length, 'shots, gaps', gp.join(','));
    ok(st.length >= 4 && gp.every(x => x > .65 && x < .8), 'sniper fires every ~0.7 s while held');
    const walkS = async () => { await s.evaluate(() => { const pl = __pal.player; pl.x = 3.5; pl.y = 8.5; window.__t0 = performance.now() });
      await s.keyboard.down('d'); await s.waitForTimeout(700); await s.keyboard.up('d');
      return s.evaluate(() => { const pl = __pal.player; return Math.hypot(pl.x - 3.5, pl.y - 8.5) / ((performance.now() - window.__t0) / 1000) }) };
    const ss = await walkS(); console.log('sniper speed', ss.toFixed(2), '=', (ss / sp).toFixed(2) + 'x soldier');
    ok(ss / sp > 1.03 && ss / sp < 1.17, 'sniper ~1.1x soldier');
    await s.close();
    // ---- 3. Grenadier speed, quartermaster sprint
    const gr = await open('grenadier'); await quiet(gr);
    await gr.evaluate(() => { const pl = __pal.player; pl.x = 3.5; pl.y = 8.5; window.__t0 = performance.now() });
    await gr.keyboard.down('d'); await gr.waitForTimeout(700); await gr.keyboard.up('d');
    const gs = await gr.evaluate(() => { const pl = __pal.player; return Math.hypot(pl.x - 3.5, pl.y - 8.5) / ((performance.now() - window.__t0) / 1000) });
    console.log('grenadier speed', gs.toFixed(2), '=', (gs / sp).toFixed(2) + 'x soldier'); ok(gs / sp > .83 && gs / sp < .97, 'grenadier ~0.9x');
    ok(await gr.evaluate(() => document.getElementById('sprBtn').hidden), 'no sprint button for the grenadier');
    await gr.keyboard.press('Shift'); ok(await gr.evaluate(() => !(__pal.player.sprT > 0)), 'Shift does nothing for the grenadier');
    await gr.close();
    const q = await open('quartermaster'); await quiet(q); await recShots(q);
    ok(await q.evaluate(() => !document.getElementById('sprBtn').hidden), 'sprint button shows for the quartermaster');
    await q.evaluate(() => { const pl = __pal.player; pl.x = 3.5; pl.y = 8.5 });
    await q.keyboard.press('Shift'); await q.evaluate(() => { window.__t0 = performance.now() });
    await q.mouse.move(1250, 300); await q.mouse.down(); await q.keyboard.down('d'); await q.waitForTimeout(700); await q.keyboard.up('d');
    const qs = await q.evaluate(() => { const pl = __pal.player; return Math.hypot(pl.x - 3.5, pl.y - 8.5) / ((performance.now() - window.__t0) / 1000) });
    const firedSprinting = (await q.evaluate(() => window.__sh)).length;
    console.log('quartermaster sprinting', qs.toFixed(2), '=', (qs / sp).toFixed(2) + 'x soldier; shots while sprinting', firedSprinting,
      '| button', await q.evaluate(() => document.getElementById('sprN').textContent));
    ok(qs / sp > 1.3 && qs / sp < 1.5, 'sprint ~1.4x'); ok(firedSprinting === 0, 'no shooting while sprinting');
    await q.waitForTimeout(2200);
    const after = await q.evaluate(() => ({ spr: __pal.player.sprT, cd: +__pal.player.sprCd.toFixed(1), n: window.__sh.length, lab: document.getElementById('sprN').textContent }));
    console.log('after the sprint ends:', JSON.stringify(after)); ok(after.spr === 0 && after.n > 0 && after.cd > 5, 'sprint ends, shooting resumes, ~6 s recharge');
    await q.keyboard.press('Shift'); ok(await q.evaluate(() => !(__pal.player.sprT > 0)), 'no sprint while recharging');
    await q.mouse.up();
    await q.screenshot({ path: O + '/v087_sprint.png' });
    // ---- 4. Armory: Repair Core (QM pays half) and Dell
    const arm = await q.evaluate(() => {
      const P = __pal, pl = P.player, c = P.cores[0], r = {};
      for (const e of P.enemies) e.dead = true; P.game.phase = 'build'; P.game.timer = 99; const k = c;
      pl.x = k.i + .5 + 1.2; pl.y = k.j + .5; pl.sal = 100;
      c.hp = c.max - 30; r.full30 = [P.buyUpgrade(pl, 'core'), c.hp === c.max, pl.sal];
      r.whenFull = [P.buyUpgrade(pl, 'core'), pl.sal];
      c.hp = c.max - 120; r.missing120 = [P.buyUpgrade(pl, 'core'), c.max - c.hp, pl.sal];
      pl.sal = 5; r.broke = [P.buyUpgrade(pl, 'core'), c.max - c.hp, pl.sal];
      pl.sal = 400; const d0 = P.dellGun();
      r.dell = []; for (let i = 0; i < 5; i++) r.dell.push([P.buyUpgrade(pl, 'dell'), P.game.dellLv, pl.sal]);
      const d4 = P.dellGun(); r.gun0 = { dmg: d0.dmg, cd: d0.cd, range: d0.range, pellets: d0.pellets }; r.gun4 = { dmg: +d4.dmg.toFixed(2), cd: +d4.cd.toFixed(3), range: +d4.range.toFixed(2), fall: d4.fall.map(x => +x.toFixed(2)) };
      r.dellHp = [P.qm.hp, P.qm.max];
      return r });
    console.log('armory', JSON.stringify(arm));
    ok(arm.full30[0] && arm.full30[1] && arm.full30[2] === 87, 'repair when 30 missing: back to full, QM pays 13');
    ok(!arm.whenFull[0] && arm.whenFull[1] === 87, 'full core: refused, nothing charged');
    ok(arm.missing120[1] === 70, 'repair adds 50 at most');
    ok(!arm.broke[0], "can't repair without the salvage");
    ok(arm.dell.map(x => x[1]).join() === '1,2,3,4,4' && arm.dell[4][0] === false && arm.dell[3][2] === 60, 'Dell levels 1-4 for 30/60/100/150, then maxed');
    ok(arm.gun4.dmg === 9.6 && arm.gun4.cd === .5 && arm.gun4.range === 9.6, 'Dell level 4 = +60% damage, range, fire rate');
    ok(arm.dellHp[1] === 180, 'Dell has 180 health');
    await q.evaluate(() => { document.getElementById('armory').hidden = false; __pal.renderArmory() }); await q.waitForTimeout(150);
    await q.screenshot({ path: O + '/v087_armory.png' });
    const rows = await q.evaluate(() => [...document.querySelectorAll('#armRows .arow')].map(r => r.querySelector('b').textContent + ':' + r.querySelector('button').textContent));
    console.log('armory rows', rows.join(' | ')); ok(rows.length === 7 && rows.some(x => x.startsWith('DELGADO')) && rows.some(x => x.startsWith('REPAIR CORE')), 'armory has DELGADO and REPAIR CORE rows');
    await q.evaluate(() => { document.getElementById('armory').hidden = true });
    await q.close();
  }
  // ---- 5. Dell's shotgun in a fight
  {
    const p = await open('soldier');
    const r = await p.evaluate(async () => { const P = __pal; P.startRaid(); P.player.x = 14; P.player.y = 14;
      window.__dl = []; let seen = 0, stop = false;
      const f = () => { for (const b of P.bullets) if (b.own === 'dell' && b.id > seen) { seen = b.id; window.__dl.push(+P.game.time.toFixed(2)) } if (!stop) requestAnimationFrame(f) }; f();
      const t0 = performance.now();
      while (performance.now() - t0 < 15000) { const e = P.enemies.find(x => !x.dead); if (e) { e.x = P.qm.x + 2.5; e.y = P.qm.y; e.hp = 999; e.max = 999; e.cd = 9 } await new Promise(r => setTimeout(r, 250)); if (window.__dl.length >= 25) break }
      stop = true; const t = window.__dl, g = {}; for (const x of t) g[x] = (g[x] || 0) + 1;
      return { volleys: Object.keys(g).length, pellets: Object.values(g) } });
    console.log('Dell in a fight: volleys', r.volleys, 'pellets per volley', r.pellets.join(','));
    ok(r.volleys > 0 && r.pellets.every(n => n === 5 || n === 10), 'Dell fires 5-pellet volleys');
    await p.close();
  }
  // ---- 6. salvage -> shards
  {
    const p = await open('soldier');
    const r = await p.evaluate(() => { const P = __pal, f = P.salvageShards;
      const table = [[0, 5], [19, 5], [20, 5], [137, 5], [250, 5], [250, 3], [1000, 40], [60, 0]].map(([s, h]) => `${s}sal/${h}held=${f(s, h)}`);
      const pl = P.player, L = P.locker; pl.sal = 137; const sh0 = L.shards | 0; P.game.won = true; P.game.wave = 5; P.game.phase = 'over';
      const cloud = L.cloud; L.cloud = null;
      P.showOver(); const once = [L.shards - sh0, pl.sal, document.getElementById('overLoot').textContent];
      P.showOver(); const twice = [L.shards - sh0, pl.sal];
      return { table, once, twice } });
    console.log('shards', r.table.join('  '));
    console.log('end of a 5-raid win with 137 salvage left:', JSON.stringify(r.once), '| showing the end screen again:', JSON.stringify(r.twice));
    ok(r.table.join() === '0sal/5held=0,19sal/5held=0,20sal/5held=1,137sal/5held=6,250sal/5held=10,250sal/3held=6,1000sal/40held=10,60sal/0held=0', 'conversion table');
    ok(r.once[0] === 6 && r.once[1] === 17 && /\+6 shards from leftover salvage/.test(r.once[2]), '6 shards, 120 salvage consumed, shown on the end screen (wording since v0.9.1)');
    ok(r.twice[0] === 6 && r.twice[1] === 17, 'no double conversion');
    await p.close();
  }
  // ---- 7. aiming at the drawn body (hitbox)
  {
    const p = await open('soldier');
    const r = await p.evaluate(async () => { const P = __pal; P.startRaid();
      const pl = P.player; pl.x = 5.5; pl.y = 9.5; let e;
      while (!(e = P.enemies.find(x => !x.dead))) await new Promise(r => setTimeout(r, 100));
      P.game.paused = true; for (const o of P.enemies) if (o !== e) o.dead = true;
      // put the raider level with the player on screen (to their right), where the old mapping missed worst
      e.x = pl.x + 3; e.y = pl.y - 3; e.hp = 999; e.max = 999;
      P.walls.fill(null);   // a clear line of fire (the brick ruins sit right beside this line)
      await new Promise(r => setTimeout(r, 100));
      const [ex, ey] = P.iso(e.x, e.y), k = P.u * 1.18, res = [];
      for (const [lab, hy] of [['boots', -2], ['chest', -18], ['head', -29], ['helmet top', -35]]) {
        P.setMouse(ex, ey + hy * k, false); await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)));
        const a = pl.aim, dx = e.x - pl.x, dy = e.y - pl.y, miss = Math.abs(dx * a.y - dy * a.x);
        // what the old aim did with the same cursor
        const W = (sx, sy) => { const A = (sx - P.camX) / (P.u * 40 / 1.25 * 1), B = 0; return null };
        res.push([lab, +miss.toFixed(2)]) }
      // old behaviour for comparison: cursor-to-ground at hip height
      const old = []; for (const hy of [-2, -18, -29, -35]) { const sy = ey + hy * k + (P.u * 16 * 1.7) * .55, sx = ex; const TW2 = 32 * P.u, TH2 = 16 * P.u;
        const A = (sx - P.camX) / TW2, B = (sy - P.camY) / TH2, wx = (A + B) / 2, wy = (B - A) / 2, dx = wx - pl.x, dy = wy - pl.y, l = Math.hypot(dx, dy), ex2 = e.x - pl.x, ey2 = e.y - pl.y;
        old.push(+Math.abs(ex2 * dy / l - ey2 * dx / l).toFixed(2)) }
      // and a real shot at the head
      // hold fire on the head of a raider that stands still: count rounds and hits
      e.speed = 0; let seen = 0; for (const b of P.bullets) seen = Math.max(seen, b.id | 0); const fired = new Set();
      const hp0 = e.hp; P.setMouse(ex, ey - 29 * k, true); P.game.paused = false;
      const t0 = performance.now(); while (performance.now() - t0 < 1500) { for (const b of P.bullets) if (b.own === pl.id && b.id > seen) fired.add(b.id); e.x = pl.x + 3; e.y = pl.y - 3; await new Promise(r => requestAnimationFrame(r)) }
      P.setMouse(ex, ey - 29 * k, false); await new Promise(r => setTimeout(r, 400));
      return { res, old, rounds: fired.size, hits: Math.round((hp0 - e.hp) / 12) } });
    console.log('miss distance (tiles) from the raider\'s centre, hit radius 0.34. New:', r.res.map(x => x.join(' ')).join(', '), '| old aim:', r.old.join(', '));
    console.log('holding fire on the head for 1.5 s:', r.rounds, 'rounds,', r.hits, 'hits');
    ok(r.res.every(x => x[1] < .05), 'cursor anywhere on the body aims at it'); ok(r.rounds >= 6 && r.hits >= r.rounds * .8, 'head shots land');
    await p.screenshot({ path: O + '/v087_aim.png' });
    await p.close();
  }
  console.log('errors', errs.length ? errs : 'none');
  console.log(fails.length ? 'FAILED: ' + fails.join('; ') : 'all checks ok');
  await b.close();
  if (fails.length) process.exit(1);
})().catch(e => { console.log('Error:', e.message); process.exit(1) });
