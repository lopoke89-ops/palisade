// v0.9.4.0: the BLITZKRIEG RUSH ladder (10/25/50/75/100 Blitzkrieg bosses: Devil Horns, Blue Arc, Blue Butcher, Hell Portal,
// Demon), counted for everyone in the match, never halved; the Blitzkrieg modifier list (Boss Rush out, five new ones in);
// no-account half rewards (odd counts round up); Devil Horns can't go on the Demon. node blitz_milestones.js
const { chromium } = require('playwright'), assert = require('node:assert/strict'), fs = require('node:fs');
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), errors = [], out = {};
  const p = await b.newPage({ viewport: { width: 1100, height: 760 } }); p.on('pageerror', e => errors.push(e.message));
  await p.goto(`http://localhost:${process.env.PORT || 8080}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal);
  // the ladder as the Locker shows it
  out.ladder = await p.evaluate(() => { const P = __pal, L = P.LADDERS.find(x => x.id === 'blitz');
    return { title: L.title, steps: L.steps, items: L.items.map(([c, k]) => { const it = P.COSBY[c + ':' + k]; return [it.id, it.r, it.need.mode_blitz_bosses] }) } });
  assert.equal(out.ladder.title, 'BLITZKRIEG RUSH'); assert.deepEqual(out.ladder.steps, [10, 25, 50, 75, 100]);
  assert.deepEqual(out.ladder.items, [['hat:devilhorns', 'r', 10], ['trail:bluearc', 'e', 25], ['skin:bluebutcher', 'e', 50], ['fx:hellportal', 'l', 75], ['skin:demon', 'g', 100]]);
  // no-account claims: a player who made it out, and one left behind with the same run
  const claim = (evac, fb, keys = ['bluebutcher', 'arsonist']) => p.evaluate(([evac, fb, keys]) => { const P = __pal, L = P.locker;
    L.cases = 0; L.bag = {}; L.shards = 0; L.prog = 0; L.st = { raids: 0, wins: 0, drops: 0, endless: 0, hardWins: 0 }; L.owned = L.owned.filter(id => !/devilhorns|bluearc|bluebutcher|hellportal|demon/.test(id)); L.sp = 0; L.spProg = 0;
    const c = { kind: 'run', mode: 'blitz', diff: 'normal', win: evac === 'evac', held: 15, raid_from: 0, raid_to: 15, kills: 30, boss_keys: keys, shard_bosses: 0, sb_keys: [], salvage: 0, size: 'std', mods: [], map: 'yard', cls: 'soldier', fb_keys: fb, evac };
    const R = P.localRun(c, 0); return { cases: R.cases, shards: R.shards, sp: R.sp, left: !!R.left, st: { raids: L.st.raids, wins: L.st.wins, mode: L.st.mode_blitz_bosses, butcher: L.st.boss_butcher | 0, storm: L.st.boss_storm | 0 }, owned: L.owned.filter(id => /devilhorns|bluearc/.test(id)), text: R.text } }, [evac, fb, keys]);
  const V = ['bluebutcher', 'arsonist', 'tempest', 'harbinger', 'bulldozer'], fb10 = [...V, ...V];
  out.evac = await claim('evac', fb10);
  assert.equal(out.evac.cases.blitz, 2 * 12 + 1); assert.equal(out.evac.cases.supply, 7); assert.equal(out.evac.sp, 15);
  assert.ok(out.evac.shards >= 150 + 25 && out.evac.shards <= 300 + 25, out.evac.shards);
  assert.deepEqual(out.evac.st, { raids: 15, wins: 1, mode: 12, butcher: 3, storm: 2 }); assert.deepEqual(out.evac.owned, ['hat:devilhorns']);
  out.left = await claim('left', fb10);
  assert.equal(out.left.cases.blitz, 12, 'half of 24'); assert.equal(out.left.cases.supply, 3, '5 -> 3: odd rounds up'); assert.equal(out.left.sp, 15, 'skill points never halved');
  assert.ok(out.left.shards >= 75 && out.left.shards <= 150, out.left.shards); assert.ok(out.left.left); assert.match(out.left.text, /Left behind/);
  assert.deepEqual(out.left.st, { raids: 15, wins: 0, mode: 12, butcher: 3, storm: 2 }, 'raids and bosses in full, no win');
  out.cap = await claim('evac', [...fb10, ...V], []); assert.equal(out.cap.st.mode, 10, 'at most 10 Final Blitz bosses');
  // everyone in the match is credited: a guest who never landed a hit still has the host's kill list
  out.shared = await p.evaluate(() => { const P = __pal; P.demo = false; P.pick.mode = 'blitz'; P.newGame(null, '', {}); const g = P.game; g.fbLog = ['tempest', 'bulldozer']; g.joinFB = 0; g.fb = { t: 30, evac: { x: 1, y: 1, r: 1.5 }, done: false };
    P.player.out = true; const { claim } = P.runClaim(14, false, 0); return { fb: claim.fb_keys, evac: claim.evac, win: claim.win, held: claim.raid_to } });
  assert.deepEqual(out.shared, { fb: ['tempest', 'bulldozer'], evac: 'evac', win: true, held: 15 });
  // modifiers: Blitzkrieg list
  out.mods = await p.evaluate(() => { const P = __pal, ids = k => P.MODS.filter(m => m.modes.includes(k)).map(m => m.id);
    return { blitz: ids('blitz'), clean: P.cleanMods(['bossrush', 'hotlz', 'nightmare', 'glass'], 'blitz'), coop: P.cleanMods(['bossrush', 'hotlz'], ''), pct: P.modBonus(['hotlz', 'blitzclock', 'barrage', 'lockdown', 'scorched'], 'blitz') } });
  assert.deepEqual(out.mods.blitz, ['nopatch', 'alone', 'firestorm', 'adrenaline', 'laststand', 'elite', 'weather', 'nightmare', 'berserk', 'hotlz', 'blitzclock', 'barrage', 'lockdown', 'scorched']);
  assert.deepEqual(out.mods.clean, ['hotlz', 'nightmare'].sort((a, b) => ['nightmare', 'hotlz'].indexOf(a) - ['nightmare', 'hotlz'].indexOf(b)));
  assert.deepEqual(out.mods.coop, ['bossrush']); assert.equal(out.mods.pct, 60);
  // Lockdown: the armory is shut for the build before raid 15; Nightmare has no surprise boss in Blitzkrieg Rush
  out.lock = await p.evaluate(() => { const P = __pal; P.pick.mode = 'blitz'; P.newGame(null, '', { mods: ['lockdown', 'nightmare'] }); const g = P.game; g.phase = 'build'; g.wave = 13; const a = P.shopOpen(P.player); g.wave = 14; const b = P.shopOpen(P.player);
    let sb = 0; for (let i = 0; i < 2000; i++) if (P.extraBoss(7)) sb++; return { at13: a, at14: b, surprise: sb } });
  assert.deepEqual(out.lock, { at13: true, at14: false, surprise: 0 });
  // Devil Horns on the Demon: blocked (the Demon has its own horns)
  out.horns = await p.evaluate(() => { const P = __pal; return { demon: P.headwearAllowed('demon', 'devilhorns'), std: P.headwearAllowed('std', 'devilhorns'), demonLook: !!P.lookOf({ skin: 'demon', hat: 'devilhorns' }, 'soldier').demonHorns } });
  assert.deepEqual(out.horns, { demon: false, std: true, demonLook: true });
  fs.writeFileSync(__dirname + '/out/blitz_milestones.json', JSON.stringify({ out, errors }, null, 2)); assert.deepEqual(errors, []);
  console.log(JSON.stringify(out)); console.log('errors: none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
