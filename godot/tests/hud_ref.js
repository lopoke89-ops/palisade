// The browser's HUD boxes, for tests/hud_shot.gd: the phase box at the top right and the tip, in each state the Godot
// HUD is checked in, at 1600x900 and 1280x720. Needs the site built (dev/build.py) and served on :8080.
//   node godot/tests/hud_ref.js            (writes godot/tests/hud_ref.json)
const { chromium } = require('../../dev/test/node_modules/playwright'), fs = require('fs'), path = require('path');
const SEL = { phase: '#top .phase', lab: '#phaseLab', pause: '#pauseBtn', val: '#phaseVal', core: '#coreM', core2: '#core2M', qm: '#qmCommand',
  note: '#phaseNote', salv: '#salv', skip: '#skipBtn', kc: '#skipBtn .kc', board: '#board', tip: '#tip span' };
// each state: what the browser starts, then what it changes (the same is set up on the Godot side)
const STATES = {
  build: { pick: { mode: '5', map: 'yard' } },
  raid: { pick: { mode: '5', map: 'yard' }, raid: true },
  blackout: { pick: { mode: 'blackout' } },
  base: { pick: { mode: '5', map: 'yard' }, pvp: 'base' },
  ffa: { pick: { mode: '5', map: 'yard' }, pvp: 'ffa' },
};
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), out = {};
  for (const [W, H] of [[1600, 900], [1280, 720]]) for (const [name, st] of Object.entries(STATES)) {
    const p = await b.newPage({ viewport: { width: W, height: H } });
    p.on('pageerror', e => console.log('page error', name, e.message));
    await p.goto(`http://localhost:${process.env.PORT || 8080}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal && __pal.ready);
    out[`${W}x${H}/${name}`] = await p.evaluate(async ([st, SEL]) => {
      const P = __pal, $ = id => document.getElementById(id);
      Object.assign(P.pick, st.pick); P.showPage('solo'); $('startBtn').click(); await new Promise(z => setTimeout(z, 600));
      if (st.raid) { P.game.timer = 0; await new Promise(z => setTimeout(z, 400)) }
      P.game.paused = true; P.toastClear();
      if (st.raid) { const n = $('phaseNote'); n.textContent = 'RAID 1 OF 5'; n.hidden = false }
      if (st.pvp === 'base') { P.game.pvp = 'base'; P.player.team = 'a'; if (P.cores.length < 2) P.cores.push({ team: 'b', i: 0, j: 0, hp: 700, max: 700, flash: 0 }) }
      if (st.pvp === 'ffa') { P.game.pvp = 'ffa'; P.game.goal = 15; P.player.kills = 0; P.player.deaths = 0 }
      P.hud(0); P.hud(.6); await new Promise(z => setTimeout(z, 600)); P.hud(0);   // the tip settles under the box on hud()'s half-second beat; the mini-map's box keeps 0.5 s
      const o = {};
      for (const [k, s] of Object.entries(SEL)) { const e = document.querySelector(s); if (!e || e.closest('[hidden]')) continue; const r = e.getBoundingClientRect(); if (!r.width || !r.height) continue;
        o[k] = { x: +r.left.toFixed(1), y: +r.top.toFixed(1), w: +r.width.toFixed(1), h: +r.height.toFixed(1), text: e.textContent.trim() } }
      if (st.pick.mode === 'blackout') { const M = P.boMapBox(); o.map = { x: M.x, y: M.y, w: M.w, h: M.h } }
      return o;
    }, [st, SEL]);
    await p.close();
  }
  fs.writeFileSync(path.join(__dirname, 'hud_ref.json'), JSON.stringify(out, null, 1) + '\n');
  await b.close();
})();
