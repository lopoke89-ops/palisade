// v0.9.3 the Flag Case: its odds, its 64 items (32 backgrounds, 32 tracers), the win drop, opening and buying it,
// duplicates turning into shards, every flag background drawing, and older tracers keeping their numbers.  node flagcase.js
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const PORT = process.env.PORT || 8080;
// the tracer list as of v0.9.2.1: a shot sends its tracer as its place in this list, so these must never move
const OLD_TRAILS = ['std', 'green', 'red', 'blue', 'pink', 'gold', 'plasma', 'rainbow', 'sunset', 'lagoon', 'heat', 'aurora', 'starlight', 'comet', 'neonpulse',
  'nebula', 'asteroid', 'solar', 'glitch', 'galaxy', 'blackhole', 'grainbow', 'candycorn', 'ghostfire'];
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined });
  const p = await b.newPage({ viewport: { width: 1280, height: 800 } });
  const errors = [], out = {};
  p.on('pageerror', e => errors.push(e.message));
  await p.goto(`http://localhost:${PORT}/debug.html?debug=1`); await p.waitForTimeout(900);

  out.basics = await p.evaluate(OLD => {
    const P = __pal, C = P.CASES.flags, items = P.COS.filter(c => c.box === 'flags');
    return { name: C.name, cost: C.cost, weights: C.weights, win: C.drop.win, winCase: P.winCase(), items: items.length, bgs: items.filter(c => c.cat === 'bg').length,
      trails: items.filter(c => c.cat === 'trail').length, oldOrder: OLD.every((k, i) => P.TRAIL_IDS[i] === k),
      byRarity: items.reduce((a, c) => (a[c.r] = (a[c.r] | 0) + 1, a), {}),
      commons: items.filter(c => c.r === 'c' && c.cat === 'bg').map(c => c.key).sort().join(','), golds: items.filter(c => c.r === 'g' && c.cat === 'bg').map(c => c.key).sort().join(',') };
  }, OLD_TRAILS);
  assert.equal(out.basics.name, 'FLAG CASE'); assert.equal(out.basics.cost, 10); assert.equal(out.basics.win, .25); assert.equal(out.basics.winCase, 'flags');
  assert.equal(out.basics.items, 64); assert.equal(out.basics.bgs, 32); assert.equal(out.basics.trails, 32);
  assert.ok(out.basics.oldOrder, 'the older tracers keep their places');
  assert.deepEqual(out.basics.byRarity, { g: 4, l: 22, e: 12, r: 18, c: 8 });
  assert.equal(out.basics.commons, 'f_india,f_israel,f_nkorea,f_russia'); assert.equal(out.basics.golds, 'f_pride,f_progress');

  // 30,000 rolls: each rarity comes up at its weight (within 1.5 points) and every one of the 64 items turns up
  out.odds = await p.evaluate(() => {
    const P = __pal, n = 30000, by = {}, seen = new Set();
    for (let i = 0; i < n; i++) { const it = P.rollCase('flags'); if (it.box !== 'flags') return { wrong: it.id }; by[it.r] = (by[it.r] | 0) + 1; seen.add(it.id) }
    const W = P.CASES.flags.weights, tot = Object.values(W).reduce((a, v) => a + v, 0);
    return { share: Object.fromEntries(Object.keys(W).map(k => [k, +(by[k] / n * 100).toFixed(2)])), expected: Object.fromEntries(Object.keys(W).map(k => [k, +(W[k] / tot * 100).toFixed(2)])), seen: seen.size };
  });
  assert.ok(!out.odds.wrong, 'a roll left the case: ' + out.odds.wrong);
  for (const k in out.odds.expected) assert.ok(Math.abs(out.odds.share[k] - out.odds.expected[k]) < 1.5, `rarity ${k}: ${out.odds.share[k]}% vs ${out.odds.expected[k]}%`);
  assert.equal(out.odds.seen, 64);

  // the win drop: about one win in four
  out.drop = await p.evaluate(() => { const P = __pal, before = P.caseCount('flags'); let n = 0; for (let i = 0; i < 4000; i++)if (P.winDrop().flags) n++; return { rate: n / 4000, added: P.caseCount('flags') - before } });
  assert.ok(Math.abs(out.drop.rate - .25) < .03, 'win drop rate ' + out.drop.rate); assert.equal(out.drop.added, Math.round(out.drop.rate * 4000));

  // opening: a new item goes into the locker; with everything owned, the same roll pays its rarity's shards instead
  out.open = await p.evaluate(() => {
    const P = __pal, L = P.locker; L.bag.flags = 2; const a = P.openCaseOf('flags'), gotNew = !a.dup && L.owned.includes(a.it.id) && a.it.box === 'flags';
    for (const c of P.COS.filter(c => c.box === 'flags')) if (!L.owned.includes(c.id)) L.owned.push(c.id);
    const s0 = L.shards, d = P.openCaseOf('flags');
    return { gotNew, dup: d.dup, shards: L.shards - s0, want: { c: 1, r: 3, e: 8, l: 20, g: 40 }[d.it.r], left: P.caseCount('flags') };
  });
  assert.ok(out.open.gotNew); assert.ok(out.open.dup); assert.equal(out.open.shards, out.open.want);

  // Every full-screen flag draws a nonempty, opaque design; presentation.js covers responsive edges and emblems.
  out.bgs = await p.evaluate(() => {
    const P = __pal, bad = [], still = [], moving = [];
    for (const [id, , r] of P.FLAGS) {
      const B = P.BGS['f_' + id], cv = document.createElement('canvas'); cv.width = 480; cv.height = 270; const x = cv.getContext('2d');
      try { P.drawBg('f_' + id, x, 480, 270, 1) } catch (e) { bad.push(id + ': ' + e.message); continue }
      const colours=new Set();for(let yy=15;yy<270;yy+=30)for(let xx=15;xx<480;xx+=30){const d=x.getImageData(xx,yy,1,1).data;if(d[3]!==255)bad.push(id+': transparent field');colours.add([d[0]>>4,d[1]>>4,d[2]>>4].join(','))}
      if(colours.size<2)bad.push(id+': empty design');
      (B.still === undefined ? moving : still).push(r);
    }
    return { bad, stillOk: still.every(r => 'cre'.includes(r)), movingOk: moving.every(r => 'lg'.includes(r)), moving: moving.length };
  });
  assert.deepEqual(out.bgs.bad, []); assert.ok(out.bgs.stillOk && out.bgs.movingOk); assert.equal(out.bgs.moving, 13);

  // the Locker: the Flag Case has its box with OPEN and BUY; buying spends 10 shards; a flag background and a flag
  // tracer can be worn
  await p.evaluate(() => { const L = __pal.locker; L.shards = 10; L.bag.flags = 0; document.querySelector('[data-nav=locker]').click() }); await p.waitForTimeout(500);
  out.box = await p.evaluate(() => { const box = [...document.querySelectorAll('#caseBoxes .cbox')].find(d => d.querySelector('span').textContent === 'FLAG CASE'); return box ? { buy: !!box.querySelector('[data-buy=flags]'), open: !!box.querySelector('[data-open=flags]') } : null });
  assert.deepEqual(out.box, { buy: true, open: true });
  await p.click('#caseBoxes [data-buy=flags]'); await p.waitForTimeout(200);
  out.bought = await p.evaluate(() => ({ shards: __pal.locker.shards, bag: __pal.caseCount('flags') }));
  assert.deepEqual(out.bought, { shards: 0, bag: 1 });
  await p.click('#lockTabs [data-cat=bg]'); await p.waitForTimeout(1200);
  await p.click('#collection-bg-flags');
  await p.evaluate(() => [...document.querySelectorAll('#lockGrid .item')].find(t => t.querySelector('b').textContent === 'Rainbow Pride Flag').click()); await p.waitForTimeout(300);
  await p.click('#lockTabs [data-cat=trail]'); await p.waitForTimeout(800);
  await p.click('#collection-trail-flags');
  await p.evaluate(() => [...document.querySelectorAll('#lockGrid .item')].find(t => t.querySelector('b').textContent === 'Progress Pride Flag').click()); await p.waitForTimeout(300);
  out.worn = await p.evaluate(() => ({ bg: __pal.locker.eq.bg, trail: __pal.locker.eq.trail }));
  assert.deepEqual(out.worn, { bg: 'f_pride', trail: 'f_progress' });
  await p.click('#lockTabs [data-cat=bg]'); await p.waitForTimeout(1500); await p.screenshot({ path: __dirname + '/out/flagcase.png' });
  console.log(JSON.stringify(out, null, 1));
  console.log('errors:', errors.length ? errors : 'none');
  assert.equal(errors.length, 0);
  await b.close();
})();
