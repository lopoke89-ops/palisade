// v0.8.6 checks: locker music, lean published page (no debug hooks, PeerJS on demand, minified game runs)
const { chromium } = require('playwright'), { ready, frames, until } = require('./lib');
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--autoplay-policy=no-user-gesture-required'] });
  const errs = [];
  // 1. locker music (debug copy, so the test can look inside)
  const p = await b.newPage({ viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true }); p.on('pageerror', e => errs.push('dbg ' + e.message));
  await p.goto('http://localhost:8080/debug.html?debug=1'); await ready(p); await p.mouse.click(5, 5);
  const settled = () => until(p, () => __pal.mus.cur === __pal.musicWant(), null, 10000).catch(() => { });   // the wanted track is playing (downloaded and decoded)
  const m = () => p.evaluate(() => { const M = __pal.mus; return { want: __pal.musicWant(), track: M.cur, playing: !!M.src, loopEnd: M.src && +M.src.loopEnd.toFixed(3), decoded: Object.keys(M.bufs).join(',') } });
  await p.click('[data-go=locker]'); await settled(); console.log('on Locker page:', JSON.stringify(await m()));
  await p.evaluate(() => { __pal.locker.bag.afterglow = 1; __pal.renderLocker(); document.querySelector('[data-open=afterglow]').click() }); await settled();
  console.log('during a case spin:', JSON.stringify(await m()));
  await p.evaluate(() => document.getElementById('caseDone').click()); await settled();
  await p.evaluate(() => __pal.showPage('main')); await settled(); console.log('back to main menu:', JSON.stringify(await m()));
  await p.evaluate(() => __pal.showPage('solo')); await p.click('#startBtn'); await settled(); console.log('in a run (build phase):', JSON.stringify(await m()));
  await p.close();
  // 2. the published page: no hooks, PeerJS waits for the Multiplayer page, the minified game plays
  const q = await b.newPage({ viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true }); q.on('pageerror', e => errs.push('prod ' + e.message));
  await q.goto('http://localhost:8080/index.html?debug=1', { waitUntil: 'load' }); await frames(q, 10);
  console.log('published page: __pal present:', await q.evaluate(() => typeof window.__pal !== 'undefined'), '| PeerJS loaded after the menu came up:', await q.evaluate(() => typeof Peer !== 'undefined'));
  await q.click('[data-go=multi]'); await q.waitForFunction(() => typeof Peer !== 'undefined', null, { timeout: 8000 }).catch(() => { });
  console.log('PeerJS loaded after opening Multiplayer:', await q.evaluate(() => typeof Peer !== 'undefined'));
  await q.click('#mBack').catch(() => q.evaluate(() => document.querySelector('[data-back],#mBack,.back')?.click()));
  await q.goto('http://localhost:8080/index.html', { waitUntil: 'load' }); await frames(q, 3);
  await q.click('[data-go=solo]'); await q.click('#startBtn'); await frames(q, 3);
  await q.keyboard.press('Enter'); await q.keyboard.down('d'); await q.mouse.move(300, 300); await q.mouse.down(); await q.waitForTimeout(6000); await q.mouse.up(); await q.keyboard.up('d');
  await q.screenshot({ path: __dirname + '/out/v086_prod_run.png' });
  console.log('minified game ran a raid for 6 s; HUD raid label:', await q.evaluate(() => document.getElementById('phaseLab') ? document.getElementById('phaseLab').textContent : '?'));
  console.log('errors', errs.length ? errs : 'none'); await b.close();
})();
