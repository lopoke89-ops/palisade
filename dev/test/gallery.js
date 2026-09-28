// Renders animated previews of cosmetics with the game's own drawing code (not a test). node gallery.js [outdir]
// Writes one folder of PNG frames per item plus items.json; dev/tools/make_gallery.py turns them into a page.
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const OUT = process.argv[2] || path.join(__dirname, 'out', 'gallery');
const ITEMS = {
  skins: ['pumpkin', 'cobweb', 'skeleton', 'mummy', 'reaper', 'phantom'],
  hats: ['jackolantern', 'witch', 'pumpkinking'],
  trails: ['candycorn', 'ghostfire'],
  fx: ['bats', 'spider', 'souls'],
  bgs: 'ALL',
};
(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined });
  const p = await b.newPage({ viewport: { width: 900, height: 700 }, deviceScaleFactor: 2 });
  const errs = []; p.on('pageerror', e => errs.push(e.message));
  await p.goto(`http://localhost:${process.env.PORT || 8080}/debug.html?debug=1`); await p.waitForTimeout(900);
  const save = (name, frames) => { const d = path.join(OUT, name); fs.mkdirSync(d, { recursive: true });
    frames.forEach((u, i) => fs.writeFileSync(path.join(d, String(i).padStart(3, '0') + '.png'), Buffer.from(u.split(',')[1], 'base64'))) };
  const meta = [];
  // figures: a turning, walking soldier (skins with the class hat; hats on the standard outfit), then the Pumpkin Butcher
  const fig = (look, cls, frames) => p.evaluate(({ look, cls, frames }) => {
    const P = __pal, c = document.createElement('canvas'); c.width = 360; c.height = 400; const x = c.getContext('2d'), out = [];
    for (let f = 0; f < frames; f++) {
      P.game.time = f / 12; const a = f / frames * Math.PI * 2, L = typeof look === 'string' ? JSON.parse(look) : look;
      x.setTransform(1, 0, 0, 1, 0, 0); const gr = x.createRadialGradient(180, 300, 20, 180, 260, 260); gr.addColorStop(0, '#3a3a2e'); gr.addColorStop(1, '#16150f'); x.fillStyle = gr; x.fillRect(0, 0, 360, 400);
      P.drawFig(x, 360, 400, Object.assign({}, L, { walk: f * .45, aim: { x: Math.cos(a), y: Math.sin(a) } }), 4.2, { x: Math.cos(a), y: Math.sin(a) }, 330);
      out.push(c.toDataURL('image/png'));
    } return out }, { look, cls, frames });
  for (const k of ITEMS.skins) { const look = await p.evaluate(k => JSON.stringify(__pal.lookOf({ skin: k, hat: 'class', trail: 'std', fx: 'none' }, 'soldier')), k);
    save('skin_' + k, await fig(look, 'soldier', 48)); meta.push({ id: 'skin:' + k, dir: 'skin_' + k, kind: 'figure' }) }
  for (const k of ITEMS.hats) { const look = await p.evaluate(k => JSON.stringify(__pal.lookOf({ skin: 'std', hat: k, trail: 'std', fx: 'none' }, 'soldier')), k);
    save('hat_' + k, await fig(look, 'soldier', 48)); meta.push({ id: 'hat:' + k, dir: 'hat_' + k, kind: 'figure' }) }
  { const look = await p.evaluate(() => JSON.stringify(Object.assign({ swing: 0 }, __pal.BOSS_VARIANTS.pumpkin.look, { big: 1 })));
    save('boss_pumpkin', await fig(look, '', 48)); meta.push({ id: 'boss:pumpkin', dir: 'boss_pumpkin', kind: 'figure', name: 'The Pumpkin Butcher', note: 'October look for the Butcher (same fight)' });
    const orig = await p.evaluate(() => JSON.stringify(Object.assign({ swing: 0 }, __pal.BOSSES.butcher.look)));
    save('boss_butcher', await fig(orig, '', 48)); meta.push({ id: 'boss:butcher', dir: 'boss_butcher', kind: 'figure', name: 'The Butcher (current, for comparison)' }) }
  // tracers and kill effects: in a real game scene, stepped frame by frame, cropped around the player
  await p.setViewportSize({ width: 390, height: 700 });
  await p.evaluate(() => { __pal.showPage('solo') }); await p.click('#startBtn'); await p.waitForTimeout(400); await p.keyboard.press('b'); await p.waitForTimeout(100);
  const scene = (mode, id, frames) => p.evaluate(({ mode, id, frames }) => {
    const P = __pal, pl = P.player, g = P.ctx, cv = g.canvas, dpr = cv.width / innerWidth;
    P.game.phase = 'build'; P.game.timer = 999; for (const e of P.enemies) e.dead = true; P.walls.fill(null);
    pl.x = 12.5; pl.y = 9.5; pl.hp = pl.max = 1e6; P.parts.length = 0; P.bullets.length = 0;
    if (mode === 'trail') { pl.cos.trail = id; pl.gun = Object.assign({}, pl.gun, { cd: .12 }) }
    for (let i = 0; i < 40; i++) { P.game.paused = false; P.update(1 / 30); P.game.paused = true; P.render(1 / 30) }   // let the camera settle on the player
    const c = document.createElement('canvas'); c.width = 520; c.height = 380; const x = c.getContext('2d'), out = [];
    for (let f = 0; f < frames; f++) {
      if (mode === 'trail') { const a = -.35 + Math.sin(f / frames * Math.PI * 2) * .5; pl.aim = { x: Math.cos(a), y: Math.sin(a) }; pl.fireIn = true; pl.autoFire = true }
      if (mode === 'fx' && (f === 2 || f === 34)) P.killFx(pl.x + .4, pl.y + 1.5, id);
      P.game.paused = false; P.update(1 / 30); P.game.paused = true; P.render(1 / 30);
      const [sx, sy] = P.iso(pl.x + (mode === 'fx' ? .4 : 1.4), pl.y + (mode === 'fx' ? 1.5 : -.4));
      x.drawImage(cv, (sx - 105) * dpr, (sy - 110) * dpr, 210 * dpr, 154 * dpr, 0, 0, 520, 380);
      out.push(c.toDataURL('image/png'));
    }
    pl.fireIn = false; return out }, { mode, id, frames });
  for (const k of ITEMS.trails) { save('trail_' + k, await scene('trail', k, 40)); meta.push({ id: 'trail:' + k, dir: 'trail_' + k, kind: 'scene' }) }
  for (const k of ITEMS.fx) { save('fx_' + k, await scene('fx', k, 64)); meta.push({ id: 'fx:' + k, dir: 'fx_' + k, kind: 'scene' }) }
  // lobby backgrounds: a phone-shaped frame
  const bgIds = ITEMS.bgs === 'ALL' ? await p.evaluate(() => Object.keys(__pal.BGS)) : ITEMS.bgs;
  for (const k of bgIds) {
    const fr = await p.evaluate(k => { const B = __pal.BGS[k], n = B.still !== undefined ? 1 : 60, c = document.createElement('canvas'); c.width = 390; c.height = 760; const x = c.getContext('2d'), out = [];
      for (let f = 0; f < n; f++) { x.clearRect(0, 0, 390, 760); __pal.drawBg(k, x, 390, 760, f / 10); out.push(c.toDataURL('image/png')) } return out }, k);
    save('bg_' + k, fr); meta.push({ id: 'bg:' + k, dir: 'bg_' + k, kind: 'bg', still: fr.length === 1 });
  }
  // names, rarities and how each is earned, from the game's own tables
  const info = await p.evaluate(ids => ids.map(id => { const P = __pal, [cat, key] = id.split(':');
    if (cat === 'bg') { const B = P.BGS[key]; return { id, name: B.name, r: B.r, box: B.box || null, how: B.src === 'free' ? 'Free' : B.src === 'case' ? ({ supply: 'Supply Case', afterglow: 'Afterglow Case', halloween: 'Halloween Case' })[B.box] : B.how, cat: 'LOBBY BACKGROUND' } }
    if (cat === 'boss') return { id, cat: 'BOSS LOOK' };
    const C = P.COSBY[id]; return { id, name: C.name, r: C.r, how: 'Halloween Case', cat: { skin: 'SKIN', hat: 'HEADGEAR', trail: 'TRACER', fx: 'KILL FX' }[cat] } }), meta.map(m => m.id));
  meta.forEach((m, i) => Object.assign(m, Object.fromEntries(Object.entries(info[i]).filter(([k, v]) => v !== undefined && !(k in m && m[k])))));
  fs.writeFileSync(path.join(OUT, 'items.json'), JSON.stringify(meta, null, 1));
  console.log('rendered', meta.length, 'items; errors', errs.length ? errs : 'none');
  await b.close();
})().catch(e => { console.log('Error:', e.message); process.exit(1) });
