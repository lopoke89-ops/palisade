// v0.9.1 after-action reward cards: cases with counts, a shard counter, UNLOCKED cards with the locker
// thumbnails, and the progress bar to the next Supply Case. A tap shows them all at once. node rewards_screen.js
const { chromium } = require('playwright'), { ready, frames } = require('./lib');
const assert = require('assert');
const PORT = process.env.PORT || 8080;
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), errors = [], out = {};
  const p = await b.newPage({ viewport: { width: 1280, height: 860 } }); p.on('pageerror', e => errors.push(e.message));
  await p.goto(`http://localhost:${PORT}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal);
  // a fresh local locker, 2 raids toward the next case; a 5-raid win with a boss down and salvage left
  await p.evaluate(() => { const P = __pal, L = P.locker; L.cases = 0; L.bag = {}; L.prog = 2; L.shards = 0; L.st.wins = 0; L.owned = L.owned.filter(id => id !== 'bg:dawn' && id !== 'skin:desert'); L.st.raids = 0 });
  await p.click('#startBtn'); await frames(p, 3);
  const R = await p.evaluate(() => { const P = __pal; P.game.time = 600; P.game.wave = 5; P.game.waves = 5; P.game.won = true; P.game.bossLog = ['demolisher']; P.game.bosses = 1; P.player.sal = 90; P.player.kills = 20;
    P.game.phase = 'over'; P.showOver(); return null });
  await p.waitForSelector('#over:not([hidden])', { timeout: 3000 });
  // cards come in one after another: early on not all are visible yet
  out.early = await p.evaluate(() => [...document.querySelectorAll('#overRewards .rwCard')].map(d => +getComputedStyle(d).opacity));
  await p.waitForTimeout(2200);
  out.cards = await p.evaluate(() => [...document.querySelectorAll('#overRewards .rwCard')].map(d => ({ cls: d.className.replace('rwCard ', ''), text: d.textContent, op: +getComputedStyle(d).opacity })));
  out.loot = await p.textContent('#overLoot');
  out.bar = await p.evaluate(() => { const i = document.querySelector('.rwBar i'), bar = document.querySelector('.rwBar'); return Math.round(i.getBoundingClientRect().width / bar.clientWidth * 100) });
  await p.screenshot({ path: __dirname + '/out/rewards_screen.png' });
  const kinds = out.cards.map(c => c.cls);
  assert.ok(kinds.includes('rwCase'), 'a case card'); assert.ok(kinds.includes('rwShard'), 'a shard card'); assert.ok(kinds.includes('rwNew'), 'an UNLOCKED card'); assert.ok(kinds.includes('rwProg'), 'the progress bar');
  assert.ok(out.cards.every(c => c.op > .99), 'all shown after 1.5 s');
  assert.ok(out.early.some(o => o < .5), 'staggered, not all at once');
  const sup = out.cards.find(c => c.cls === 'rwCase' && /SUPPLY/.test(c.text)); assert.ok(sup && /×\d/.test(sup.text), 'supply count');
  assert.ok(out.cards.find(c => c.cls === 'rwShard').text.includes('+4'), 'shard counter reaches the total');
  assert.ok(out.cards.some(c => c.cls === 'rwNew' && /UNLOCKED/.test(c.text)), 'unlock card');
  assert.match(out.loot, /supply case/, 'the sentence is still there for screen readers and toasts');
  // structured: the reward data itself
  out.data = await p.evaluate(() => { const P = __pal; P.toMenu(); P.locker.prog = 0; document.getElementById('startBtn').click(); P.game.time = 200; P.game.wave = 2; P.game.won = false; P.player.sal = 0; const R = P.lockerReward(1, false, 3); return { cases: R.cases, shards: R.shards, unlocked: R.unlocked, toNext: R.toNext, prog: R.prog, text: R.text } });
  assert.deepEqual([out.data.toNext, out.data.prog, out.data.shards], [2, 1, 0]); assert.equal(typeof out.data.text, 'string');
  // a tap skips straight to the end
  out.skip = await p.evaluate(async () => { const P = __pal; P.game.phase = 'over'; P.game.won = true; P.game.wave = 5; P.game.rewarded = false; P.showOver(); await new Promise(r => setTimeout(r, 1000)); document.getElementById('overRewards').click(); await new Promise(r => setTimeout(r, 60));
    return [...document.querySelectorAll('#overRewards .rwCard')].every(d => +getComputedStyle(d).opacity > .99) });
  assert.ok(out.skip, 'tap shows everything');
  // cloud results arrive as the same data (claimReward), with item ids
  out.claim = await p.evaluate(() => { const P = __pal; const R = P.claimReward({ kind: 'run' }, { cases: { supply: 2, afterglow: 1, halloween: 0 }, shards: 3, unlocked_ids: ['bg:dawn'], to_next: 1, locker: { prog: 2 } }); return { cases: R.cases, unlocked: R.unlocked, toNext: R.toNext, text: R.text } });
  assert.deepEqual(out.claim.unlocked, ['bg:dawn']); assert.equal(out.claim.toNext, 1); assert.match(out.claim.text, /First Light/);
  out.oldServer = await p.evaluate(() => __pal.claimReward({ kind: 'run' }, { cases_granted: 1, bonuses: [{ case: 'afterglow', n: 1 }], unlocked: ['First Light'], locker: { prog: 1 } }));
  assert.deepEqual(out.oldServer.cases, { supply: 1, afterglow: 1 }); assert.deepEqual(out.oldServer.unlocked, ['bg:dawn']);
  console.log(JSON.stringify(out, null, 1)); console.log('errors:', errors.length ? errors : 'none'); assert.equal(errors.length, 0);
  await b.close();
})().catch(e => { console.log('Error:', e.message); process.exit(1) });
