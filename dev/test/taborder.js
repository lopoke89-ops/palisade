// v0.9.2.1 keyboard focus order: Tab walks every lobby page at desktop and phone-landscape sizes without landing on
// anything hidden or off-screen, and inside pause and the armory it stays in that window.
// node taborder.js
const { chromium } = require('playwright');
const PORT = process.env.PORT || 8080;
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined });
  const errors = [];
  const lab = () => { const e = document.activeElement; if (!e || e === document.body) return null; const q = e.getBoundingClientRect(), cs = getComputedStyle(e);
    const l = (e.id || e.dataset.nav || e.dataset.c || e.dataset.map || e.getAttribute('aria-label') || e.textContent || e.tagName).trim().replace(/\s+/g, ' ').slice(0, 22);
    const vis = q.width > 1 && q.height > 1 && cs.visibility !== 'hidden' && +cs.opacity > 0 && !e.closest('[hidden]');
    const inView = q.bottom > 0 && q.top < innerHeight && q.right > 0 && q.left < innerWidth;
    return { l, vis, inView, tag: e.tagName } };
  for (const vp of [{ width: 1440, height: 900 }, { width: 844, height: 390 }]) {
    const p = await b.newPage({ viewport: vp }); p.on('pageerror', e => errors.push(e.message));
    await p.goto(`http://localhost:${PORT}/debug.html?debug=1`); await p.waitForTimeout(1200);
    for (const pg of ['solo', 'multi', 'classes', 'locker', 'skills', 'settings', 'account']) {
      await p.evaluate(pg => { const b = document.querySelector(`[data-nav=${pg}]`) || document.getElementById('identityButton'); b.click(); document.activeElement.blur() }, pg); await p.waitForTimeout(150);
      const seq = [], bad = [];
      for (let i = 0; i < 90; i++) {
        await p.keyboard.press('Tab'); const r = await p.evaluate(lab);
        if (!r) continue;
        if (seq.filter(x => x === r.l).length > 1) break;
        seq.push(r.l); if (!r.vis || !r.inView) bad.push(`${r.l} (${r.vis ? 'off-screen' : 'invisible'})`);
      }
      console.log(vp.width, pg, '|', seq.length, 'stops', bad.length ? 'BAD: ' + [...new Set(bad)].join(', ') : 'ok');
      if (seq.length < 3) errors.push(`${vp.width} ${pg}: only ${seq.length} stops`);
      if (bad.length) errors.push(`${vp.width} ${pg}: ${[...new Set(bad)].join(', ')}`);
    }
    await p.close();
  }
  // windows over the game keep Tab inside them
  const p = await b.newPage({ viewport: { width: 1440, height: 900 } }); p.on('pageerror', e => errors.push(e.message));
  await p.goto(`http://localhost:${PORT}/debug.html?debug=1`); await p.waitForTimeout(1200);
  await p.click('#startBtn'); await p.waitForTimeout(500);
  const walk = async (name, scope) => { const seq = [];
    for (let i = 0; i < 12; i++) { await p.keyboard.press('Tab');
      seq.push(await p.evaluate(sc => { const e = document.activeElement; if (!e || e === document.body) return '·';
        return (document.getElementById(sc).contains(e) ? '' : '!OUT:') + (e.id || e.textContent || e.tagName).trim().replace(/\s+/g, ' ').slice(0, 18) }, scope)) }
    console.log(name, seq.slice(0, 6).join(' | '));
    if (seq.some(s => s.startsWith('!OUT') || s === '·')) errors.push(`${name}: Tab left the window: ${seq.join(' | ')}`) };
  await p.keyboard.press('Escape'); await p.waitForTimeout(200); await walk('pause', 'pause'); await p.keyboard.press('Escape'); await p.waitForTimeout(200);
  await p.evaluate(() => { const P = window.__pal; if (P && P.player) P.player.sal = 900 }); await p.keyboard.press('e'); await p.waitForTimeout(250);
  if (!(await p.evaluate(() => !document.getElementById('armory').hidden))) errors.push('armory did not open');
  else await walk('armory', 'armory');
  await b.close();
  console.log('errors:', errors.length ? errors : 'none');
})();
