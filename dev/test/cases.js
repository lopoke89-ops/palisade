// local (no account) case logic: odds, pools, buying, opening, mode-specific drops
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ executablePath:process.env.CHROMIUM||undefined });
  const p = await b.newPage({ viewport: { width: 520, height: 1000 } });
  const errs = []; p.on('pageerror', e => errs.push(e.message + ' ' + (e.stack || '').split('\n')[1]));
  const P = (f, a) => p.evaluate(f, a);
  await p.goto('http://localhost:8080/index.html?debug=1'); await p.waitForTimeout(600);
  console.log('odds (100k rolls each):', await P(() => { const out = {}; for (const id of ['supply', 'afterglow']) { const c = {}; let wrong = 0;
    for (let i = 0; i < 100000; i++) { const it = __pal.rollCase(id); c[it.r] = (c[it.r] || 0) + 1; if (it.box !== id) wrong++ }
    out[id] = Object.entries(c).sort((a, b) => a[1] - b[1]).map(([k, v]) => k + ' ' + (v / 1000).toFixed(2) + '%').join(', ') + (wrong ? ` WRONG POOL ${wrong}` : ' · pool ok') } return out }));
  // buy + open through the locker UI
  await P(() => { const L = __pal.locker; L.shards = 23; L.cases = 1; L.bag = {}; __pal.renderLocker && 0 });
  await p.click('[data-go=locker]'); await p.waitForTimeout(150);
  console.log('buttons:', await P(() => [...document.querySelectorAll('#caseBoxes button')].map(b => b.textContent + (b.disabled ? ' (off)' : '')).join(' | ')));
  await p.click('[data-buy=afterglow]'); await p.waitForTimeout(100); await p.click('[data-buy=afterglow]'); await p.waitForTimeout(100);
  console.log('after 2 buys:', await P(() => ({ shards: __pal.locker.shards, bag: __pal.locker.bag, buyOff: document.querySelector('[data-buy=afterglow]').disabled })));
  await p.click('[data-open=afterglow]'); await p.waitForTimeout(5200);
  console.log('opened afterglow:', await P(() => ({ eyebrow: document.getElementById('caseEye').textContent, got: document.getElementById('caseName').textContent + ' / ' + document.getElementById('caseSub').textContent, bag: __pal.locker.bag })));
  await p.screenshot({ path: __dirname + '/out/c_open.png' });
  await p.click('#caseDone');
  // mode drops: co-op pays supply only; base/ffa never pay supply, sometimes afterglow
  const drops = await P(() => { const P = __pal, L = P.locker, g = P.game; const res = {};
    for (const mode of ['', 'base', 'ffa']) { let sup = 0, ag = 0; const N = 2000;
      for (let i = 0; i < N; i++) { const s0 = L.cases, a0 = L.bag.afterglow | 0; g.pvp = mode; g.mode = '5'; g.time = 300;
        if (mode) { window.__demoOff = 1 } }
      res[mode || 'coop'] = { n: N } }
    return res });
  // call the reward functions directly with demo off (they no-op in the menu demo), so start a quick solo
  await p.click('#pg-locker [data-go=main]').catch(() => { });
  await P(() => __pal.showPage('solo')); await p.click('#startBtn'); await p.waitForTimeout(300);
  const dr = await P(() => { const P = __pal, L = P.locker, g = P.game, out = {};
    for (const [mode, win] of [['base', true], ['base', false], ['ffa', true], ['ffa', false]]) { let sup = 0, ag = 0; const N = 2000;
      g.pvp = mode; for (let i = 0; i < N; i++) { const s0 = L.cases, a0 = L.bag.afterglow | 0; g.time = 300; P.pvpReward(win, 3); sup += L.cases - s0; ag += (L.bag.afterglow | 0) - a0 }
      out[mode + (win ? ' win' : ' loss')] = `supply +${sup}, afterglow ${(100 * ag / N).toFixed(1)}%` }
    g.pvp = ''; const s0 = L.cases, a0 = L.bag.afterglow | 0; P.lockerReward(5, true, 30); out['coop 5-raid win'] = `supply +${L.cases - s0}, afterglow +${(L.bag.afterglow | 0) - a0}`;
    return out }).catch(e => 'ERR ' + e.message);
  console.log('drops:', dr);
  console.log('errors:', errs.length ? errs : 'none'); await b.close();
})();
