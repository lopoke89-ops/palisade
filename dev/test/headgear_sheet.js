// Contact sheets for headgear review (not pass/fail): the six Halloween pieces at 4 angles and 2 scales, and every hat
// at 2 angles. node headgear_sheet.js <label>   -> out/headgear_<label>_halloween.png, out/headgear_<label>_all.png
const { chromium } = require('playwright'), fs = require('node:fs'), label = process.argv[2] || 'now';
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), p = await b.newPage({ viewport: { width: 1300, height: 900 } }), errors = [];
  p.on('pageerror', e => errors.push(e.message));
  await p.goto(`http://localhost:${process.env.PORT || 8080}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal);
  const shots = await p.evaluate(() => { const P = __pal, out = {};
    // head close-ups: paint the whole figure large on a scratch canvas, then crop the head
    const tmp = document.createElement('canvas'), tx = tmp.getContext('2d');
    const head = (key, a, scale, size) => { tmp.width = 40 * scale; tmp.height = 48 * scale; tx.clearRect(0, 0, tmp.width, tmp.height);
      P.paintWardrobeCharacter(tx, P.lookOf({ skin: 'std', hat: key }, 'soldier'), a, 0, scale, tmp.width / 2, tmp.height - 2 * scale, 0);
      return [tmp, tmp.width / 2 - 9 * scale, tmp.height - 2 * scale - 43 * scale, 18 * scale, 18 * scale] };
    const sheet = (items, cols, cell, scale, angles) => { const rows = Math.ceil(items.length / cols), cv = document.createElement('canvas'); cv.width = cols * cell * angles.length; cv.height = rows * (cell + 18); const x = cv.getContext('2d');
      x.fillStyle = '#202923'; x.fillRect(0, 0, cv.width, cv.height);
      items.forEach((it, i) => { const c = i % cols, r = Math.floor(i / cols);
        angles.forEach((a, k) => { const [src, sx, sy, sw, sh] = head(it.key, a, scale); x.drawImage(src, sx, sy, sw, sh, (c * angles.length + k) * cell, r * (cell + 18) + 18, cell, cell) });
        x.fillStyle = '#efe8d6'; x.font = '12px sans-serif'; x.textAlign = 'center'; x.fillText(it.name, (c * angles.length + angles.length / 2) * cell, r * (cell + 18) + 13) });
      return cv.toDataURL() };
    const hal = Object.keys(P.HALLOWEEN_HATS).map(k => ({ key: k, name: P.COSBY['hat:' + k].name }));
    out.halloween = sheet(hal, 2, 150, 12, [.55, 1.6, 3.2, 4.9]);
    const all = P.COS.filter(c => c.cat === 'hat').map(c => ({ key: c.key, name: c.name }));
    out.all = sheet(all, 6, 100, 8, [.55, 2.6]);
    out.side = sheet(all.slice(0, 16), 4, 150, 12, [1.6, 3.2, 4.9]);
    out.side2 = sheet(all.slice(16), 4, 150, 12, [1.6, 3.2, 4.9]);
    return out });
  for (const k of ['halloween', 'all', 'side', 'side2']) fs.writeFileSync(`${__dirname}/out/headgear_${label}_${k}.png`, Buffer.from(shots[k].split(',')[1], 'base64'));
  console.log('saved', label, 'errors:', errors.length ? errors : 'none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
