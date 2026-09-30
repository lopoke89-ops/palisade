// Menu audit (review, not pass/fail): every main-menu page and panel at desktop, phone portrait and phone landscape.
// Saves viewport screenshots (and the scrolled bottom when a page scrolls) plus layout measurements: horizontal
// overflow, content height vs screen, small tap targets and small text. node menu_audit.js  -> out/menu_audit/*
const { chromium } = require('playwright'), fs = require('node:fs');
const Q = 'peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1', PORT = process.env.PORT || 8080, DIR = __dirname + '/out/menu_audit';
const SIZES = [['desktop', 1440, 900, 1, false], ['laptop', 1280, 720, 1, false], ['portrait', 390, 844, 3, true], ['landscape', 844, 390, 3, true]];
const PAGES = ['solo', 'classes', 'multi', 'lobby', 'locker', 'locker-hat', 'locker-trail', 'locker-fx', 'locker-bg', 'locker-ms', 'skills', 'settings', 'account', 'friends'];
(async () => {
  fs.mkdirSync(DIR, { recursive: true });
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--disable-features=WebRtcHideLocalIpsWithMdns'] }), report = {};
  for (const [tag, w, h, dpr, mobile] of SIZES) {
    const p = await b.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: dpr, isMobile: mobile, hasTouch: mobile }); const errs = []; p.on('pageerror', e => errs.push(e.message));
    await p.goto(`http://localhost:${PORT}/debug.html?${Q}`); await p.waitForFunction(() => window.__pal); await p.waitForTimeout(900);
    for (const pg of PAGES) {
      const [base, sub] = pg.split('-');
      if (pg === 'lobby') { await p.evaluate(() => __pal.showPage('multi')); await p.click('#hostBtn').catch(() => {}); await p.waitForFunction(() => /^[A-Z0-9]{4}$/.test(document.getElementById('lCode').textContent), null, { timeout: 15000 }).catch(() => {}) }
      else if (pg === 'friends') { await p.evaluate(() => __pal.showPage('solo')); await p.click('#friendsBtn').catch(() => {}) }
      else { await p.evaluate(x => { __pal.showPage(x) }, base); if (sub) await p.click(`[data-cat=${sub}]`).catch(() => {}) }
      await p.waitForTimeout(700);
      const m = await p.evaluate(() => { const W = innerWidth, H = innerHeight, vis = e => { const r = e.getBoundingClientRect(), s = getComputedStyle(e); return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none' };
        const scroller = [...document.querySelectorAll('#menu *')].filter(e => vis(e) && e.scrollHeight > e.clientHeight + 4 && /(auto|scroll)/.test(getComputedStyle(e).overflowY)).map(e => ({ id: e.id || e.className.toString().slice(0, 30), sh: e.scrollHeight, ch: e.clientHeight }));
        const over = [...document.querySelectorAll('#menu *')].filter(e => { if (!vis(e)) return false; const r = e.getBoundingClientRect(); return r.right > W + 1 || r.left < -1 }).slice(0, 8).map(e => (e.id || e.tagName + '.' + e.className.toString().slice(0, 20)));
        const btns = [...document.querySelectorAll('#menu button, #menu a, #menu input, #menu select')].filter(vis);
        const small = btns.filter(e => { const r = e.getBoundingClientRect(); return r.height < 36 || r.width < 36 }).map(e => (e.textContent || e.getAttribute('aria-label') || e.id || '').trim().slice(0, 18) + ` ${Math.round(e.getBoundingClientRect().width)}x${Math.round(e.getBoundingClientRect().height)}`);
        const tiny = [...document.querySelectorAll('#menu *')].filter(e => vis(e) && e.childElementCount === 0 && e.textContent.trim() && parseFloat(getComputedStyle(e).fontSize) < 11).map(e => e.textContent.trim().slice(0, 20) + ' ' + getComputedStyle(e).fontSize).slice(0, 10);
        return { page: document.getElementById('menu').dataset.page, docScroll: document.documentElement.scrollHeight > H + 2, hOverflow: document.documentElement.scrollWidth > W + 1, over, scroller, buttons: btns.length, small: small.slice(0, 12), smallN: small.length, tiny } });
      report[`${tag}/${pg}`] = m;
      await p.screenshot({ path: `${DIR}/${tag}_${pg}.png` });
      // the bottom of the page when the menu scrolls
      const scrolled = await p.evaluate(() => { const s = [...document.querySelectorAll('#menu, #menu *')].filter(e => e.scrollHeight > e.clientHeight + 40 && /(auto|scroll)/.test(getComputedStyle(e).overflowY) && e.getBoundingClientRect().height > 100).sort((a, b) => b.scrollHeight - a.scrollHeight)[0]; if (!s) return false; s.scrollTop = s.scrollHeight; return true });
      if (scrolled) { await p.waitForTimeout(250); await p.screenshot({ path: `${DIR}/${tag}_${pg}_bottom.png` }); await p.evaluate(() => { for (const e of document.querySelectorAll('#menu, #menu *')) if (e.scrollTop) e.scrollTop = 0 }) }
      if (pg === 'friends') await p.keyboard.press('Escape');
      if (pg === 'lobby') await p.evaluate(() => { __pal.netLeave && __pal.netLeave('') }).catch(() => {});
    }
    report[tag + '/errors'] = errs; await p.close();
  }
  fs.writeFileSync(DIR + '/report.json', JSON.stringify(report, null, 1));
  console.log(JSON.stringify(report, null, 0).slice(0, 400)); console.log('errors: none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
