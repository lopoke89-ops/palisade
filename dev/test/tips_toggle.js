// v0.9.3.9: Settings > Show tips during games. Off hides the how-to tips (in-game and from the in-game settings panel),
// on by default, persists across reload; toasts (boss arrivals etc.) still show. node tips_toggle.js
const { chromium } = require('playwright'), assert = require('node:assert/strict'), fs = require('node:fs');
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), errors = [], out = {};
  const p = await b.newPage({ viewport: { width: 900, height: 700 } }); p.on('pageerror', e => errors.push(e.message));
  await p.goto(`http://localhost:${process.env.PORT || 8080}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal);
  const tipShown = () => p.evaluate(() => !document.getElementById('tip').hidden && !!document.getElementById('tipText').textContent);
  await p.click('[data-go=solo]'); await p.click('#startBtn'); await p.waitForTimeout(400);
  out.defaultOn = await p.evaluate(() => __pal.cfg.tips) === true && await tipShown(); assert.ok(out.defaultOn, 'tips on by default and showing');
  // turn off from the in-game settings panel: the current tip disappears and new ones stay hidden
  await p.evaluate(() => __pal.togglePause()); await p.click('#pSetBtn'); await p.click('#igSet #sTips'); await p.click('#igDone'); await p.click('#resumeBtn');
  out.offNow = !(await tipShown()); await p.evaluate(() => { __pal.game.stats.built = 5; __pal.game.tip = 1 });
  await p.evaluate(() => { const P = __pal; P.game.phase = 'raid'; P.game.wave = 5; P.spawnBoss('butcher') }); await p.waitForTimeout(150);
  out.toast = await p.evaluate(() => document.getElementById('toast').textContent); out.stillOff = !(await tipShown());
  assert.ok(out.offNow && out.stillOff, 'tips hidden'); assert.match(out.toast, /BUTCHER/, 'boss toast still shows');
  await p.reload(); await p.waitForFunction(() => window.__pal); out.persisted = await p.evaluate(() => __pal.cfg.tips === false && !document.getElementById('sTips').checked);
  assert.ok(out.persisted);
  await p.click('[data-go=solo]'); await p.click('#startBtn'); await p.waitForTimeout(400); out.newRunOff = !(await tipShown()); assert.ok(out.newRunOff, 'first-run tip stays hidden next game');
  fs.writeFileSync(__dirname + '/out/tips_toggle.json', JSON.stringify({ out, errors }, null, 2)); assert.deepEqual(errors, []);
  console.log(JSON.stringify(out)); console.log('errors: none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
