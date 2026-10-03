// v0.9.3.6 frame-rate setting: 30 / 60 caps, Auto on desktop vs touch, simulation time unaffected by the cap, and a
// host and guest at 30 FPS moving without host movement rejections. node fps_mode.js
const { chromium } = require('playwright'), assert = require('node:assert/strict'), fs = require('node:fs');
const PORT = process.env.PORT || 8080, Q = 'peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1';
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--disable-features=WebRtcHideLocalIpsWithMdns'] }), errors = [], out = {};
  const p = await b.newPage({ viewport: { width: 1100, height: 760 } }); p.on('pageerror', e => errors.push(e.message));
  await p.goto(`http://localhost:${PORT}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal);
  // the setting: three buttons, saved in cfg, reflected as selected
  await p.evaluate(() => __pal.showPage('settings'));
  await p.click('#fpsSeg [data-fpsm="30"]');
  out.setting = await p.evaluate(() => ({ mode: __pal.cfg.fpsMode, sel: document.querySelector('#fpsSeg .sel').dataset.fpsm, saved: JSON.parse(localStorage.getItem('palisade.cfg.v1')).fpsMode }));
  assert.deepEqual(out.setting, { mode: '30', sel: '30', saved: '30' });
  await p.evaluate(() => __pal.showPage('main')); await p.click('[data-go=solo]'); await p.click('#startBtn'); await p.waitForTimeout(400);
  await p.evaluate(() => { __pal.cfg.fps = true; __pal.applyCfg(); window.__keep = setInterval(() => { const P = __pal; P.core.hp = P.core.max; for (const q of P.players.values()) q.hp = q.max }, 100) });
  const measure = async () => { await p.waitForTimeout(1300); const t0 = await p.evaluate(() => [__pal.game.time, performance.now()]); await p.waitForTimeout(2100);
    const t1 = await p.evaluate(() => [__pal.game.time, performance.now(), document.getElementById('fpsLab').textContent]);
    return { fps: parseInt(t1[2]), label: t1[2], simPerReal: +((t1[0] - t0[0]) / ((t1[1] - t0[1]) / 1000)).toFixed(2) } };
  out.at30 = await measure();
  await p.evaluate(() => { __pal.cfg.fpsMode = '60'; __pal.applyCfg() }); out.at60 = await measure();
  await p.evaluate(() => { __pal.cfg.fpsMode = 'auto'; __pal.applyCfg() }); out.autoDesktopCap = await p.evaluate(() => __pal.fpsCap());
  assert.ok(out.at30.fps >= 26 && out.at30.fps <= 31, JSON.stringify(out.at30)); assert.ok(out.at60.fps >= 50 && out.at60.fps <= 61, JSON.stringify(out.at60));
  assert.ok(Math.abs(out.at30.simPerReal - out.at60.simPerReal) < .08 && out.at30.simPerReal > .9, 'game time runs at the same speed capped or not ' + JSON.stringify(out));
  assert.equal(out.autoDesktopCap, 60, 'v0.9.6.3: desktop Auto holds 60 (uncapped ran 144/240 Hz monitors flat out)');
  // Auto on a touch phone: 60, and 30 once the phone is struggling
  const m = await b.newPage({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, deviceScaleFactor: 2 }); m.on('pageerror', e => errors.push('m ' + e.message));
  await m.goto(`http://localhost:${PORT}/debug.html?debug=1`); await m.waitForFunction(() => window.__pal);
  out.autoTouch = await m.evaluate(() => { const a = __pal.fpsCap(); __pal.FPS_AUTO.drop = true; return [a, __pal.fpsCap()] });
  assert.deepEqual(out.autoTouch, [60, 30]);
  // host and guest both at 30: the guest's movement reaches the host without metering rejections
  const H = await b.newPage({ viewport: { width: 1000, height: 700 } }), G = await b.newPage({ viewport: { width: 1000, height: 700 } });
  for (const [x, n] of [[H, 'H'], [G, 'G']]) { x.on('pageerror', e => errors.push(n + ' ' + e.message)); await x.addInitScript(() => localStorage.setItem('palisade.cfg.v1', JSON.stringify({ fpsMode: '30' }))); await x.goto(`http://localhost:${PORT}/debug.html?${Q}`); await x.waitForFunction(() => window.__pal) }
  await H.click('[data-nav=multi]'); await H.click('#hostBtn'); await H.waitForFunction(() => /^[A-Z0-9]{4}$/.test(document.getElementById('lCode').textContent), null, { timeout: 15000 });
  const code = await H.textContent('#lCode'); await G.click('[data-nav=multi]'); await G.fill('#mCode', code); await G.click('#joinBtn');
  await G.waitForSelector('#pg-lobby:not([hidden])', { timeout: 15000 }); await H.click('#lStart'); await G.waitForFunction(() => __pal.NET.inGame && document.getElementById('menu').hidden, null, { timeout: 10000 }); await H.waitForTimeout(800);
  const gpos = () => H.evaluate(() => { const g = [...__pal.players.values()].find(q => q.id !== 'host'); return [g.x, g.y] });
  const a = await gpos(); await G.bringToFront(); await G.keyboard.down('KeyD'); await G.waitForTimeout(1600); await G.keyboard.up('KeyD'); await H.waitForTimeout(500);
  const bpos = await gpos();
  out.net = { moved: +Math.hypot(bpos[0] - a[0], bpos[1] - a[1]).toFixed(2), path: [a, bpos], rejects: await H.evaluate(() => [...__pal.NET.conns.values()].reduce((s, c) => s + (c.moveRejects | 0), 0)), caps: [await H.evaluate(() => __pal.fpsCap()), await G.evaluate(() => __pal.fpsCap())] };
  const seen = await H.evaluate(() => __pal.NET.conns.size);
  assert.ok(seen === 1 && out.net.rejects === 0 && out.net.moved > 1.5, JSON.stringify(out.net)); assert.deepEqual(out.net.caps, [30, 30]);
  fs.mkdirSync(__dirname + '/out', { recursive: true }); fs.writeFileSync(__dirname + '/out/fps_mode.json', JSON.stringify({ out, errors }, null, 2));
  assert.deepEqual(errors, []); console.log(JSON.stringify(out)); console.log('errors: none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
