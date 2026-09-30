// v0.9.3.9 HUD: on landscape phones the team bars sit in the bottom-left corner and the boss strip is one thin row at
// the top centre (two XL bosses side by side); nothing overlaps the kit column or the phase panel; portrait and
// desktop keep their layout. Screenshots in out/hud_*.png. node hud_layout.js
const { chromium } = require('playwright'), assert = require('node:assert/strict'), fs = require('node:fs');
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), errors = [], out = {};
  for (const [w, h, touch] of [[844, 390, true], [932, 430, true], [390, 844, true], [1280, 800, false]]) {
    const p = await b.newPage({ viewport: { width: w, height: h }, isMobile: touch, hasTouch: touch }); p.on('pageerror', e => errors.push(e.message));
    await p.goto(`http://localhost:${process.env.PORT || 8080}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal);
    await p.evaluate(() => { const P = __pal; P.pick.size = 'xl'; P.pick.map = 'yard' }); await p.click('[data-go=solo]'); await p.click('#startBtn'); await p.waitForTimeout(400);
    const r = await p.evaluate(() => { const P = __pal; P.game.paused = true;
      for (let i = 0; i < 5; i++) { const q = P.makePlayer('m' + i, 'Mate' + i, 'soldier', i + 1, '', ''); P.players.set('m' + i, q) }
      P.game.phase = 'raid'; P.game.wave = 5; P.spawnBoss('butcher'); P.spawnBoss('demolisher'); P.hud(.6); P.render(1 / 60);
      const R = id => { const e = document.querySelector(id); if (!e || e.closest('[hidden]')) return null; const r = e.getBoundingClientRect(); return { l: r.left, t: r.top, r: r.right, b: r.bottom } };
      const hit = (a, b) => a && b && a.l < b.r && b.l < a.r && a.t < b.b && b.t < a.b;
      const v = R('#top .vitals'), kit = R('#kit'), phase = R('#top .phase'), W = innerWidth, H = innerHeight;
      return { v, kit, phase, W, H, kitHit: hit(v, kit), phaseHit: hit(v, phase), mates: document.querySelectorAll('#mates .meter').length } });
    const land = h < w && touch;
    if (land) { assert.ok(r.v.b >= r.H - 20 && r.v.l <= 20, `team bars bottom-left at ${w}x${h}: ${JSON.stringify(r.v)}`); assert.ok(r.v.r < r.W * .4, 'compact') }
    else assert.ok(r.v.t <= 60, `team bars at the top at ${w}x${h}`);
    assert.ok(!r.kitHit && !r.phaseHit, `no overlap at ${w}x${h}: ${JSON.stringify(r)}`); assert.equal(r.mates, 5);
    out[w + 'x' + h] = { vitals: r.v, mates: r.mates };
    await p.screenshot({ path: `${__dirname}/out/hud_${w}x${h}.png` }); await p.close();
  }
  fs.writeFileSync(__dirname + '/out/hud_layout.json', JSON.stringify({ out, errors }, null, 2)); assert.deepEqual(errors, []);
  console.log(JSON.stringify(out)); console.log('errors: none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
