// Network traffic meter (not pass/fail): host + 1 guest in a busy co-op raid with a walled base.
// Prints bytes the host sends per second to the guest, split by kind, plus what the guest sees.
// node netbench.js [port]   (default 8080; the site and a PeerJS server on :9000 must be running)
const { chromium } = require('playwright');
const port = process.argv[2] || 8080, Q = 'peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1';
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--disable-features=WebRtcHideLocalIpsWithMdns'] });
  const H = await b.newPage({ viewport: { width: 1280, height: 720 } }), G = await b.newPage({ viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true });
  const errs = []; for (const [p, t] of [[H, 'HOST'], [G, 'GUEST']]) p.on('pageerror', e => errs.push(t + ' ' + e.message));
  await H.goto(`http://localhost:${port}/${process.argv[3]||"debug.html"}?${Q}`); await G.goto(`http://localhost:${port}/${process.argv[3]||"debug.html"}?${Q}`); await H.waitForTimeout(700);
  await H.click('[data-go=multi]'); await H.fill('#mName', 'Host'); await H.click('#hostBtn');
  await H.waitForSelector('#pg-lobby:not([hidden])', { timeout: 10000 }); const code = await H.textContent('#lCode');
  await G.click('[data-go=multi]'); await G.fill('#mName', 'Guest'); await G.fill('#mCode', code); await G.click('#joinBtn');
  await G.waitForSelector('#pg-lobby:not([hidden])', { timeout: 10000 }); await H.waitForTimeout(500);
  await H.evaluate(()=>__pal.lobbyReadyAll());await H.click('#lStart'); await G.waitForFunction(() => document.getElementById('menu').hidden, null, { timeout: 6000 }); await H.waitForTimeout(800);
  await H.evaluate(() => {
    const P = __pal, N = 16, c = P.core; let k = 0;
    for (let j = 0; j < N; j++) for (let i = 0; i < N; i++) { const d = Math.max(Math.abs(i - c.i), Math.abs(j - c.j)); if ((d === 3 || d === 4) && !P.walls[j * N + i]) { P.walls[j * N + i] = P.makeWall(k % 3, k % 11 === 0); k++ } }
    P.player.x = c.i + .5; P.player.y = c.j + 1.5; P.game.wave = 3; P.startRaid();
    window.__bytes = { state: 0, events: 0, other: 0, msgs: 0 };
    const cnt = (m, kind) => { const n = JSON.stringify(m).length; window.__bytes[kind] += n; window.__bytes.msgs++ };
    const sa = P.NET.sendAll.bind(P.NET); P.NET.sendAll = (m, ch) => { cnt(m, m.t === 's' ? 'state' : m.t === 'x' ? 'events' : 'other'); return sa(m, ch) };
    if (P.NET.sendState) { const ss = P.NET.sendState.bind(P.NET); P.NET.sendState = m => { cnt(m, 'state'); return ss(m) } }
    // keep it busy: raiders can't die (so they keep shooting), and an explosion lands in the yard every 0.7 s
    let q = 0; window.__boom = setInterval(() => { for (const e of P.enemies) { e.hp = e.max = 1e6 } q++; P.explode(3 + (q * 5) % 10, 2 + (q * 3) % 5, 1.2, 1, null) }, 700);
  });
  // the guest holds fire the whole time (its input messages say so)
  await G.evaluate(() => { const f = __pal.NET.toHost.bind(__pal.NET); __pal.NET.toHost = (m, c) => { if (m.t === 'i') m.f = 1; return f(m, c) } });
  await H.waitForTimeout(2000); await H.evaluate(() => { for (const k in window.__bytes) window.__bytes[k] = 0 });
  const samples = [];
  for (let t = 0; t < 10; t++) { await H.waitForTimeout(1000); samples.push(await G.evaluate(() => ({ bullets: __pal.bullets.length, parts: __pal.parts.length, walls: __pal.walls.filter(Boolean).length }))) }
  const bytes = await H.evaluate(() => window.__bytes), hostWalls = await H.evaluate(() => __pal.walls.filter(Boolean).length), hostEnemies = await H.evaluate(() => __pal.enemies.length);
  const kb = x => +(x / 10 / 1024).toFixed(1);
  console.log(JSON.stringify({ port, KB_per_s: { state: kb(bytes.state), events: kb(bytes.events), other: kb(bytes.other), total: kb(bytes.state + bytes.events + bytes.other) }, msgs_per_s: bytes.msgs / 10,
    guest_saw: { max_bullets: Math.max(...samples.map(s => s.bullets)), max_particles: Math.max(...samples.map(s => s.parts)), walls: samples.at(-1).walls, host_walls: hostWalls }, host_enemies: hostEnemies, errors: errs.length ? errs.slice(0, 3) : 'none' }));
  await b.close();
})();
