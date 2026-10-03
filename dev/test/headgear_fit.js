// v0.9.3.9 headgear fit: for every hat, at 8 angles x 3 walk phases, every pixel the hat changes (against the same
// figure wearing Class Issue) stays inside a head-sized window. Per-hat changed area is recorded for review.
// Halo is exempt from the window (it floats by design). node headgear_fit.js
const { chromium } = require('playwright'), assert = require('node:assert/strict'), fs = require('node:fs');
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), p = await b.newPage(), errors = [];
  p.on('pageerror', e => errors.push(e.message));
  await p.goto(`http://localhost:${process.env.PORT || 8080}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal);
  const r = await p.evaluate(() => { const P = __pal, S = 6, W = 60 * S, H = 64 * S, ox = W / 2, oy = H - 4 * S, cv = document.createElement('canvas'); cv.width = W; cv.height = H;
    const x = cv.getContext('2d', { willReadFrequently: true });
    const px = (key, a, ph, skin = 'std') => { x.clearRect(0, 0, W, H); const look = P.lookOf({ skin, hat: key }, 'soldier'); look.gaitWeight = 1; P.paintWardrobeCharacter(x, look, a, 0, S, ox, oy, ph); return x.getImageData(0, 0, W, H).data };
    const hats = P.COS.filter(c => c.cat === 'hat' && c.key !== 'class' && c.key !== 'halo').map(c => c.key), bad = [], vol = {};
    for (const skin of ['std', 'phantom']) for (const key of hats) { let area = 0, n = 0;   // v0.9.7.1: the Phantom wears every hat again
      for (let a = 0; a < Math.PI * 2 - 1e-6; a += Math.PI / 4) for (const ph of [0, .8, 2.2]) {
        const A = px('class', a, ph, skin), B = px(key, a, ph, skin); let minY = H, maxAbsX = 0, maxY = 0, diff = 0;
        for (let i = 3; i < A.length; i += 4) { if (Math.abs(A[i] - B[i]) < 60 && Math.abs(A[i - 3] - B[i - 3]) + Math.abs(A[i - 2] - B[i - 2]) + Math.abs(A[i - 1] - B[i - 1]) < 60) continue;
          const q = (i - 3) / 4, X = q % W, Y = (q / W) | 0; diff++; minY = Math.min(minY, Y); maxY = Math.max(maxY, Y); maxAbsX = Math.max(maxAbsX, Math.abs(X - ox)) }
        const top = (oy - minY) / S, low = (oy - maxY) / S, side = maxAbsX / S; area += diff; n++;
        // head window: x within 10 units of the figure's centre line, y between the collar and 46 units up
        if (diff && (side > 10.5 || top > 46 || low < (key === 'ghillie' || key === 'witch' ? 16 : 22))) bad.push({ skin, key, a: +a.toFixed(2), ph, top: +top.toFixed(1), low: +low.toFixed(1), side: +side.toFixed(1) });
      }
      if (skin === 'std') vol[key] = Math.round(area / n / S / S); else if (!area) bad.push({ skin, key, missing: true }) }
    return { bad, vol, phantomOk: P.headwearAllowed('phantom', 'tophat') && P.headwearAllowed('phantom', 'crown') } });
  const hal = ['gravecap', 'stemband', 'batcirclet', 'bonewrap', 'webpin', 'skullseal'];
  const out = { outside: r.bad, halloweenArea: Object.fromEntries(hal.map(k => [k, r.vol[k]])), medianOtherArea: Object.entries(r.vol).filter(([k]) => !hal.includes(k)).map(([, v]) => v).sort((a, b) => a - b)[Math.floor((Object.keys(r.vol).length - 6) / 2)] };
  fs.writeFileSync(__dirname + '/out/headgear_fit.json', JSON.stringify({ out, all: r.vol, errors }, null, 2));
  console.log(JSON.stringify(out));
  assert.deepEqual(r.bad, [], 'every hat stays within the head window (and shows on the Phantom)'); assert.ok(r.phantomOk, 'the Phantom may wear headwear'); assert.deepEqual(errors, []);
  // area differing from Class Issue is recorded for review, not asserted: caps shaped like the helmet naturally differ less
  console.log('errors: none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
