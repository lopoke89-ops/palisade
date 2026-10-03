// v0.9.6.4 campaign resources: on the Yard brick opens after raid 1 and metal after raid 2 (it used to be due after
// the map had already changed); from chapter 2 on, every kiln and scrap pile starts open, std and XL. node campaign_resources.js
const { chromium } = require('playwright'), assert = require('node:assert/strict');
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), errors = [], out = {};
  for (const size of ['std', 'xl']) {
    const p = await b.newPage({ viewport: { width: 1280, height: 800 } }); p.on('pageerror', e => errors.push(e.message));
    await p.goto(`http://localhost:${process.env.PORT || 8080}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal);
    out[size] = await p.evaluate(async size => { const P = __pal; P.pick.mode = 'campaign'; P.pick.size = size; P.showPage('solo'); document.getElementById('startBtn').click(); await new Promise(r => setTimeout(r, 300));
      const g = P.game, locks = () => P.nodes.filter(n => n.type > 0).map(n => (n.type === 1 ? 'B' : 'M') + (n.locked ? 'x' : 'o')).join(''), rows = [{ at: 'start', ch: g.chapter, map: g.map, n: locks(), label: P.nodes.filter(n => n.locked).map(n => n.unlock) }];
      for (let w = 1; w <= 12; w++) { g.wave = w; g.phase = 'raid'; if (!P.campaignAdvance()) P.startBuild(30); if (g.cev && !g.cev.done) P.finishMapEvac && P.finishMapEvac(); rows.push({ at: 'after ' + w, ch: g.chapter, map: g.map, n: locks() }) }
      return rows }, size);
    await p.close() }
  const at = (s, k) => out[s].find(r => r.at === k);
  for (const s of ['std', 'xl']) {
    assert.ok(/Bx/.test(at(s, 'start').n) && /Mx/.test(at(s, 'start').n), s + ' Yard starts with brick and metal locked');
    assert.ok(at(s, 'start').label.every(u => u <= 3), s + ' every Yard lock opens by raid 3 ' + at(s, 'start').label);
    assert.ok(/Bo/.test(at(s, 'after 1').n) && /Mx/.test(at(s, 'after 1').n), s + ' brick after raid 1');
    assert.ok(!/x/.test(at(s, 'after 2').n), s + ' metal (and everything) after raid 2: ' + at(s, 'after 2').n);
    for (let w = 3; w <= 12; w++) { const r = at(s, 'after ' + w); assert.ok(!/x/.test(r.n), `${s} after raid ${w} (${r.map}) all open: ${r.n}`) }
    assert.deepEqual(['after 3', 'after 6', 'after 9'].map(k => at(s, k).map), ['river', 'quarry', 'frost']);
  }
  assert.deepEqual(errors, []); console.log(JSON.stringify(out.std.map(r => r.at + ' ' + r.map + ' ' + r.n))); console.log('errors: none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
