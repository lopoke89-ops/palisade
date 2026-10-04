// v0.9.9 HUD: the team health panel is gone during matches (health is drawn above heads); core health sits in the
// phase box under the timer, the phase box stays top right and doesn't overlap the kit column, and every mate still
// gets a nameplate. Screenshots in out/hud_*.png. node hud_layout.js
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
      const R = id => { const e = typeof id === 'string' ? document.querySelector(id) : id; if (!e || e.closest('[hidden]')) return null; const r = e.getBoundingClientRect(); return { l: r.left, t: r.top, r: r.right, b: r.bottom } };
      const hit = (a, b) => a && b && a.l < b.r && b.l < a.r && a.t < b.b && b.t < a.b;
      const v = R('#top .vitals'), kit = R('#kit'), phase = R('#top .phase'), core = R('#coreM'), W = innerWidth, H = innerHeight;
      const kitHit = [...document.querySelectorAll('#kit > *')].some(k => k.getBoundingClientRect().width && hit(R(k), phase));
      P.drawNameplates(); const mates = new Set(P.plates.map(e => e.who || e.arrow).filter(n => /^mate/i.test(n || ''))).size;
      return { v, kit, phase, core, W, H, kitHit, mates } });
    assert.equal(r.v, null, `no health panel at ${w}x${h}`);
    assert.ok(r.core && r.core.l >= r.phase.l - 1 && r.core.r <= r.phase.r + 1 && r.core.b <= r.phase.b + 1, `core bar inside the phase box at ${w}x${h}`);
    assert.ok(r.phase.r >= r.W - 40 && r.phase.t <= 30, `phase box top right at ${w}x${h}: ${JSON.stringify(r.phase)}`);
    assert.ok(!r.kitHit, `phase box clear of the kit at ${w}x${h}: ${JSON.stringify(r)}`); assert.equal(r.mates, 5);
    out[w + 'x' + h] = { phase: r.phase, core: r.core, mates: r.mates };
    await p.screenshot({ path: `${__dirname}/out/hud_${w}x${h}.png` }); await p.close();
  }
  fs.writeFileSync(__dirname + '/out/hud_layout.json', JSON.stringify({ out, errors }, null, 2)); assert.deepEqual(errors, []);
  console.log(JSON.stringify(out)); console.log('errors: none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
