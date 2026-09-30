// Network traffic meter (not pass/fail), v0.9.1: six players online on an XL (24×24) Riverbend, in a boss raid
// with both XL bosses up, plus a busy normal raid. Prints what the host sends each guest per second, split by kind,
// and the host's frame time while it runs. node netxl.js [port] [page]   (MODS=weather,nightmare to switch modifiers on)
const { chromium } = require('playwright');
const port = process.argv[2] || 8080, page = process.argv[3] || 'debug.html', Q = 'peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1';
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--disable-features=WebRtcHideLocalIpsWithMdns'] });
  const errs = [], open = async (vp, tag) => { const p = await b.newPage({ viewport: vp }); p.on('pageerror', e => errs.push(tag + ' ' + e.message)); await p.goto(`http://localhost:${port}/${page}?${Q}`); await p.waitForTimeout(600); return p };
  const H = await open({ width: 1280, height: 720 }, 'HOST');
  await H.click('[data-go=multi]'); await H.fill('#mName', 'Host'); await H.click('[data-setup=map]:visible'); await H.click('[data-mmap=river]'); await H.click('#sizeSeg [data-size=xl]'); await H.click('#setupDone'); await H.click('#hostBtn');
  await H.waitForSelector('#pg-lobby:not([hidden])', { timeout: 10000 }); const code = await H.textContent('#lCode');
  const G = [];
  for (let n = 1; n <= 5; n++) { const g = await open({ width: 400, height: 300 }, 'G' + n); await g.click('[data-go=multi]'); await g.fill('#mName', 'Guest' + n); await g.fill('#mCode', code); await g.click('#joinBtn');
    await g.waitForSelector('#pg-lobby:not([hidden])', { timeout: 15000 }); G.push(g) }
  await H.waitForFunction(() => __pal.NET.roster.length === 6, null, { timeout: 10000 });
  if (process.env.MODS) await H.evaluate(m => { for (const id of m.split(',')) __pal.toggleMod('coop', id) }, process.env.MODS);   // v0.9.2: e.g. MODS=weather,nightmare
  await H.click('#lStart'); for (const g of G) await g.waitForFunction(() => document.getElementById('menu').hidden, null, { timeout: 8000 }); await H.waitForTimeout(1000);
  const meter = async (label, setup) => {
    await H.evaluate(setup);
    await H.evaluate(() => {
      const P = __pal; window.__bytes = { state: 0, events: 0, other: 0, msgs: 0 };
      const cnt = (m, kind) => { window.__bytes[kind] += JSON.stringify(m).length; window.__bytes.msgs++ };
      if (!P.NET.__wrapped) { P.NET.__wrapped = true; const sa = P.NET.sendAll.bind(P.NET); P.NET.sendAll = (m, ch) => { cnt(m, m.t === 's' ? 'state' : m.t === 'x' ? 'events' : 'other'); return sa(m, ch) };
        if (P.NET.sendState) { const ss = P.NET.sendState.bind(P.NET); P.NET.sendState = m => { cnt(m, 'state'); return ss(m) } } }
      window.__ft = []; let last = performance.now(); const f = now => { window.__ft.push(now - last); last = now; if (window.__ft.length < 2000) requestAnimationFrame(f) }; requestAnimationFrame(f);
    });
    await H.waitForTimeout(1500); await H.evaluate(() => { for (const k in window.__bytes) window.__bytes[k] = 0; window.__ft = [] });
    await H.waitForTimeout(10000);
    const r = await H.evaluate(() => { const ft = window.__ft.slice().sort((a, b) => a - b); return { bytes: window.__bytes, enemies: __pal.enemies.length, bosses: __pal.enemies.filter(e => e.type === 'boss').map(e => e.boss), p50: ft[Math.floor(ft.length / 2)], p95: ft[Math.floor(ft.length * .95)] } });
    const kb = x => +(x / 10 / 1024).toFixed(1), B = r.bytes;
    return { label, per_guest_KB_s: { state: kb(B.state), events: kb(B.events), other: kb(B.other), total: kb(B.state + B.events + B.other) }, msgs_s: B.msgs / 10, enemies: r.enemies, bosses: r.bosses, host_frame_ms: { p50: +r.p50.toFixed(1), p95: +r.p95.toFixed(1) } };
  };
  const res = [];
  // a big normal raid: raiders can't die, so the yard stays full and shooting
  res.push(await meter('XL raid 9, six players', () => { const P = __pal; P.game.wave = 8; P.startRaid(); window.__keep = setInterval(() => { for (const e of P.enemies) e.hp = e.max = 1e6; for (const p of P.players.values()) { p.hp = p.max } P.core.hp = P.core.max }, 200) }));
  // the XL boss raid: both bosses up at once
  res.push(await meter('XL boss raid (two bosses), six players', () => { const P = __pal; clearInterval(window.__keep); for (const e of P.enemies) e.dead = true; P.game.queue = []; P.game.phase = 'build'; P.game.wave = 9; P.startRaid();
    for (const q of P.game.queue.filter(q => q.startsWith('boss:'))) P.spawnBoss(q.slice(5)); P.game.queue = P.game.queue.filter(q => !q.startsWith('boss:'));
    window.__keep = setInterval(() => { for (const e of P.enemies) e.hp = Math.max(e.hp, e.max * .6); for (const p of P.players.values()) { p.hp = p.max } P.core.hp = P.core.max }, 200) }));
  const guestSaw = await G[0].evaluate(() => ({ N: __pal.N, map: __pal.game.map, enemies: __pal.enemies.length, bosses: __pal.enemies.filter(e => e.type === 'boss').length }));
  console.log(JSON.stringify({ players: 6, results: res, guest_saw: guestSaw, errors: errs.length ? errs.slice(0, 3) : 'none' }, null, 1));
  await b.close();
})();
