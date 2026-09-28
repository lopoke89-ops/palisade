// v0.9.3 milestones: the boss, map and class counters move from a finished run (this browser's own locker, which
// follows the server's rules), each threshold unlocks its item, a class change mid-run counts for the class you ended
// as, PvP adds nothing to them, and the Locker shows progress bars and the MILESTONES view.
// The server side is the same rules in claim_match_reward (tested in a rolled-back transaction).  node milestones.js
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const PORT = process.env.PORT || 8080;
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined });
  const p = await b.newPage({ viewport: { width: 1280, height: 800 } });
  const errors = [], out = {};
  p.on('pageerror', e => errors.push(e.message));
  await p.goto(`http://localhost:${PORT}/debug.html?debug=1`); await p.waitForTimeout(900);
  await p.click('#startBtn'); await p.waitForTimeout(400);

  // a won 5-raid run on Riverbend as a sniper; the Butcher went down on raid 5 (a second, bogus boss is over the cap)
  out.run1 = await p.evaluate(() => {
    const P = __pal, g = P.game, st = P.locker.st;
    st.boss_butcher = 24; g.waves = 5; g.size = 'std'; g.map = 'river'; g.bossLog = ['butcher', 'storm']; g.joinHeld = 0; g.joinBoss = 0; P.player.cls = 'sniper';
    const R = P.lockerReward(5, true, 12);
    return { butcher: st.boss_butcher, storm: st.boss_storm | 0, river: st.map_river, sniper: st.cls_sniper_raids, unlocked: R.unlocked, owns: P.locker.owned.includes('skin:butcher') };
  });
  assert.equal(out.run1.butcher, 25); assert.equal(out.run1.storm, 0, 'only as many bosses as the raids allow');
  assert.equal(out.run1.river, 5); assert.equal(out.run1.sniper, 5);
  assert.ok(out.run1.unlocked.includes('skin:butcher') && out.run1.owns, 'the 25th Butcher unlocks the Butcher outfit');

  // switched class mid-run: the raids count for the class the player ended as. An XL boss raid counts both bosses,
  // and the October Butcher counts as the Butcher.
  out.run2 = await p.evaluate(() => {
    const P = __pal, g = P.game, st = P.locker.st;
    g.size = 'xl'; g.map = 'quarry'; g.bossLog = ['butcher_oct', 'foreman']; P.player.cls = 'grenadier';
    P.lockerReward(5, false, 3);
    return { gren: st.cls_grenadier_raids, sniper: st.cls_sniper_raids, quarry: st.map_quarry, butcher: st.boss_butcher, foreman: st.boss_foreman };
  });
  assert.deepEqual(out.run2, { gren: 5, sniper: 5, quarry: 5, butcher: 26, foreman: 1 });

  // PvP: no raids, no bosses, no milestone counters
  out.pvp = await p.evaluate(() => {
    const P = __pal, st = P.locker.st, before = JSON.stringify(Object.entries(st).filter(([k]) => /^(boss|map|cls)_/.test(k)));
    P.game.pvp = 'base'; P.pvpReward(true, 4); P.game.pvp = '';
    return before === JSON.stringify(Object.entries(st).filter(([k]) => /^(boss|map|cls)_/.test(k)));
  });
  assert.ok(out.pvp, 'PvP left the milestone counters alone');

  // every ladder item: rarity steps r, e, l, g; the need matches its ladder's steps
  out.ladders = await p.evaluate(() => __pal.LADDERS.map(L => L.items.map(([c, k], i) => { const it = __pal.COS.find(x => x.id === c + ':' + k); return it && it.r === 'relg'[i] && it.need[L.st] === L.steps[i] && it.src === 'unlock' }).every(Boolean)));
  assert.ok(out.ladders.every(Boolean), 'every ladder is rare, epic, legendary, gold with its own goals');
  assert.equal(out.ladders.length, 12);

  // the after-action card for the closest milestone
  out.card = await p.evaluate(() => { __pal.showRewards({ kind: 'run', cases: {}, shards: 0, unlocked: [], toNext: 2, prog: 1 }); const c = document.querySelector('.rwMile'); return c ? c.textContent : '' });
  assert.match(out.card, /THE BUTCHER.*26 \/ 50 Butchers beaten.*Pale Butcher/);

  // the Locker: MILESTONES lists all 12 ladders; a locked item shows its progress, an owned one doesn't
  await p.evaluate(() => { __pal.endRun ? __pal.endRun() : 0 });
  await p.goto(`http://localhost:${PORT}/debug.html?debug=1`); await p.waitForTimeout(900);
  await p.evaluate(() => { const L = __pal.locker; L.st.boss_butcher = 26; L.owned.push('skin:butcher'); document.querySelector('[data-nav=locker]').click() });
  await p.waitForTimeout(500); await p.click('#lockTabs [data-cat=ms]'); await p.waitForTimeout(1500);
  out.ui = await p.evaluate(() => {
    const heads = [...document.querySelectorAll('#lockGrid .gsec')].map(h => h.firstChild.textContent);
    const tile = name => [...document.querySelectorAll('#lockGrid .item')].find(t => t.querySelector('b').textContent === name);
    const pale = tile('Pale Butcher'), base = tile('Butcher');
    return { heads, pale: pale && pale.querySelector('.iprog') ? pale.querySelector('.iprog').textContent : '', baseBar: !!(base && base.querySelector('.iprog')), sub: document.querySelector('#lockGrid .gsec small').textContent };
  });
  assert.equal(out.ui.heads.length, 12); assert.equal(out.ui.pale, '26 / 50'); assert.equal(out.ui.baseBar, false); assert.match(out.ui.sub, /26 Butchers beaten/);
  await p.screenshot({ path: __dirname + '/out/milestones.png' });
  // the normal SKINS tab has its own MILESTONES section, between the plain unlocks and the cases
  await p.click('#lockTabs [data-cat=skin]'); await p.waitForTimeout(300);
  out.skinSections = await p.evaluate(() => [...document.querySelectorAll('#lockGrid .gsec')].map(h => h.textContent));
  assert.equal(out.skinSections[0], 'MILESTONES');
  console.log(JSON.stringify(out, null, 1));
  console.log('errors:', errors.length ? errors : 'none');
  assert.equal(errors.length, 0);
  await b.close();
})();
