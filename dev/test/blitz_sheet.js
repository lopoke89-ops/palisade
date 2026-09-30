// Contact sheets for the v0.9.4.0 Blitzkrieg art (review, not pass/fail): the ladder rewards and the Blitzkrieg Case
// (skins and Devil Horns at 4 angles, tracers, kill effects at 4 moments, both backgrounds), and the five boss variants
// next to the bosses they come from. node blitz_sheet.js <label>  -> out/blitz_<label>_*.png
const { chromium } = require('playwright'), fs = require('node:fs'), label = process.argv[2] || 'now';
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), p = await b.newPage({ viewport: { width: 1300, height: 900 } }), errors = [];
  p.on('pageerror', e => errors.push(e.message));
  await p.goto(`http://localhost:${process.env.PORT || 8080}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal);
  const shots = await p.evaluate(() => { const P = __pal, out = {}, bg = '#1a1f1c', ink = '#efe8d6';
    const canvas = (w, h) => { const c = document.createElement('canvas'); c.width = w; c.height = h; const x = c.getContext('2d'); x.fillStyle = bg; x.fillRect(0, 0, w, h); return [c, x] };
    const text = (x, t, cx, y, size = 13) => { x.fillStyle = ink; x.font = `600 ${size}px sans-serif`; x.textAlign = 'center'; x.fillText(t, cx, y) };
    // 1. figures: the two skins, Devil Horns on a standard soldier, Devil Horns tried on the Demon (blocked), four angles
    { const rows = [['Blue Butcher', { skin: 'bluebutcher', hat: 'class' }], ['Demon', { skin: 'demon', hat: 'class' }], ['Devil Horns', { skin: 'std', hat: 'devilhorns' }], ['Demon + Devil Horns (blocked)', { skin: 'demon', hat: 'devilhorns' }]];
      const angs = [.55, 1.6, 3.2, 4.9], cw = 220, ch = 280, [c, x] = canvas(cw * angs.length, rows.length * (ch + 24));
      rows.forEach(([n, cos], r) => { text(x, n, c.width / 2, r * (ch + 24) + 17, 15); const look = P.lookOf(cos, 'soldier');
        angs.forEach((a, k) => { const sc = 6, cx = k * cw + cw / 2, cy = r * (ch + 24) + 24 + ch - 12; if (look.aura) P.paintAura(x, look.aura, cx, cy, sc, 1.3, 1, 'ground');
          P.paintWardrobeCharacter(x, look, a, 0, sc, cx, cy, false); if (look.aura) P.paintAura(x, look.aura, cx, cy, sc, 1.3, 1, 'top') }) });
      out.figures = c.toDataURL() }
    // 2. tracers (the locker icon and a long shot), kill effects at four moments
    { const tr = ['bluearc', 'brimstone', 'tealwake', 'hellchain', 'sigil'], fx = ['hellportal', 'cinder', 'tealslash', 'ashbrand', 'demonclaw'], [c, x] = canvas(1100, 760);
      tr.forEach((k, i) => { const y = 30 + i * 70; text(x, P.COSBY['trail:' + k].name, 110, y + 26); x.fillStyle = '#0c0b09'; x.fillRect(220, y, 860, 50);
        for (let s = 0; s < 3; s++) P.traceSeg(x, 330 + s * 260, y + 25, 250 + s * 260, y + 25, P.TRAILS[k], 5 * (P.TRAILS[k].w || 1), s * .4, false) });
      fx.forEach((k, i) => { const y = 400 + i * 70; text(x, P.COSBY['fx:' + k].name, 110, y + 30);
        [.12, .3, .55, .85].forEach((q, j) => { x.fillStyle = '#0c0b09'; x.fillRect(220 + j * 215, y - 6, 205, 66); P.paintFinish(x, k, q, 1.25, 322 + j * 215, y + 44) }) });
      out.cosmetics = c.toDataURL() }
    // 3. backgrounds: Scorched Front (still) and Hellgate at three moments (the arc sweep, the rift sealing, a boss in the fire)
    { const [c, x] = canvas(1280, 820), W = 620, H = 349, pos = [[10, 30, 'bg', 'scorched', 0, 'Scorched Front'], [650, 30, 'bg', 'hellgate', .8, 'Hellgate · the arc sweeps'], [10, 440, 'bg', 'hellgate', 2.4, 'Hellgate · the rift seals'], [650, 440, 'bg', 'hellgate', 5, 'Hellgate · a boss in the fire']];
      for (const [px, py, , id, t, n] of pos) { const o = document.createElement('canvas'); o.width = W; o.height = H; P.drawBg(id, o.getContext('2d'), W, H, t); x.drawImage(o, px, py); text(x, n, px + W / 2, py - 8) }
      out.backgrounds = c.toDataURL() }
    // 4. the Blitzkrieg Case, its icons and the locker thumbnails of all 15 items
    { const items = P.COS.filter(k => k.box === 'blitz' || k.ladder === 'blitz'), n = items.length, cell = 150, cols = 8, [c, x] = canvas(cols * cell, Math.ceil(n / cols) * (cell + 22) + 10);
      items.forEach((it, i) => { const cv = document.createElement('canvas'); cv.width = cv.height = 128; P.drawIcon(cv, it); const cx = (i % cols) * cell, cy = Math.floor(i / cols) * (cell + 22);
        x.drawImage(cv, cx + 11, cy + 22); text(x, `${it.name} · ${it.r.toUpperCase()}${it.ladder ? ' · ladder' : ''}`, cx + cell / 2, cy + 14, 11) });
      out.icons = c.toDataURL() }
    return out });
  for (const k of Object.keys(shots)) fs.writeFileSync(`${__dirname}/out/blitz_${label}_${k}.png`, Buffer.from(shots[k].split(',')[1], 'base64'));
  // 5. the boss variants in play, next to their base bosses (a raid frozen with all ten on the field)
  const q = await b.newPage({ viewport: { width: 1200, height: 700 }, deviceScaleFactor: 2 }); q.on('pageerror', e => errors.push(e.message));
  await q.goto(`http://localhost:${process.env.PORT || 8080}/debug.html?debug=1`); await q.waitForFunction(() => window.__pal);
  await q.evaluate(() => { const P = __pal; P.demo = false; P.pick.mode = 'blitz'; P.pick.map = 'yard'; P.newGame(null, '', {}); P.enterGameHook(); const g = P.game; g.phase = 'raid'; g.wave = 5; g.queue = [];
    for (let k = 0; k < P.walls.length; k++) P.walls[k] = null; P.qm.alive = false; P.qm.gone = true; P.qm.x = P.qm.y = -9;
    const keys = ['butcher', 'bluebutcher', 'demolisher', 'arsonist', 'storm', 'tempest', 'ferryman', 'harbinger', 'foreman', 'bulldozer'];
    keys.forEach((k, i) => { P.spawnBoss(k); const e = P.enemies[P.enemies.length - 1], c = Math.floor(i / 2), r = i % 2; e.x = 4 + c * 1.9 + r * 1.9; e.y = 11 - c * 1.9 + r * 1.9; e.raft = false; e.aim = { x: .3, y: 1 }; e.cd = 99; e.ab = 99 });
    P.player.x = 9.2; P.player.y = 8.2; P.player.alive = false; P.player.downed = false; for (let i = 0; i < 20; i++) P.update(1 / 60); for (const e of P.enemies) { e.cd = 99; e.ab = 99; e.st = 0 } });
  await q.addStyleTag({ content: '#top,#kit,#toast,#tip,#keys,#chat,#chatBtn,#hud,.hud{display:none!important}' }); await q.waitForTimeout(500); await q.screenshot({ path: `${__dirname}/out/blitz_${label}_bosses.png` });
  console.log('saved', label, 'errors:', errors.length ? errors : 'none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
