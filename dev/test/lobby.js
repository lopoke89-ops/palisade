// v0.9.0 lobby: navigation, PLAY panel (map, size, job), backgrounds, starting a run, phone layout, and the
// host's map reaching a guest. node lobby.js
const { chromium } = require('playwright');
const assert = require('assert');
const Q = 'peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1', PORT = process.env.PORT || 8080;
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--disable-features=WebRtcHideLocalIpsWithMdns'] });
  const errors = [], out = {};
  const open = async (vp, mobile) => { const p = await b.newPage({ viewport: vp, isMobile: !!mobile, hasTouch: !!mobile }); p.on('pageerror', e => errors.push(e.message));
    await p.goto(`http://localhost:${PORT}/debug.html?${Q}`); await p.waitForTimeout(1200); return p };
  const page = p => p.evaluate(() => document.getElementById('menu').dataset.page);
  const cur = p => p.evaluate(() => [...document.querySelectorAll('[data-nav][aria-current=page]')].map(b => b.dataset.nav).join());
  // 1. desktop: lands on PLAY, background up, every nav button goes where it says
  const p = await open({ width: 1440, height: 900 });
  assert.equal(await page(p), 'solo'); assert.equal(await cur(p), 'solo');
  assert.equal(await p.evaluate(() => document.getElementById('lobbyBg').hidden), false, 'background shows on PLAY');
  for (const nav of ['multi', 'classes', 'locker', 'settings', 'solo']) {
    await p.click(`[data-nav=${nav}]`); await p.waitForTimeout(150);
    assert.equal(await page(p), nav, 'nav ' + nav);
    if (['solo', 'classes', 'multi'].includes(nav)) assert.equal(await cur(p), nav);
  }
  await p.click('[data-nav=settings]'); await p.click('#sDone'); assert.equal(await page(p), 'solo', 'settings DONE returns to PLAY');
  await p.click('[data-nav=locker]'); await p.click('#pg-locker [data-go=main]'); assert.equal(await page(p), 'solo', 'locker BACK returns to PLAY');
  await p.click('#identityButton'); assert.equal(await page(p), 'account'); await p.click('#pg-account [data-go=main]');
  // 2. PLAY: job, map card, size; the stage title follows
  await p.click('#pg-solo [data-c=grenadier]'); assert.equal(await p.evaluate(() => __pal.pick.cls), 'grenadier');
  await p.click('.mapCard[data-map=river]'); await p.click('#sizeSeg [data-size=xl]');
  out.play = await p.evaluate(() => ({ map: __pal.pick.map, size: __pal.pick.size, cards: document.querySelectorAll('.mapCard').length, sel: document.querySelector('.mapCard.sel').dataset.map,
    title: document.getElementById('partyMode').textContent, soloMap: document.getElementById('soloMap').textContent }));
  assert.equal(out.play.map, 'river'); assert.equal(out.play.size, 'xl'); assert.equal(out.play.cards, 3); assert.match(out.play.title, /RIVERBEND XL/);
  await p.click('[data-nav=classes]'); out.classesSel = await p.evaluate(() => document.querySelector('#classes .sel').dataset.c); assert.equal(out.classesSel, 'grenadier');
  await p.click('#classes [data-c=sniper]'); assert.equal(await p.evaluate(() => document.getElementById('partyTitle').textContent), 'SNIPER');
  await p.click('#pg-classes [data-go=solo]');
  // 3. start: the run is on the chosen map and size, and the background canvas is gone
  await p.click('#startBtn'); await p.waitForTimeout(500);
  out.run = await p.evaluate(() => ({ map: __pal.game.map, size: __pal.game.size, N: __pal.N, cls: __pal.player.cls, menu: document.getElementById('menu').hidden, bg: document.getElementById('lobbyBg').hidden,
    water: [...__pal.terr].filter(t => t === 1).length }));
  assert.deepEqual([out.run.map, out.run.size, out.run.N, out.run.cls, out.run.menu, out.run.bg], ['river', 'xl', 24, 'sniper', true, true]);
  assert.ok(out.run.water > 30, 'river has water');
  await p.evaluate(() => __pal.toMenu()); await p.waitForTimeout(300);
  out.back = await p.evaluate(() => ({ page: document.getElementById('menu').dataset.page, bg: document.getElementById('lobbyBg').hidden, demoMap: __pal.game.map, N: __pal.N }));
  assert.deepEqual(out.back, { page: 'solo', bg: false, demoMap: 'yard', N: 16 }, 'menu again, the demo yard is 16x16');
  // 4. backgrounds: an old save with the removed live-yard choice falls back to a real background
  await p.evaluate(() => { __pal.locker.eq.bg = 'yard'; __pal.showPage('solo') }); assert.equal(await p.evaluate(() => document.getElementById('lobbyBg').hidden), false, 'always a background');
  await p.evaluate(() => { __pal.locker.eq.bg = 'campfire'; __pal.showPage('solo') });
  await p.click('[data-nav=locker]'); await p.click('#lockTabs [data-cat=bg]'); await p.waitForTimeout(200);
  out.bgTab = await p.evaluate(() => ({ tiles: document.querySelectorAll('#lockGrid .item').length, owned: document.querySelectorAll('#lockGrid .item:not(.lock)').length }));
  assert.ok(out.bgTab.tiles >= 25 && out.bgTab.owned >= 2, 'background tiles');
  await p.locator('#lockGrid .item:not(.lock)').nth(1).click(); out.equipped = await p.evaluate(() => __pal.locker.eq.bg);
  await p.screenshot({ path: __dirname + '/out/lobby_desk.png' });
  await p.close();
  // 5. phone: nothing wider than the screen on the lobby pages
  const q = await open({ width: 390, height: 844 }, true);
  for (const nav of ['solo', 'classes', 'multi']) { await q.evaluate(x => __pal.showPage(x), nav); await q.waitForTimeout(150);
    const o = await q.evaluate(() => ({ sw: document.querySelector('#menu .panel').scrollWidth, cw: document.querySelector('#menu .panel').clientWidth }));
    assert.ok(o.sw <= o.cw + 1, 'phone overflow on ' + nav + ' ' + JSON.stringify(o)) }
  await q.evaluate(() => __pal.showPage('solo')); await q.screenshot({ path: __dirname + '/out/lobby_phone.png' }); await q.close();
  // 6. online: the host's map and size reach the guest in the lobby and in the run, with the same ground
  const H = await open({ width: 1280, height: 800 }), G = await open({ width: 390, height: 844 }, true);
  await H.click('[data-nav=multi]'); await H.click('[data-mmap=quarry]'); await H.click('#mSizeSeg [data-size=std]'); await H.click('#hostBtn');
  await H.waitForFunction(() => /^[A-Z0-9]{4}$/.test(document.getElementById('lCode').textContent), null, { timeout: 15000 });
  const code = await H.textContent('#lCode');
  await G.click('[data-nav=multi]'); await G.fill('#mCode', code); await G.click('#joinBtn'); await G.waitForSelector('#pg-lobby:not([hidden])', { timeout: 15000 }); await G.waitForTimeout(600);
  out.guestLobby = await G.evaluate(() => ({ map: __pal.pick.map, size: __pal.pick.size, note: document.getElementById('lNote').textContent, sub: document.getElementById('partySubtitle').textContent }));
  assert.equal(out.guestLobby.map, 'quarry'); assert.match(out.guestLobby.note, /ASHFALL QUARRY/);
  assert.equal(await G.evaluate(() => { __pal.showPage('solo'); return document.getElementById('menu').dataset.page }), 'lobby', 'in a room, PLAY means the room');
  await H.click('#lStart'); await G.waitForFunction(() => document.getElementById('menu').hidden, null, { timeout: 8000 }); await H.waitForTimeout(800);
  const sig = x => x.evaluate(() => ({ map: __pal.game.map, N: __pal.N, terr: [...__pal.terr].join(''), nodes: __pal.game.lay ? __pal.game.lay.nodes.length : 0 }));
  const hs = await sig(H), gs = await sig(G);
  assert.equal(gs.map, 'quarry'); assert.equal(gs.N, hs.N); assert.equal(gs.terr, hs.terr, 'same ground on both');
  out.online = { map: gs.map, N: gs.N, sameGround: gs.terr === hs.terr };
  console.log(JSON.stringify(out, null, 1));
  console.log('errors:', errors.length ? errors : 'none');
  await b.close();
})().catch(e => { console.log('Error:', e.message); process.exit(1) });
