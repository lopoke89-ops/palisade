// v0.9.3.7: SETTINGS during a run opens an in-game overlay, not the main menu; no way to start or host another game
// from it; settings still work; pause/Escape and BACK return to the pause menu; online, the host keeps running.
// The main-menu Settings page still works outside a run. node ingame_settings.js
const { chromium } = require('playwright'), assert = require('node:assert/strict'), fs = require('node:fs');
const PORT = process.env.PORT || 8080, Q = 'peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1';
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--disable-features=WebRtcHideLocalIpsWithMdns'] }), errors = [], out = {};
  for (const vp of [{ width: 390, height: 844, isMobile: true, hasTouch: true }, { width: 1280, height: 800 }]) {
    const p = await b.newPage({ viewport: { width: vp.width, height: vp.height }, isMobile: !!vp.isMobile, hasTouch: !!vp.hasTouch }); p.on('pageerror', e => errors.push(e.message));
    await p.goto(`http://localhost:${PORT}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal);
    await p.click('[data-go=solo]'); await p.click('#startBtn'); await p.waitForTimeout(400);
    const gid = await p.evaluate(() => __pal.game.gid);
    await p.evaluate(() => __pal.togglePause()); await p.click('#pSetBtn');
    const r = await p.evaluate(() => { const vis = id => { const e = document.getElementById(id); return !!e && !e.closest('[hidden]') && e.getBoundingClientRect().width > 0 };
      return { ig: vis('igSet'), menu: !document.getElementById('menu').hidden, pause: !document.getElementById('pause').hidden, fps: vis('fpsSeg'), vol: vis('sVol'), save: vis('sExport'),
        start: vis('startBtn'), host: vis('hostBtn'), join: vis('joinBtn'), locker: vis('lockGrid'), paused: __pal.game.paused } });
    out['open' + vp.width] = r;
    assert.deepEqual(r, { ig: true, menu: false, pause: false, fps: true, vol: true, save: false, start: false, host: false, join: false, locker: false, paused: true });
    await p.screenshot({ path: `${__dirname}/out/ingame_settings_${vp.width}.png` });
    await p.click('#igSet [data-fpsm="30"]'); assert.equal(await p.evaluate(() => __pal.cfg.fpsMode), '30');
    // keyboard: Escape/P from the overlay goes back to the pause menu, not into the game
    await p.keyboard.press('p');
    out['back' + vp.width] = await p.evaluate(() => ({ ig: !document.getElementById('igSet').hidden, pause: !document.getElementById('pause').hidden, cardsHome: !!document.querySelector('#pg-settings #fpsSeg') }));
    assert.deepEqual(out['back' + vp.width], { ig: false, pause: true, cardsHome: true });
    // BACK button path too, then resume; still the same run
    await p.click('#pSetBtn'); await p.click('#igDone'); assert.equal(await p.evaluate(() => !document.getElementById('pause').hidden), true);
    await p.click('#resumeBtn'); assert.equal(await p.evaluate(() => __pal.game.gid), gid);
    // a deep link can't start another game over the run
    await p.evaluate(() => { document.getElementById('startBtn').click() }); assert.equal(await p.evaluate(() => __pal.game.gid), gid, 'start refused during a run');
    await p.close();
  }
  // outside a run, the menu Settings page still works
  const m = await b.newPage({ viewport: { width: 1280, height: 800 } }); m.on('pageerror', e => errors.push('m ' + e.message));
  await m.goto(`http://localhost:${PORT}/debug.html?debug=1`); await m.waitForFunction(() => window.__pal);
  await m.click('[data-go=settings]'); out.menuPage = await m.evaluate(() => !document.getElementById('pg-settings').hidden && !!document.querySelector('#pg-settings #sExport'));
  assert.equal(out.menuPage, true); await m.click('#sDone');
  // online: the host opening settings doesn't pause the raid for everyone
  const H = await b.newPage({ viewport: { width: 1000, height: 700 } }), G = await b.newPage({ viewport: { width: 1000, height: 700 } });
  for (const [x, n] of [[H, 'H'], [G, 'G']]) { x.on('pageerror', e => errors.push(n + ' ' + e.message)); await x.goto(`http://localhost:${PORT}/debug.html?${Q}`); await x.waitForFunction(() => window.__pal) }
  await H.click('[data-nav=multi]'); await H.click('#hostBtn'); await H.waitForFunction(() => /^[A-Z0-9]{4}$/.test(document.getElementById('lCode').textContent), null, { timeout: 15000 });
  const code = await H.textContent('#lCode'); await G.click('[data-nav=multi]'); await G.fill('#mCode', code); await G.click('#joinBtn');
  await G.waitForSelector('#pg-lobby:not([hidden])', { timeout: 15000 }); await H.click('#lStart'); await G.waitForFunction(() => __pal.NET.inGame && document.getElementById('menu').hidden, null, { timeout: 10000 });
  await H.waitForTimeout(500); await H.evaluate(() => __pal.togglePause()); await H.click('#pSetBtn');
  const t0 = await H.evaluate(() => __pal.game.time); await H.waitForTimeout(1200); const t1 = await H.evaluate(() => __pal.game.time);
  out.online = { hostTimeAdvanced: +(t1 - t0).toFixed(2), note: await H.textContent('#igSetNote'), hostCanHost: await H.evaluate(() => !!document.getElementById('hostBtn').closest('[hidden]') === false && document.getElementById('hostBtn').getBoundingClientRect().width > 0) };
  assert.ok(out.online.hostTimeAdvanced > .8 && /keeps going/.test(out.online.note) && !out.online.hostCanHost, JSON.stringify(out.online));
  fs.writeFileSync(__dirname + '/out/ingame_settings.json', JSON.stringify({ out, errors }, null, 2)); assert.deepEqual(errors, []);
  console.log(JSON.stringify(out)); console.log('errors: none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
