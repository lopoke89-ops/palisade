// v0.12 THE UNDERSTRIP CASE on the client: the case (weights, 15 shards), its 30 items in their tiers as
// dev/plans/understrip/tables/case_items.csv has them, every weighted tier stocked, local openings landing on its items;
// the ten skins on their own models (each draws differently from the standard soldier at all four angles), which hats
// each one wears, the tracers, kill effects and backgrounds drawing; and a run's pay without an account (the server's
// rule: a case, 2 shards and a skill point a region cleared, a case for the finish).
const { chromium } = require('playwright'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const csv = fs.readFileSync(path.join(__dirname, '../plans/understrip/tables/case_items.csv'), 'utf8').trim().split('\n').slice(1).map(l => l.split(','));
(async () => {
 const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), errors = [];
 const p = await b.newPage({ viewport: { width: 1000, height: 800 } }); p.on('pageerror', e => errors.push(e.message));
 await p.goto(`http://localhost:${process.env.PORT || 8080}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal && __pal.ready);
 const r = await p.evaluate(() => {
  let s = 5; Math.random = () => (s = (s * 16807) % 2147483647) / 2147483647; const P = __pal, r = {};
  const C = P.CASES.understrip; r.case = C && [C.name, C.cost, ['c', 'r', 'e', 'l', 'g'].map(k => C.weights[k]).join()];
  r.items = P.COS.filter(c => c.box === 'understrip').map(c => [c.id, c.cat, c.name, c.r, c.src]);
  r.rolls = {}; for (let n = 0; n < 2000; n++) { const it = P.rollCase('understrip'); r.rolls[it ? it.box + ':' + it.r : 'none'] = (r.rolls[it ? it.box + ':' + it.r : 'none'] | 0) + 1 }
  // the models: four angles each, against the standard soldier's
  const sig = (skin, hat, a) => { const c = document.createElement('canvas'); c.width = 120; c.height = 150; const x = c.getContext('2d'); P.paintWardrobeCharacter(x, P.lookOf({ skin, hat }, 'soldier'), a * Math.PI / 2, 2, 2.4, 60, 140, false); const d = x.getImageData(0, 0, 120, 150).data; let h = 0, ink = 0; for (let k = 0; k < d.length; k += 4) { if (d[k + 3] > 16) ink++; h = (h * 31 + d[k] + d[k + 1] * 3 + d[k + 2] * 7) % 1000000007 } return [h, ink] };
  r.models = {}; for (const k of P.COS.filter(c => c.box === 'understrip' && c.cat === 'skin').map(c => c.key)) r.models[k] = [0, 1, 2, 3].map(a => { const m = sig(k, 'class', a), std = sig('std', 'class', a); return m[1] > 400 && m[0] !== std[0] });
  r.hats = {}; for (const k of P.COS.filter(c => c.box === 'understrip' && c.cat === 'hat').map(c => c.key)) r.hats[k] = [0, 2].map(a => sig('std', k, a)[0] !== sig('std', 'class', a)[0]);
  r.wear = { open: ['pitboss', 'highroller', 'shelterdweller', 'cardsharp'].map(k => P.headwearAllowed(k, 'tinfoil') && P.headwearAllowed(k, 'halo')), closed: ['visitor', 'custodian', 'stripking', 'generalissimo', 'gunslinger', 'sheriff'].map(k => P.headwearAllowed(k, 'tinfoil') || P.headwearAllowed(k, 'halo')), aura: P.lookOf({ skin: 'visitor', hat: 'class' }, 'soldier').aura };
  // tracers, kill effects, backgrounds draw something
  const inked = draw => { const c = document.createElement('canvas'); c.width = 200; c.height = 150; const x = c.getContext('2d'); draw(x); const d = x.getImageData(0, 0, 200, 150).data; let n = 0; for (let k = 3; k < d.length; k += 4)if (d[k] > 16) n++; return n };
  r.trails = ['chips', 'neontube', 'jackpotcoins', 'tractorbeam', 'saucerbolt'].map(k => !!P.TRAILS[k] && inked(x => P.traceSeg(x, 160, 75, 40, 75, P.TRAILS[k], 4, 1, false, 0)) > 100);
  r.fx = ['bust', 'plumes', 'jackpot', 'dissolved', 'abducted'].map(k => [.12, .5, .85].every(t => inked(x => P.paintFinish(x, k, t, 2, 100, 110)) > 50));
  r.bgs = ['floodtunnels', 'vaultdoor', 'area67', 'stripnight', 'specimenhall'].map(k => !!P.BGS[k] && P.BGS[k].animated && inked(x => P.drawBg(k, x, 200, 150, 2)) > 25000);
  // a run's pay, no account
  const pay = c => { const b0 = P.caseCount('understrip'), s0 = P.locker.shards | 0, sp0 = P.locker.sp | 0; const R = P.localRun({ kind: 'run', mode: 'understrip', cv: 6, diff: 'normal', win: false, held: 0, raid_from: 0, raid_to: 0, kills: 40, boss_keys: [], salvage: 0, duration_s: 2400, mods: [], map: 'understrip', cls: 'soldier', size: 'std', ...c }, 0); return [P.caseCount('understrip') - b0, (P.locker.shards | 0) - s0, (P.locker.sp | 0) - sp0, R.text] };
  r.payWin = pay({ win: true, held: 10, raid_to: 10 }); r.payDeep = pay({ held: 7, raid_to: 7 }); r.payShallow = pay({ held: 2, raid_to: 2 }); r.paySplit = pay({ held: 6, raid_from: 4, raid_to: 10, win: true }); r.payFast = pay({ win: true, held: 10, raid_to: 10, duration_s: 600 });
  return r });
 console.log(JSON.stringify(r, null, 1));
 assert.deepEqual(r.case, ['UNDERSTRIP CASE', 15, '40,32,18,8,2']);
 assert.equal(r.items.length, 30);
 for (const [id, cat, name, rar] of csv) { const it = r.items.find(i => i[0] === id); assert.ok(it, id); assert.deepEqual(it.slice(1), [cat, name.replace(/''/g, "'"), rar, 'case'], id) }
 for (const k of ['c', 'r', 'e', 'l', 'g']) assert.ok(r.rolls['understrip:' + k] > 0, 'tier ' + k + ' lands');
 assert.ok(!Object.keys(r.rolls).some(k => !k.startsWith('understrip:')), 'every opening lands on the case\'s own items');
 assert.ok(Math.abs(r.rolls['understrip:c'] / 2000 - .4) < .05 && Math.abs(r.rolls['understrip:g'] / 2000 - .02) < .015, 'the weights');
 for (const [k, v] of Object.entries(r.models)) assert.deepEqual(v, [true, true, true, true], k + ': its own model at all four angles');
 for (const [k, v] of Object.entries(r.hats)) assert.deepEqual(v, [true, true], k + ' draws, front and back');
 assert.ok(r.wear.open.every(Boolean), 'open heads wear any hat'); assert.ok(!r.wear.closed.some(Boolean), 'models with their own hat or head wear only it'); assert.equal(r.wear.aura, 'gvisitor');
 assert.ok(r.trails.every(Boolean) && r.fx.every(Boolean) && r.bgs.every(Boolean), 'tracers, kill effects and backgrounds draw');
 assert.deepEqual(r.payWin.slice(0, 3), [4, 6, 3 + 2], 'a won run: 4 cases, 6 shards, 3 skill points (+2 for 10 levels)');
 assert.deepEqual(r.payDeep.slice(0, 2), [2, 4], 'level 7: two regions'); assert.deepEqual(r.payShallow.slice(0, 2), [0, 0]);
 assert.deepEqual(r.paySplit.slice(0, 2), [3, 4], 'rejoined at 4: regions 2 and 3, and the finish'); assert.deepEqual(r.payFast.slice(0, 2), [3, 6], 'a win under 15 minutes isn\'t a win');
 assert.match(r.payWin[3], /understrip case/i);
 console.log('errors:', errors.length ? errors : 'none'); await b.close(); if (errors.length) process.exit(1);
})();
