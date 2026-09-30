// v0.9.3.6: Dell is shown as Delgado everywhere a player reads it; internal ids stay 'dell'. node delgado.js
const { chromium } = require('playwright'), assert = require('node:assert/strict'), fs = require('node:fs');
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), errors = [], out = {};
  for (const vp of [{ width: 390, height: 844 }, { width: 844, height: 390 }]) {
    const p = await b.newPage({ viewport: vp, isMobile: true, hasTouch: true }); p.on('pageerror', e => errors.push(e.message));
    await p.goto(`http://localhost:${process.env.PORT || 8080}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal);
    const text = await p.evaluate(() => document.body.innerText + ' ' + document.body.innerHTML.replace(/<[^>]+>/g, ' '));
    await p.click('[data-go=solo]'); const lede = await p.textContent('#pg-solo .lede').catch(() => '');
    await p.click('#startBtn'); await p.waitForTimeout(600);
    const hud = await p.evaluate(() => { const lab = document.querySelector('#qmM .lab'), r = lab.getBoundingClientRect(), m = document.getElementById('qmM').getBoundingClientRect(); return { lab: lab.textContent, fits: r.right <= m.right + 1 && lab.scrollWidth <= lab.clientWidth + 1 } });
    const armory = await p.evaluate(() => { const P = __pal; P.player.sal = 999; P.game.phase = 'build'; P.renderArmory(); return [...document.querySelectorAll('#armory .aRow b, #armory [data-k] b, #armory b')].map(e => e.textContent).filter(t => /DEL/.test(t)) });
    await p.screenshot({ path: `${__dirname}/out/delgado_${vp.width}x${vp.height}.png` });
    out[vp.width + 'x' + vp.height] = { lede, hud, armory, dellLeft: /\bDell\b(?! got you)|\bDELL\b/.test(text) };
    await p.close();
  }
  for (const v of Object.values(out)) { assert.equal(v.hud.lab, 'DELGADO'); assert.ok(v.hud.fits, 'HUD label fits'); assert.ok(v.armory.some(t => t.startsWith('DELGADO')), JSON.stringify(v.armory)); assert.equal(v.dellLeft, false); assert.match(v.lede, /Delgado.*Dell got you/) }
  fs.writeFileSync(__dirname + '/out/delgado.json', JSON.stringify({ out, errors }, null, 2)); assert.deepEqual(errors, []);
  console.log(JSON.stringify(out)); console.log('errors: none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
