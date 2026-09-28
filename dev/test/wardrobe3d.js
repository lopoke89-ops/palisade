// every skin and headgear looks different from the standard kit on the 3D model (none silently falls back). node wardrobe3d.js
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), p = await b.newPage(), errors = [];
  p.on('pageerror', e => errors.push(e.message));
  await p.goto(`http://localhost:${process.env.PORT || 8080}/debug.html?debug=1`); await p.waitForTimeout(900);
  const r = await p.evaluate(async () => {
    const P = __pal, shot = look => { const c = document.createElement('canvas'); c.width = 160; c.height = 220; const x = c.getContext('2d');
      P.drawWardrobeCharacter(x, look, .35, 0, 4, 80, 205, false); return c.toDataURL() };
    // the renderer may hand work to background workers; draw twice so the second draw comes from its cache
    const all = P.COS.filter(c => c.cat === 'skin' || c.cat === 'hat');
    for (const c of all) shot(P.lookOf({ ...P.locker.eq, skin: 'std', hat: 'class', [c.cat]: c.key }, 'soldier'));
    await new Promise(r => setTimeout(r, 1500));
    const base = shot(P.lookOf({ skin: 'std', hat: 'class', trail: 'std', fx: 'none' }, 'soldier')), same = [];
    for (const c of all) { if ((c.cat === 'skin' && c.key === 'std') || (c.cat === 'hat' && c.key === 'class')) continue;
      if (shot(P.lookOf({ skin: 'std', hat: 'class', trail: 'std', fx: 'none', [c.cat]: c.key }, 'soldier')) === base) same.push(c.id) }
    return { checked: all.length, sameAsStandard: same };
  });
  console.log(JSON.stringify(r));
  if (r.sameAsStandard.length) errors.push('looks like the standard kit in 3D: ' + r.sameAsStandard.join(', '));
  console.log('errors:', errors.length ? errors : 'none'); await b.close();
})();
