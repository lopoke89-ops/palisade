// v0.9.2 modifiers: which ones each mode lists, what every one of the 15 does when it's on (and that it does nothing
// when it's off), the reward bonus and the in-between (shard) bosses, best scores per modifier set, and a host and
// guest online: the host's picks reach the guest's room and game. node modifiers.js
const { chromium } = require('playwright');
const assert = require('assert');
const Q = 'peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1', PORT = process.env.PORT || 8080;
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--disable-features=WebRtcHideLocalIpsWithMdns'] });
  const errors = [], out = {};process.on('exit', () => console.log('OUT', JSON.stringify(out)));
  const open = async (vp = { width: 1280, height: 800 }) => { const p = await b.newPage({ viewport: vp }); p.on('pageerror', e => errors.push(e.message)); await p.goto(`http://localhost:${PORT}/debug.html?${Q}`); await p.waitForTimeout(800); return p };
  const P = await open();
  // 1. the lists per mode
  out.lists = await P.evaluate(() => ({ coop: __pal.MODS.filter(m => m.modes.includes('coop')).map(m => m.id), base: __pal.MODS.filter(m => m.modes.includes('base')).map(m => m.id), ffa: __pal.MODS.filter(m => m.modes.includes('ffa')).map(m => m.id),
    clean: __pal.cleanMods(['glass', 'weather', 'bogus', 'weather', 'nopatch'], 'ffa') }));
  assert.deepEqual(out.lists.coop, ['nopatch', 'alone', 'firestorm', 'adrenaline', 'laststand', 'elite', 'bossrush', 'weather', 'nightmare', 'berserk']);
  assert.deepEqual(out.lists.base, ['adrenaline', 'weather', 'nightmare', 'glass', 'onejob', 'scrap', 'frenzy']);
  assert.deepEqual(out.lists.ffa, ['adrenaline', 'weather', 'nightmare', 'glass', 'onejob', 'frenzy', 'sudden']);
  assert.deepEqual(out.lists.clean, ['weather', 'glass'], 'unknown, repeated and wrong-mode ids are dropped');
  // the SOLO page lists the co-op ones and remembers the picks
  await P.click('[data-go=solo]'); await P.waitForTimeout(200);
  out.soloChips = await P.$$eval('#soloMods .modChip', x => x.length); assert.equal(out.soloChips, 10);
  await P.click('#soloMods [data-mod=alone]'); await P.click('#soloMods [data-mod=adrenaline]');
  out.soloTag = await P.textContent('#soloModTag'); assert.match(out.soloTag, /2 ON · REWARDS \+5%/);
  out.heading = await P.textContent('#partyMods'); assert.match(out.heading, /ON YOUR OWN · ADRENALINE/);
  out.bonus = await P.evaluate(() => [__pal.modBonus(['alone', 'adrenaline'], ''), __pal.modBonus(['nopatch', 'alone', 'firestorm', 'laststand', 'elite', 'bossrush', 'weather', 'nightmare', 'berserk'], ''), __pal.modBonus(['adrenaline'], 'ffa')]);
  assert.deepEqual(out.bonus, [5, 75, -15], 'bonus capped at +75%');
  await P.click('#soloMods [data-mod=alone]'); await P.click('#soloMods [data-mod=adrenaline]');   // off again
  // a helper: a fresh solo game with these modifiers
  const game = (mods, pvp = '', extra = '') => P.evaluate(([mods, pvp, extra]) => { const P = __pal; P.demo = false; P.pick.mode = '10'; P.pick.diff = 'normal'; P.pick.map = 'yard'; P.pick.size = 'std';
    const roster = pvp ? [{ id: 'solo', name: 'A', cls: 'soldier', cos: '' }, { id: 'b', name: 'B', cls: 'sniper', cos: '' }] : null;
    P.newGame(roster, pvp, { mods, job: extra }); P.enterGameHook(); return P.game.mods }, [mods, pvp, extra]);
  // 2. No Patch-Ups
  await game(['nopatch']);
  out.nopatch = await P.evaluate(() => { const P = __pal, p = P.player; p.sal = 999; P.core.hp = 100; [p.x, p.y] = [P.core.i + 1.5, P.core.j + .5]; const r = P.buyUpgrade(p, 'core'); P.renderArmory(); return { bought: r, row: [...document.querySelectorAll('#armRows .arow b')].some(b => /REPAIR CORE/.test(b.textContent)) } });
  assert.deepEqual(out.nopatch, { bought: false, row: false });
  await game([]);
  out.patchOff = await P.evaluate(() => { const P = __pal, p = P.player; p.sal = 999; P.core.hp = 100; [p.x, p.y] = [P.core.i + 1.5, P.core.j + .5]; return P.buyUpgrade(p, 'core') });
  assert.equal(out.patchOff, true);
  // 3. On Your Own: no Dell, not even after a raid
  await game(['alone']);
  out.alone = await P.evaluate(() => { const P = __pal; P.startRaid(); P.game.queue = []; for (const e of P.enemies) e.dead = true; P.update(.05); P.update(.05); P.hud(0);
    return { gone: P.qm.gone, alive: P.qm.alive, phase: P.game.phase, meter: document.getElementById('qmM').hidden } });
  assert.deepEqual(out.alone, { gone: true, alive: false, phase: 'build', meter: true });
  // 4. Firestorm: more firebrands from raid 1, bigger and longer fires, walls burn faster
  await game(['firestorm']);
  out.firestorm = await P.evaluate(() => { const P = __pal; P.startRaid(); const q = P.game.queue.filter(x => x === 'fire').length;
    P.lobs.push({ x0: 5, y0: 5, x1: 6.5, y1: 6.5, t: 0, T: .01, R: 1, power: 1, k: 1 }); P.updateLobs(.05); const f = P.fires2[P.fires2.length - 1];
    const k = 3 * P.N + 3; P.walls[k] = P.makeWall(0); P.walls[k].fire = 5; const h0 = P.walls[k].hp; for (let i = 0; i < 10; i++) P.update(.05); return { fireRaid1: q, t: f.t, r: f.r, burn: +(h0 - (P.walls[k] ? P.walls[k].hp : 0)).toFixed(1) } });
  await game([]);
  out.firestormOff = await P.evaluate(() => { const P = __pal; P.startRaid(); const q = P.game.queue.filter(x => x === 'fire').length;
    P.lobs.push({ x0: 5, y0: 5, x1: 6.5, y1: 6.5, t: 0, T: .01, R: 1, power: 1, k: 1 }); P.updateLobs(.05); const f = P.fires2[P.fires2.length - 1];
    const k = 3 * P.N + 3; P.walls[k] = P.makeWall(0); P.walls[k].fire = 5; const h0 = P.walls[k].hp; for (let i = 0; i < 10; i++) P.update(.05); return { fireRaid1: q, t: f.t, r: f.r || .9, burn: +(h0 - (P.walls[k] ? P.walls[k].hp : 0)).toFixed(1) } });
  assert.ok(out.firestorm.fireRaid1 >= 1 && out.firestormOff.fireRaid1 === 0, 'firebrands from raid 1');
  assert.ok(out.firestorm.t > out.firestormOff.t && out.firestorm.r > out.firestormOff.r && out.firestorm.burn > out.firestormOff.burn * 1.3);
  // 5. Adrenaline: 20% faster (movement is worked out on each player's own phone)
  const walk = async mods => { await game(mods); return P.evaluate(() => new Promise(res => { const P = __pal, p = P.player; [p.x, p.y] = [2.5, 2.5];
    for (let k = 0; k < P.N * P.N; k++) if (P.walls[k]) P.walls[k] = null; window.dispatchEvent(new KeyboardEvent('keydown', { key: 'd' }));
    // speed per second of game time: a slow first frame (caches warming up) can't shorten the walk
    const x0 = p.x, y0 = p.y, t0 = P.game.time; setTimeout(() => { window.dispatchEvent(new KeyboardEvent('keyup', { key: 'd' })); res(Math.hypot(p.x - x0, p.y - y0) / Math.max(.05, P.game.time - t0)) }, 600) })) };
  out.walkOff = await walk([]); out.walkOn = await walk(['adrenaline']);
  assert.ok(out.walkOn / out.walkOff > 1.12 && out.walkOn / out.walkOff < 1.3, 'adrenaline ~1.2x: ' + out.walkOn / out.walkOff);
  // 6. Last Stand: down in a raid stays down until the raid is broken (a teammate or Dell can still help)
  await game(['laststand']);
  out.laststand = await P.evaluate(() => { const P = __pal, p = P.player; P.startRaid(); P.hurtPlayer(p, 1e4); const rt = p.rt; P.game.queue = []; for (const e of P.enemies) e.dead = true;
    for (let i = 0; i < 4; i++) P.update(.05); return { rt, backUp: p.alive, phase: P.game.phase } });
  assert.ok(out.laststand.rt > 1e5 && out.laststand.backUp && out.laststand.phase === 'build');
  await game([]);
  out.laststandOff = await P.evaluate(() => { const P = __pal, p = P.player; P.startRaid(); P.hurtPlayer(p, 1e4); return p.rt });
  assert.ok(out.laststandOff <= 10);
  // 7. Elite Raid: no riflemen; spotters mark for the grenadiers and firebrands
  await game(['elite']);
  out.elite = await P.evaluate(() => { const P = __pal; P.game.wave = 6; P.startRaid(); const q = P.game.queue; return { rifle: q.filter(x => x === 'rifle').length, n: q.length, kinds: [...new Set(q)].sort() } });
  assert.equal(out.elite.rifle, 0); assert.ok(out.elite.n > 8);
  out.eliteMark = await P.evaluate(() => { const P = __pal; P.game.queue = []; for (const e of P.enemies) e.dead = true; P.update(.05);
    const p = P.player; [p.x, p.y] = [8.5, 8.5]; p.markT = 5; const g = P.spawnEnemyAt('gren', 8.5, 1.2); g.cd = 0; g.scanT = 0; P.updateEnemies(.02); return { foe: g.foe === p, lobs: P.lobs.length } });
  assert.ok(out.eliteMark.foe, 'a marked soldier draws the grenadier from 7.3 tiles');
  // 8. Boss Rush: a boss every other raid; the in-between ones are shard bosses (not cases)
  await game(['bossrush']);
  out.bossrush = await P.evaluate(() => { const P = __pal, r = {}; for (const w of [2, 4, 5, 6, 10]) { P.game.wave = w - 1; P.game.phase = 'build'; P.startRaid(); r[w] = P.game.queue.filter(x => x.startsWith('boss:')); P.game.queue = []; for (const e of P.enemies) e.dead = true; P.update(.05) } return r });
  assert.ok(/:sb$/.test(out.bossrush[2][0]) && /:sb$/.test(out.bossrush[4][0]) && !/:sb/.test(out.bossrush[5][0]) && /:sb$/.test(out.bossrush[6][0]) && !/:sb/.test(out.bossrush[10][0]));
  out.shardBoss = await P.evaluate(() => { const P = __pal; P.game.wave = 7; P.game.phase = 'build'; P.startRaid(); const k = P.game.queue.find(x => x.startsWith('boss:')).split(':')[1]; P.game.queue = [];
    P.spawnBoss(k, true); const e = P.enemies.find(e => e.type === 'boss'); P.hurtEnemyHook(e, 1e7, P.player.id); const keys = P.game.bossLog.slice();
    const before = P.locker.shards, R = P.lockerReward(8, false, 3); return { sbN: P.game.sbN, keys, bossShards: R.bossShards, got: P.locker.shards - before } });
  assert.equal(out.shardBoss.sbN, 1); assert.deepEqual(out.shardBoss.keys, []); assert.ok(out.shardBoss.bossShards >= 15 && out.shardBoss.bossShards <= 30);
  // 9. Weather: every other raid, slows everyone, 1 health every 2 s for players only (never below 1)
  await game(['weather']);
  out.weather = await P.evaluate(() => { const P = __pal, p = P.player; P.startRaid(); const r1 = P.game.wx; P.game.queue = []; for (const e of P.enemies) e.dead = true; P.update(.05); P.update(.05);
    P.startRaid(); const r2 = P.game.wx, slow = P.slowAtHook(8.5, 8.5); p.hp = 50; P.qm.hp = 100; for (let i = 0; i < 81; i++) P.stormTick(.05); const hp1 = p.hp; p.hp = 1; for (let i = 0; i < 100; i++) P.stormTick(.05);
    return { r1, r2, slow, lost: 50 - hp1, floor: p.hp, dell: P.qm.hp } });
  assert.deepEqual(out.weather, { r1: 0, r2: 1, slow: .8, lost: 2, floor: 1, dell: 100 });
  // 10. Nightmare: always night; a 1-in-12 surprise boss on raids without one (never on a boss raid)
  await game(['nightmare']);
  out.nightmare = await P.evaluate(() => { const P = __pal; let n = 0; for (let i = 0; i < 2400; i++)if (P.extraBoss(3)) n++; return { night: P.todStage(1), rate: n / 2400, onBossRaid: P.extraBoss(5) } });
  assert.equal(out.nightmare.night, 2); assert.ok(out.nightmare.rate > .05 && out.nightmare.rate < .13); assert.equal(out.nightmare.onBossRaid, '');
  await game([]); out.dayOff = await P.evaluate(() => [__pal.todStage(1), __pal.extraBoss(3)]); assert.deepEqual(out.dayOff, [0, '']);
  // 11. Berserk: a boss's next attack comes about a third sooner; a warning in progress is untouched
  const bz = async mods => { await game(mods); return P.evaluate(() => { const P = __pal; P.startRaid(); P.game.queue = []; for (const e of P.enemies) e.dead = true; P.update(.05);
    P.spawnBoss('demolisher'); const e = P.enemies.find(e => e.type === 'boss'); e.x = P.N - .5; e.y = .5; e.cd = 5; e.foe = null; P.player.x = -50; for (let i = 0; i < 10; i++) P.updateEnemies(.1);
    const cd = e.cd; e.st = 1; e.stT = 1; e.stM = 1; P.updateEnemies(.1); return { cd: +cd.toFixed(2), warn: +e.stT.toFixed(2) } }) };
  out.berserk = await bz(['berserk']); out.berserkOff = await bz([]);
  assert.ok(Math.abs(out.berserk.cd - (5 - 1.33)) < .05 && Math.abs(out.berserkOff.cd - 4) < .05, JSON.stringify([out.berserk, out.berserkOff]));
  assert.equal(out.berserk.warn, out.berserkOff.warn, 'warnings keep their full length');
  // 12. Glass Cannon (PvP): 30% less health, 50% more damage
  await game(['glass'], 'ffa');
  out.glass = await P.evaluate(() => { const P = __pal, a = P.players.get('solo'), b = P.players.get('b'); a.prot = b.prot = 0; const hp0 = b.hp; P.hurtPlayer(b, 10, 'solo'); return { max: a.max, took: +(hp0 - b.hp).toFixed(1) } });
  await game([], 'ffa');
  out.glassOff = await P.evaluate(() => { const P = __pal, a = P.players.get('solo'), b = P.players.get('b'); a.prot = b.prot = 0; const hp0 = b.hp; P.hurtPlayer(b, 10, 'solo'); return { max: a.max, took: +(hp0 - b.hp).toFixed(1) } });
  assert.equal(out.glass.max, Math.round(out.glassOff.max * .7)); assert.equal(out.glass.took, 15); assert.equal(out.glassOff.took, 10);
  // 13. One Job: everyone plays the host's pick, and job changes are off
  await game(['onejob'], 'ffa', 'grenadier');
  out.onejob = await P.evaluate(() => { const P = __pal; P.player.alive = false; P.player.downed = true; P.hud(0); return { cls: [...P.players.values()].map(p => p.cls), pick: document.getElementById('respawnJobs').hidden } });
  assert.deepEqual(out.onejob, { cls: ['grenadier', 'grenadier'], pick: true });
  // 14. Scrap Shortage (Base Battle): half salvage for a kill
  const scrap = async mods => { await game(mods, 'base'); return P.evaluate(() => { const P = __pal, a = P.players.get('solo'), b = P.players.get('b'); a.team = 'a'; b.team = 'b'; b.prot = 0; const s0 = a.sal; P.hurtPlayer(b, 1e4, 'solo'); return a.sal - s0 }) };
  out.scrap = [await scrap(['scrap']), await scrap([])]; assert.deepEqual(out.scrap, [4, 8]);
  // 15. Grenade Frenzy: a grenade back every 6 s, blasts a third bigger
  await game(['frenzy'], 'ffa');
  out.frenzy = await P.evaluate(() => { const P = __pal, p = P.player; p.prot = 0; p.nades = 0; for (let i = 0; i < 130; i++) P.update(.05); const n = p.nades; p.ncd = 0; p.nades = 1; P.throwNade(p, p.x + 3, p.y); return { back: n, R: +P.lobs[P.lobs.length - 1].R.toFixed(2), ncd: +p.ncd.toFixed(2) } });
  await game([], 'ffa');
  out.frenzyOff = await P.evaluate(() => { const P = __pal, p = P.player; p.nades = 0; for (let i = 0; i < 130; i++) P.update(.05); const n = p.nades; p.ncd = 0; p.nades = 1; P.throwNade(p, p.x + 3, p.y); return { back: n, R: +P.lobs[P.lobs.length - 1].R.toFixed(2), ncd: +p.ncd.toFixed(2) } });
  assert.equal(out.frenzy.back, 1); assert.equal(out.frenzyOff.back, 0); assert.ok(out.frenzy.R > out.frenzyOff.R * 1.3 && out.frenzy.ncd < out.frenzyOff.ncd);
  // 16. Sudden Death (FFA): the last minute, drops count double and no spawn protection
  await game(['sudden'], 'ffa');
  out.sudden = await P.evaluate(() => { const P = __pal, a = P.players.get('solo'), b = P.players.get('b'); P.game.timer = 61; P.update(.05); const before = P.game.sd; P.game.timer = 59.5; P.update(.05);
    b.prot = 0; P.hurtPlayer(b, 1e4, 'solo'); b.rt = 0; P.update(.05); return { before, sd: P.game.sd, kills: a.kills, prot: b.prot } });
  assert.deepEqual(out.sudden, { before: false, sd: true, kills: 2, prot: 0 });
  // 17. rewards: harder modifiers move more raids toward a Supply Case (this browser's locker; the server does the same)
  out.reward = await P.evaluate(() => { const P = __pal, L = P.locker; const run = mods => { P.newGame(null, '', { mods }); P.player.sal = 0; L.prog = 0; const c0 = L.cases; P.lockerReward(5, false, 0); return L.cases - c0 + L.prog / 3 };
    return { none: run([]), hard: run(['alone', 'nightmare', 'weather']), easy: run(['adrenaline']) } });
  assert.ok(out.reward.hard > out.reward.none && out.reward.easy < out.reward.none, JSON.stringify(out.reward));
  // 18. best scores are kept per modifier set
  out.best = await P.evaluate(() => { const P = __pal; localStorage.removeItem('palisade.best.v3'); P.newGame(null, '', { mods: ['weather', 'alone'] }); P.showOver(); const k = Object.keys(JSON.parse(localStorage.getItem('palisade.best.v3') || '{}')); return k });
  assert.deepEqual(out.best, ['10:normal|alone+weather']);
  await P.close();
  // 19. online: the host's picks reach the guest's room and game (storm and One Job too)
  const H = await open(), G = await open({ width: 390, height: 844 });
  await H.click('[data-nav=multi]'); await H.click('[data-pv=ffa]'); await H.click('#hostBtn');
  await H.waitForFunction(() => /^[A-Z0-9]{4}$/.test(document.getElementById('lCode').textContent), null, { timeout: 15000 });
  const code = await H.textContent('#lCode');
  await G.click('[data-nav=multi]'); await G.fill('#mCode', code); await G.click('#joinBtn'); await G.waitForSelector('#pg-lobby:not([hidden])', { timeout: 15000 });
  await H.click('#lMods [data-mod=weather]'); await H.click('#lMods [data-mod=onejob]'); await H.click('[data-oj=sniper]'); await H.waitForTimeout(700);
  out.guestRoom = await G.evaluate(() => ({ chips: [...document.querySelectorAll('#lMods .modChip')].map(b => b.dataset.mod), disabled: [...document.querySelectorAll('#lMods .modChip')].every(b => b.disabled), job: document.querySelector('[data-oj].sel')?.dataset.oj }));
  assert.deepEqual(out.guestRoom, { chips: ['weather', 'onejob'], disabled: true, job: 'sniper' });
  await G.click('#lMods .modChip').catch(() => { });   // a guest can't change them
  await H.click('#lStart'); await G.waitForFunction(() => document.getElementById('menu').hidden, null, { timeout: 8000 }); await H.waitForTimeout(600);
  out.guestGame = await G.evaluate(() => ({ mods: __pal.game.mods, job: __pal.game.job, cls: [...__pal.players.values()].map(p => p.cls), gid: __pal.game.gid }));
  const hostGid = await H.evaluate(() => __pal.game.gid);
  assert.deepEqual(out.guestGame.mods, ['weather', 'onejob']); assert.deepEqual(out.guestGame.cls, ['sniper', 'sniper']); assert.equal(out.guestGame.gid, hostGid, 'one game id for everyone');
  await H.evaluate(() => { __pal.game.wxT = 45 }); await H.waitForTimeout(900);
  out.guestStorm = await G.evaluate(() => ({ wx: __pal.game.wx, slow: __pal.slowAtHook(8.5, 8.5) }));
  assert.deepEqual(out.guestStorm, { wx: 1, slow: .8 });
  await G.screenshot({ path: __dirname + '/out/modifiers_guest_storm.png' });
  console.log(JSON.stringify(out)); console.log('errors:', errors.length ? errors : 'none'); assert.equal(errors.length, 0); await b.close();
})().catch(e => { console.log('Error:', e.message, e.stack.split('\n').find(l => /modifiers.js/.test(l))); process.exit(1) });
