// v0.9.0/v0.9.1 lobby: navigation (SOLO), the shared map panel in every mode, backgrounds, starting a run, phone
// layout, the Friends dropdown, the full party on the stage, a job change in the room, and the host's map reaching a guest.
// node lobby.js
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
  await p.click('[data-nav=locker]'); await p.click('[data-nav=solo]'); assert.equal(await page(p), 'solo', 'from the Locker back to SOLO');
  assert.equal(await p.textContent('[data-nav=solo]'), 'SOLO', 'the PLAY nav item is now SOLO');
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
  // Settings still opens from the pause menu over the running game, and DONE goes back to the pause menu
  await p.keyboard.press('Escape'); await p.click('#pSetBtn');
  out.pauseSettings = await p.evaluate(() => ({ page: document.getElementById('menu').dataset.page, menu: !document.getElementById('menu').hidden, cards: document.querySelectorAll('#pg-settings .setCard').length, running: __pal.game.phase !== 'over' }));
  assert.deepEqual(out.pauseSettings, { page: 'settings', menu: true, cards: 5, running: true });   // v0.9.2.1: + the controller card
  await p.click('#sDone'); assert.equal(await p.evaluate(() => !document.getElementById('pause').hidden && document.getElementById('menu').hidden), true, 'back to the pause menu');
  await p.click('#resumeBtn');
  await p.evaluate(() => __pal.toMenu()); await p.waitForTimeout(300);
  out.back = await p.evaluate(() => ({ page: document.getElementById('menu').dataset.page, bg: document.getElementById('lobbyBg').hidden, demoMap: __pal.game.map, N: __pal.N }));
  assert.deepEqual(out.back, { page: 'solo', bg: false, demoMap: 'yard', N: 16 }, 'menu again, the demo yard is 16x16');
  // 4. backgrounds: an old save with the removed live-yard choice falls back to a real background
  await p.evaluate(() => { __pal.locker.eq.bg = 'yard'; __pal.showPage('solo') }); assert.equal(await p.evaluate(() => document.getElementById('lobbyBg').hidden), false, 'always a background');
  await p.evaluate(() => { __pal.locker.eq.bg = 'campfire'; __pal.showPage('solo') });
  await p.click('[data-nav=locker]'); await p.click('#lockTabs [data-cat=bg]'); await p.waitForTimeout(200);
  // since v0.9.3.3 case collections start collapsed and build their tiles when opened
  await p.evaluate(() => { for (const b of document.querySelectorAll('#lockGrid [id^=collection-bg-]')) if (b.getAttribute('aria-expanded') !== 'true') b.click() }); await p.waitForTimeout(200);
  out.bgTab = await p.evaluate(() => ({ tiles: document.querySelectorAll('#lockGrid .item').length, owned: document.querySelectorAll('#lockGrid .item:not(.lock)').length }));
  assert.ok(out.bgTab.tiles >= 25 && out.bgTab.owned >= 2, 'background tiles');
  await p.locator('#lockGrid .item:not(.lock)').nth(1).click(); out.equipped = await p.evaluate(() => __pal.locker.eq.bg);
  await p.screenshot({ path: __dirname + '/out/lobby_desk.png' });
  // 4b. the map panel is in the right column on MULTIPLAYER for every mode; PvP hides the XL size
  await p.click('[data-nav=multi]');
  for (const pv of ['coop', 'base', 'ffa']) { await p.click(`[data-pv=${pv}]`); await p.waitForTimeout(120);
    const o = await p.evaluate(() => ({ panel: getComputedStyle(document.getElementById('mapPanel')).display, cards: document.querySelectorAll('#mapCards .mapCard').length, size: !document.getElementById('sizeBox').hidden, note: !document.getElementById('pvpSizeNote').hidden, tag: document.getElementById('mapSizeTag').textContent }));
    assert.notEqual(o.panel, 'none', 'map panel on multi/' + pv); assert.equal(o.cards, 3);
    assert.equal(o.size, pv === 'coop', 'size choice only in co-op'); assert.equal(o.note, pv !== 'coop'); if (pv !== 'coop') assert.equal(o.tag, '16×16') }
  await p.click('.mapCard[data-map=river]'); assert.equal(await p.evaluate(() => __pal.pick.map), 'river', 'PvP picks a map too');
  await p.click('[data-pv=coop]');
  // 4c. the Friends dropdown on the account badge: opens, tabs, closes on Escape
  await p.click('#friendsBtn'); assert.equal(await p.evaluate(() => document.getElementById('friendsDrop').hidden), false);
  await p.click('[data-ft=requests]'); assert.equal(await p.evaluate(() => document.querySelector('[data-fp=requests]').hidden), false);
  await p.keyboard.press('Escape'); assert.equal(await p.evaluate(() => document.getElementById('friendsDrop').hidden), true, 'Escape closes it');
  // 4d. the full party on the stage: six in the room, five of them behind you with name plates
  out.party = await p.evaluate(async () => { const P = __pal; P.NET.mode = 'host'; P.NET.code = 'TEST';
    P.NET.roster = [{ id: P.player.id, name: 'Me', cls: 'soldier', cos: 'std|class|std|none' }, ...[1, 2, 3, 4, 5].map(n => ({ id: 'g' + n, name: 'G' + n, cls: ['sniper', 'grenadier', 'quartermaster', 'soldier', 'sniper'][n - 1], cos: 'std|class|std|none' }))];
    const keep = P.NET.roster[0].id; P.showPage('lobby'); await new Promise(r => setTimeout(r, 300));
    const cv = document.getElementById('partyPreview'), x = cv.getContext('2d'), d = x.getImageData(0, 0, cv.width, cv.height).data; let lit = 0; for (let i = 3; i < d.length; i += 4 * 16) if (d[i] > 30) lit++;
    const slots = document.querySelectorAll('.partySlot.occupied').length; P.NET.mode = 'solo'; P.NET.roster = []; P.NET.code = ''; P.showPage('solo'); return { lit, slots } });
  assert.ok(out.party.lit > 3000, 'the party is painted on the stage'); assert.equal(out.party.slots, 6);
  await p.close();
  // 5. phone: nothing wider than the screen on the lobby pages
  const q = await open({ width: 390, height: 844 }, true);
  for (const nav of ['solo', 'classes', 'multi']) { await q.evaluate(x => __pal.showPage(x), nav); await q.waitForTimeout(150);
    const o = await q.evaluate(() => ({ sw: document.querySelector('#menu .panel').scrollWidth, cw: document.querySelector('#menu .panel').clientWidth }));
    assert.ok(o.sw <= o.cw + 1, 'phone overflow on ' + nav + ' ' + JSON.stringify(o)) }
  await q.evaluate(() => __pal.showPage('solo')); await q.screenshot({ path: __dirname + '/out/lobby_phone.png' }); await q.close();
  // 6. online: the host's map and size reach the guest in the lobby and in the run, with the same ground
  const H = await open({ width: 1280, height: 800 }), G = await open({ width: 390, height: 844 }, true);
  await H.click('[data-nav=multi]'); await H.click('[data-mmap=quarry]'); await H.click('#sizeSeg [data-size=std]'); await H.click('#hostBtn');
  await H.waitForFunction(() => /^[A-Z0-9]{4}$/.test(document.getElementById('lCode').textContent), null, { timeout: 15000 });
  const code = await H.textContent('#lCode');
  await G.click('[data-nav=multi]'); await G.fill('#mCode', code); await G.click('#joinBtn'); await G.waitForSelector('#pg-lobby:not([hidden])', { timeout: 15000 }); await G.waitForTimeout(600);
  out.guestLobby = await G.evaluate(() => ({ map: __pal.pick.map, size: __pal.pick.size, note: document.getElementById('lNote').textContent, sub: document.getElementById('partySubtitle').textContent }));
  assert.equal(out.guestLobby.map, 'quarry'); assert.match(out.guestLobby.note, /ASHFALL QUARRY/);
  assert.equal(await G.evaluate(() => { __pal.showPage('solo'); return document.getElementById('menu').dataset.page }), 'lobby', 'in a room, PLAY means the room');
  await G.click('#lJobs [data-lc=grenadier]'); await H.waitForFunction(() => __pal.NET.roster.some(r => r.id !== __pal.player.id && r.cls === 'grenadier'), null, { timeout: 5000 });
  out.roomJob = 'grenadier';
  await H.click('#lStart'); await G.waitForFunction(() => document.getElementById('menu').hidden, null, { timeout: 8000 }); await H.waitForTimeout(800);
  const sig = x => x.evaluate(() => ({ map: __pal.game.map, N: __pal.N, terr: [...__pal.terr].join(''), nodes: __pal.game.lay ? __pal.game.lay.nodes.length : 0 }));
  const hs = await sig(H), gs = await sig(G);
  assert.equal(gs.map, 'quarry'); assert.equal(gs.N, hs.N); assert.equal(gs.terr, hs.terr, 'same ground on both');
  out.online = { map: gs.map, N: gs.N, sameGround: gs.terr === hs.terr };
  console.log(JSON.stringify(out, null, 1));
  console.log('errors:', errors.length ? errors : 'none');
  await b.close();
})().catch(e => { console.log('Error:', e.message); process.exit(1) });
