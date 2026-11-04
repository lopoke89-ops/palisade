// THE UNDERSTRIP v0.12.0: release screens for the evidence folder (a tool, not in the suite), from the release build's debug page:
// the menu's footer and the PLAY card's UNDERSTRIP, the Locker with the UNDERSTRIP CASE, an opening landing on one of its
// items, and a lobby with the Strip at Night behind High Roller. No account (the local locker).
// node understrip_capture_m5.js OUT_DIR        (a server on PORT, default 8080, serving the built site)
const { chromium } = require('playwright'), fs = require('node:fs'), path = require('node:path');
const OUT = process.argv[2] || path.join(__dirname, 'out/understrip-m5-shots'), PORT = process.env.PORT || 8080;
fs.mkdirSync(OUT, { recursive: true });
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), errors = [];
  const p = await b.newPage({ viewport: { width: 1280, height: 800 }, deviceScaleFactor: 2, reducedMotion: 'reduce' }); p.on('pageerror', e => errors.push(e.message));
  const shot = async n => { await p.screenshot({ path: path.join(OUT, n + '.png') }); console.log(n) };
  await p.goto(`http://localhost:${PORT}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal && __pal.ready);
  // the PLAY card set to THE UNDERSTRIP
  await p.evaluate(() => { const P = __pal; P.pick.mode = 'understrip'; P.showPage('solo'); document.querySelector('[data-m5=understrip]').click() }); await p.waitForTimeout(700); await shot('play-card');
  // the Locker: the case, then an opening
  await p.evaluate(() => { const P = __pal; let s = 21; Math.random = () => (s = (s * 16807) % 2147483647) / 2147483647; P.locker.bag.understrip = 3; P.showPage('locker'); P.renderLocker() }); await p.waitForTimeout(600);
  await p.evaluate(() => { const el = document.querySelector('[data-open=understrip]'); if (el) el.scrollIntoView({ block: 'center' }) }); await p.waitForTimeout(300); await shot('locker-case');
  await p.click('[data-open=understrip]'); await p.waitForTimeout(300); const intro = await p.$('#caseIntro'); if (intro && await intro.isVisible()) await p.click('#caseIntro');
  await p.waitForSelector('#caseResult:not([hidden])', { timeout: 20000 }); await p.waitForTimeout(700); await shot('case-opened');
  await p.waitForSelector('#caseDone:not([hidden])', { timeout: 10000 }); await p.click('#caseDone'); await p.waitForTimeout(300);
  // a lobby behind a new skin
  await p.evaluate(() => { const P = __pal; for (const id of ['skin:highroller', 'bg:stripnight', 'hat:neonhalo']) if (!P.locker.owned.includes(id)) P.locker.owned.push(id); P.locker.eq.skin = 'highroller'; P.locker.eq.bg = 'stripnight'; P.locker.eq.hat = 'class'; P.saveLocker && P.saveLocker(); P.showPage('solo') });
  await p.waitForTimeout(1200); await shot('lobby-stripnight');
  console.log('errors:', errors.length ? errors : 'none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
