const { chromium } = require('playwright');
const FAKE = () => { window.__fakePad = { id: 'Xbox', index: 0, connected: true, mapping: 'standard', axes: [0,0,0,0], buttons: Array.from({ length: 17 }, () => ({ pressed: false, value: 0 })) }; navigator.getGamepads = () => [window.__fakePad] };
const O = process.argv[2] || 'out';
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM });
  for (const [name, vp, mob] of [['desk', { width: 1440, height: 900 }, false], ['phone', { width: 390, height: 844 }, true]]) {
    const p = await b.newPage({ viewport: vp, isMobile: mob, hasTouch: mob }); await p.addInitScript(FAKE);
    await p.goto('http://localhost:8080/debug.html?debug=1'); await p.waitForTimeout(1300);
    const press = async i => { await p.evaluate(i => { __fakePad.buttons[i].pressed = true }, i); await p.waitForTimeout(60); await p.evaluate(i => { __fakePad.buttons[i].pressed = false }, i); await p.waitForTimeout(80) };
    await press(0); await press(13); await press(13); await p.screenshot({ path: `${O}/pad_${name}_solo.png` });
    await p.evaluate(() => { document.querySelector('[data-nav=settings]').click() }); await p.waitForTimeout(200);
    await p.evaluate(() => __pal.padFocusEl(document.querySelector('[data-pa=nade]'))); await p.waitForTimeout(100);
    await p.screenshot({ path: `${O}/pad_${name}_settings.png`, fullPage: false });
    await press(1); await p.evaluate(() => __pal.padFocusEl(document.getElementById('startBtn'))); await press(0); await p.waitForTimeout(800);
    await p.screenshot({ path: `${O}/pad_${name}_game.png` });
    await press(9); await p.waitForTimeout(200); await p.screenshot({ path: `${O}/pad_${name}_pause.png` });
    await p.close();
  }
  await b.close();
})();
