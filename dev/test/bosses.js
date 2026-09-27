// v0.8.1 feature tests: shotgun, quartermaster, wall salvage, bosses (solo, host-side sim)
const { chromium } = require('playwright');
const O = __dirname + '/out';
(async () => {
  const b = await chromium.launch({ executablePath:process.env.CHROMIUM||undefined });
  const p = await b.newPage({ viewport: { width: 1400, height: 860 } });
  const errs = []; p.on('pageerror', e => errs.push(e.message + ' ' + (e.stack || '').split('\n')[1]));
  const P = f => p.evaluate(f), W = ms => p.waitForTimeout(ms), log = (...a) => console.log(...a);
  const start = async cls => {
    await p.goto('http://localhost:8080/debug.html?debug=1'); await W(700); await p.mouse.move(700, 430);
    await p.click('[data-go=solo]'); await p.click(`[data-c=${cls}]`); await p.click('#startBtn'); await W(400);
  };

  // ---------- 1. Grenadier shotgun
  await start('grenadier');
  log('grenadier gun', await P(() => { const g = __pal.player.gun; return { pellets: g.pellets, dmg: g.dmg, cd: g.cd, spread: g.spread, range: g.range, mag: g.mag, ammo: __pal.player.ammo, nades: __pal.player.maxN } }));
  await P(() => __pal.startRaid()); await W(200);
  // one click -> one blast of 7 pellets, one shell used
  await P(() => { window.__n0 = __pal.bullets.filter(b => b.own === __pal.player.id).length });
  await p.mouse.move(1100, 430); await p.mouse.down(); await W(40); await p.mouse.up(); await W(60);
  log('one pull ->', await P(() => ({ pellets: __pal.bullets.filter(b => b.own === __pal.player.id).length - window.__n0, ammo: __pal.player.ammo })));
  // falloff
  log('pellet damage at 1 / 4 / 7 tiles', await P(() => [1, 4, 7].map(d => Math.round(__pal.bdmg({ dmg: 10, fall: [2.5, 7, .5], dist: d }) * 10) / 10)));
  // empty the tube: 5 more pulls, then try again (dry), then watch it reload shell by shell
  for (let k = 0; k < 6; k++) { await p.mouse.down(); await W(30); await p.mouse.up(); await W(760) }
  log('after 6 more pulls: ammo', await P(() => __pal.player.ammo), 'reloading', await P(() => __pal.player.rl > 0));
  await p.screenshot({ path: O + '/f_shotgun_reload.png' });
  const t0 = Date.now(); const seen = [];
  for (let k = 0; k < 8; k++) { await W(400); seen.push(await P(() => __pal.player.ammo)) }
  log('ammo while reloading (every 0.4s):', seen.join(' '));
  // R reloads a partial tube after firing
  await p.mouse.down(); await W(30); await p.mouse.up(); await W(100);
  const a1 = await P(() => __pal.player.ammo); await p.keyboard.press('r'); await W(500);
  log('partial tube', a1, '-> after R + 0.5s', await P(() => __pal.player.ammo));
  log('key bar', await P(() => document.getElementById('keys').textContent));
  // PvP-free damage on raiders: blast a rifleman at close range
  const kill = await P(async () => {
    const P = __pal, pl = P.player; P.enemies.length = 0; P.bullets.length = 0;
    P.enemies.push({ id: 999, type: 'rifle', x: pl.x + 1.5, y: pl.y, hp: 36, max: 36, cd: 9, walk: 0, aim: { x: -1, y: 0 }, flash: 0, speed: 0, scanT: 9, foe: null, planted: false });
    pl.aim = { x: 1, y: 0 }; pl.ammo = 6; pl.cd = 0; pl.bolt = 0; pl.pullIn = (pl.pullIn + 1) & 255; pl.pullT = P.game.time;
    await new Promise(r => setTimeout(r, 400)); return { alive: P.enemies.some(e => e.id === 999), sal: pl.sal };
  });
  log('one blast at 1.5 tiles on a 36hp rifleman: still alive?', kill.alive);

  // ---------- 2. Quartermaster
  await start('quartermaster');
  log('qm', await P(() => { const pl = __pal.player; return { cap: pl.cap, gun: pl.gun.snd, gather: pl.C.gather, repair: pl.C.repair } }));
  // a downed teammate: walking over them gets them up instantly, once
  const rv = await P(async () => {
    const P = __pal, pl = P.player, m = P.makePlayer('mate', 'Ace', 'soldier', 1, 'std|class|std|none', ''); P.players.set('mate', m);
    m.x = pl.x + 2; m.y = pl.y; m.alive = false; m.downed = true; m.hp = 0; m.rt = 10;
    const r0 = P.game.stats.revives;
    await new Promise(r => setTimeout(r, 300)); const before = { alive: m.alive };
    pl.x = m.x - .3; pl.y = m.y; await new Promise(r => setTimeout(r, 120));
    const after = { alive: m.alive, hp: Math.round(m.hp), max: m.max, revives: P.game.stats.revives - r0 };
    await new Promise(r => setTimeout(r, 500)); after.revivesLater = P.game.stats.revives - r0;
    // Dell too
    P.qm.alive = false; P.qm.hp = 0; P.qm.x = pl.x + .4; P.qm.y = pl.y; await new Promise(r => setTimeout(r, 120));
    after.dellUp = P.qm.alive; after.dellHp = Math.round(P.qm.hp);
    P.players.delete('mate'); return { before, after };
  });
  log('quartermaster instant revive', JSON.stringify(rv));
  // repairs for half: a wall at half health
  log('repair cost qm vs soldier', await P(() => {
    const P = __pal, pl = P.player, i = Math.floor(pl.x) + 1, j = Math.floor(pl.y) - 2, w = P.makeWall(0, false, .5); P.walls2[j * 16 + i] = w;
    const a = P.buildEval(pl, i, j, 0, false).cost; const s = P.makePlayer('s', 'S', 'soldier', 2, '', ''); s.x = pl.x; s.y = pl.y; const b2 = P.buildEval(s, i, j, 0, false).cost; P.walls2[j * 16 + i] = null; return { qm: a, soldier: b2 };
  }));

  // ---------- 3. wall salvage
  await start('soldier');
  const sv = await P(() => {
    const P = __pal, pl = P.player, W = P.walls2, out = {};
    const ruins = []; for (let k = 0; k < 256; k++) if (W[k] && !W[k].crew) ruins.push([k, W[k].mat]);
    out.ruins = ruins.map(r => r[1]).join('');
    const s0 = pl.sal; const wood = ruins.find(r => r[1] === 0)[0], brick = ruins.find(r => r[1] === 1)[0];
    P.damageWall(wood, 9999, pl.id); out.wood = pl.sal - s0;
    P.damageWall(wood, 9999, pl.id); out.woodAgain = pl.sal - s0;           // already gone: nothing more
    P.damageWall(brick, 9999, pl.id); out.brickTotal = pl.sal - s0;
    // metal ruin made for the test
    W[5] = P.makeWall(2, false); P.damageWall(5, 99999, pl.id); out.metalTotal = pl.sal - s0;
    // own wall: build then break -> nothing
    const i = Math.floor(pl.x) + 1, j = Math.floor(pl.y); pl.mats[0] = 20; pl.bcd = 0; P.doBuild(pl, i, j, 0, false); const k = j * 16 + i; out.built = !!W[k] && !!W[k].crew;
    const s1 = pl.sal; P.damageWall(k, 9999, pl.id); out.ownWall = pl.sal - s1;
    // raiders knocking down a ruin: no one paid
    const r3 = ruins.find(r => r[1] === 0 && W[r[0]]); const s2 = pl.sal; if (r3) P.damageWall(r3[0], 9999, null); out.byRaiders = pl.sal - s2;
    return out;
  });
  log('wall salvage', JSON.stringify(sv));
  await W(300); await p.screenshot({ path: O + '/f_salvage.png' });

  // ---------- 4. bosses
  await start('soldier');
  log('boss schedule', await P(() => [1, 4, 5, 9, 10, 15, 20, 25, 30].map(w => w + ':' + (__pal.game.waves, (w % 5 === 0 ? ['demolisher', 'butcher', 'storm'][(w / 5 - 1) % 3] : '-'))).join(' ')));
  const q = await P(() => { const P = __pal; P.game.wave = 4; P.startRaid(); return { wave: P.game.wave, queue: P.game.queue.join(','), toast: document.getElementById('toast').textContent } });
  log('raid 5 queue:', q.queue); log('raid 5 toast:', q.toast);
  // demolisher vs the player standing still in the open
  const dm = await P(async () => {
    const P = __pal, pl = P.player; P.game.queue.length = 0; P.enemies.length = 0; pl.hp = pl.max = 99999;
    P.spawnBoss('demolisher'); const e = P.enemies[0]; e.x = pl.x + 6; e.y = pl.y - .2; e.cd = .1;
    const seen = { st: new Set(), rockets: 0, fires: 0 }; let hp0 = pl.hp;
    for (let k = 0; k < 60; k++) { await new Promise(r => setTimeout(r, 100)); seen.st.add(e.st); seen.rockets = Math.max(seen.rockets, P.rockets.length); seen.fires = Math.max(seen.fires, P.fires.length) }
    return { hp: Math.round(e.max), states: [...seen.st].join(','), maxRockets: seen.rockets, fires: seen.fires, dmgTaken: Math.round(hp0 - pl.hp), toast: document.getElementById('toast').textContent };
  });
  log('demolisher', JSON.stringify(dm));
  // screenshot with telegraph up
  await P(async () => { const P = __pal, e = P.enemies[0]; e.cd = 0; e.st = 0; for (let k = 0; k < 40 && e.st === 0; k++)await new Promise(r => setTimeout(r, 25)); await new Promise(r => setTimeout(r, 350)) });
  await p.screenshot({ path: O + '/f_demolisher.png' });
  // butcher
  const bu = await P(async () => {
    const P = __pal, pl = P.player; P.enemies.length = 0; P.rockets.length = 0; pl.hp = pl.max = 99999;
    P.spawnBoss('butcher'); const e = P.enemies[0]; e.x = pl.x + 5; e.y = pl.y; e.ab = 0; const st = new Set(); let hp0 = pl.hp, slashes = 0;
    for (let k = 0; k < 80; k++) { await new Promise(r => setTimeout(r, 50)); st.add(e.st); slashes = Math.max(slashes, P.slashes.length) }
    const d = Math.hypot(e.x - pl.x, e.y - pl.y);
    e.hp = e.max * .3; await new Promise(r => setTimeout(r, 300));
    return { states: [...st].join(','), dmgTaken: Math.round(hp0 - pl.hp), slashes, endDist: d.toFixed(2), rage: !!e.rage, speed: e.speed.toFixed(2) };
  });
  log('butcher', JSON.stringify(bu));
  await P(async () => { const P = __pal, e = P.enemies[0], pl = P.player; e.x = pl.x + 4; e.y = pl.y + .3; e.st = 0; e.ab = 0; for (let k = 0; k < 60 && e.st !== 2; k++)await new Promise(r => setTimeout(r, 20)) });
  await p.screenshot({ path: O + '/f_butcher.png' });
  // stormcaller, with Dell nearby so the bolt can jump
  const sc = await P(async () => {
    const P = __pal, pl = P.player; P.enemies.length = 0; pl.hp = pl.max = 99999;
    P.spawnBoss('storm'); const e = P.enemies[0]; e.x = pl.x + 8; e.y = pl.y; e.cd = .1; P.qm.alive = true; P.qm.hp = P.qm.max = 99999; P.qm.x = pl.x - .8; P.qm.y = pl.y + .8;
    const st = new Set(); let hp0 = pl.hp, zaps = 0, stun = 0, chain = 0;
    for (let k = 0; k < 90; k++) { await new Promise(r => setTimeout(r, 50)); st.add(e.st); if (P.zaps.length) { zaps++; chain = Math.max(chain, P.zaps[0].pts.length / 2 - 1) } stun = Math.max(stun, pl.stun || 0) }
    return { states: [...st].join(','), dmgTaken: Math.round(hp0 - pl.hp), zapFrames: zaps, maxStun: stun.toFixed(2), chainTargets: chain, qmHurt: P.qm.hp < 99999 };
  });
  log('stormcaller', JSON.stringify(sc));
  await P(async () => { const P = __pal, e = P.enemies[0]; e.cd = 0; e.st = 0; for (let k = 0; k < 60 && e.st === 0; k++)await new Promise(r => setTimeout(r, 20)); await new Promise(r => setTimeout(r, 500)) });
  await p.screenshot({ path: O + '/f_storm.png' });
  // killing a boss pays the killer 40 and ends the raid when the rest are gone
  const kd = await P(async () => {
    const P = __pal, pl = P.player, e = P.enemies[0], s0 = pl.sal;
    e.hp = 1; P.explode(e.x, e.y, 1, 1, pl.id);
    await new Promise(r => setTimeout(r, 600));
    return { bossGone: !P.enemies.some(x => x.type === 'boss'), salGain: pl.sal - s0, phase: P.game.phase, toast: document.getElementById('toast').textContent };
  });
  log('boss down', JSON.stringify(kd));
  log('errors:', errs.length ? errs : 'none');
  await b.close();
})();
