// v0.9.2.1 controller: a fake controller drives the menus (highlight, pages, tabs, sliders, toggles, button changes),
// then a raid (move, aim, trigger, grenade, build keys, pause card, armory), then hands back to mouse, keys and touch.
// node controller.js
const { chromium } = require('playwright'), { ready, frames } = require('./lib');
const assert = require('assert');
const PORT = process.env.PORT || 8080;
// the fake controller: the page reads it through navigator.getGamepads like a real one
const FAKE = (id) => {
  const mk = () => ({ id, index: 0, connected: true, mapping: 'standard', timestamp: 0, axes: [0, 0, 0, 0],
    buttons: Array.from({ length: 17 }, () => ({ pressed: false, value: 0, touched: false })),
    vibrationActuator: { effects: [], playEffect(t, o) { this.effects.push([t, o]); return Promise.resolve('complete') } } });
  window.__fakePad = mk(); window.__padOn = true;
  navigator.getGamepads = () => [window.__padOn ? window.__fakePad : null, null, null, null];
};
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--disable-features=WebRtcHideLocalIpsWithMdns'] });
  const errors = [], out = {};
  const open = async (vp, mobile, id, nopad) => {
    const p = await b.newPage({ viewport: vp, isMobile: !!mobile, hasTouch: !!mobile }); p.on('pageerror', e => errors.push(e.message));
    if (!nopad) await p.addInitScript(FAKE, id || 'Xbox Wireless Controller (STANDARD GAMEPAD Vendor: 045e Product: 0b13)');
    await p.goto(`http://localhost:${PORT}/debug.html?peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1`); await ready(p);
    if (!nopad) await p.waitForFunction(() => __pal.pad.idx >= 0, null, { timeout: 5000 });   // with no controller seen yet the game looks once a second
    return p;
  };
  const press = async (p, i, hold = 70) => { await p.evaluate(i => { const b = __fakePad.buttons[i]; b.pressed = true; b.value = 1 }, i); await p.waitForTimeout(hold);
    await p.evaluate(i => { const b = __fakePad.buttons[i]; b.pressed = false; b.value = 0 }, i); await p.waitForTimeout(70) };
  const hold = (p, i, on) => p.evaluate(([i, on]) => { const b = __fakePad.buttons[i]; b.pressed = on; b.value = on ? 1 : 0 }, [i, on]);
  const axes = (p, a) => p.evaluate(a => { __fakePad.axes = a }, a);
  const S = p => p.evaluate(() => ({ mode: __pal.padMode, touch: __pal.touchMode, page: document.getElementById('menu').dataset.page,
    focus: __pal.padFocus ? (__pal.padFocus.id || __pal.padFocus.dataset.nav || __pal.padFocus.dataset.pa || __pal.padFocus.textContent.trim().slice(0, 24)) : null,
    bodyPad: document.body.classList.contains('pad'), hint: !document.getElementById('padHint').hidden && getComputedStyle(document.getElementById('padHint')).display !== 'none' }));
  const focusOn = (p, sel) => p.evaluate(sel => __pal.padFocusEl(document.querySelector(sel)), sel);

  // 1. desktop menus
  const p = await open({ width: 1440, height: 900 });
  let s = await S(p); assert.equal(s.mode, false, 'no controller mode until it is used');
  await press(p, 0); s = await S(p); out.firstPress = s;
  assert.equal(s.mode, true, 'a button press switches to the controller'); assert.ok(s.bodyPad && s.focus, 'something is highlighted'); assert.ok(s.hint, 'menu hint bar shows');
  // move the highlight around; it never leaves the menu
  const seen = new Set([s.focus]);
  for (const d of [15, 15, 13, 13, 14, 12, 13, 15]) { await press(p, d); s = await S(p); seen.add(s.focus);
    assert.ok(await p.evaluate(() => document.getElementById('menu').contains(__pal.padFocus)), 'focus stays in the menu') }
  out.walked = [...seen]; assert.ok(seen.size >= 4, 'the d-pad reaches several buttons');
  // held stick keeps moving
  await focusOn(p, '[data-nav=solo]'); await axes(p, [0, 1, 0, 0]); await p.waitForTimeout(900); await axes(p, [0, 0, 0, 0]); await p.waitForTimeout(60);
  s = await S(p); out.stickHold = s.focus; assert.notEqual(s.focus, 'solo', 'holding the stick moves the highlight');
  // bumpers: pages
  await press(p, 5); out.rb1 = (await S(p)).page; assert.equal(out.rb1, 'multi', 'RB goes to the next page');
  await press(p, 4); assert.equal((await S(p)).page, 'solo', 'LB goes back');
  // locker: triggers switch category tabs
  await p.click('[data-nav=locker]'); await press(p, 0); await p.waitForTimeout(100);
  const cat0 = await p.evaluate(() => document.querySelector('#lockTabs .sel').dataset.cat);
  await press(p, 7); const cat1 = await p.evaluate(() => document.querySelector('#lockTabs .sel').dataset.cat);
  await press(p, 6); const cat2 = await p.evaluate(() => document.querySelector('#lockTabs .sel').dataset.cat);
  out.lockerTabs = [cat0, cat1, cat2]; assert.notEqual(cat0, cat1, 'RT changes locker tab'); assert.equal(cat0, cat2, 'LT goes back');
  // settings: slider, toggle (with rumble), button changes
  await p.click('[data-nav=settings]'); await press(p, 0);
  out.padRows = await p.evaluate(() => document.querySelectorAll('#padMap [data-pa]').length); assert.equal(out.padRows, 12, 'every action listed');
  out.status = await p.textContent('#padStatus'); assert.ok(/connected/i.test(out.status), 'settings sees the controller');
  await focusOn(p, '#sVol'); const v0 = await p.evaluate(() => +document.getElementById('sVol').value);
  await press(p, 15); const v1 = await p.evaluate(() => +document.getElementById('sVol').value); await press(p, 14);
  out.vol = [v0, v1]; assert.equal(v1, Math.min(100, v0 + 5), 'right on a slider turns it up');
  await focusOn(p, 'label.tog:has(#sHap)'); const h0 = await p.evaluate(() => document.getElementById('sHap').checked);
  await press(p, 0); await press(p, 0);
  out.hap = [h0, await p.evaluate(() => document.getElementById('sHap').checked)]; assert.equal(out.hap[1], h0, 'A toggles a checkbox (twice = back)');
  out.rumble = await p.evaluate(() => __fakePad.vibrationActuator.effects.length); assert.ok(out.rumble >= 1, 'turning Vibration on rumbles the controller');
  // change RELOAD to LB, then GRENADE to RT (which FIRE has, so they swap)
  await focusOn(p, '[data-pa=reload]'); await press(p, 0); await p.waitForTimeout(60);
  assert.ok(/PRESS/.test(await p.textContent('[data-pa=reload] kbd')), 'row waits for a button');
  await press(p, 4); out.reload = await p.evaluate(() => __pal.padMap.reload); assert.equal(out.reload, 4, 'reload now on LB');
  assert.equal((await S(p)).focus, 'reload', 'highlight stays on the row');
  await focusOn(p, '[data-pa=nade]'); await press(p, 0); await press(p, 7);
  out.swap = await p.evaluate(() => ({ nade: __pal.padMap.nade, fire: __pal.padMap.fire, saved: JSON.parse(localStorage.getItem('palisade.pad.v1')).map }));
  assert.equal(out.swap.nade, 7); assert.equal(out.swap.fire, 6, 'the button already in use swaps over'); assert.equal(out.swap.saved.nade, 7, 'saved');
  // MENU cancels a change
  await focusOn(p, '[data-pa=build]'); await press(p, 0); await press(p, 9); assert.equal(await p.evaluate(() => __pal.padMap.build), 0, 'MENU cancels');
  await p.click('#padReset'); await press(p, 12);   // the click hands back to the mouse; a press takes over again
  out.reset = await p.evaluate(() => ({ nade: __pal.padMap.nade, fire: __pal.padMap.fire, reload: __pal.padMap.reload })); assert.deepEqual(out.reset, { nade: 6, fire: 7, reload: -1 });
  // B leaves settings
  await press(p, 1); assert.equal((await S(p)).page, 'solo', 'B backs out of settings');

  // 2. a raid
  await p.click('[data-setup=job]:visible'); await p.click('#setupSheet [data-c=soldier]'); await p.click('#setupDone'); await press(p, 12);
  await focusOn(p, '#startBtn'); await press(p, 0); await p.waitForFunction(() => document.getElementById('menu').hidden, null, { timeout: 5000 }); await frames(p, 3);
  const st = () => p.evaluate(() => { const q = __pal.player; return { phase: __pal.game.phase, x: q.x, y: q.y, aim: q.aim, fire: q.fireIn, auto: q.autoFire, sel: __pal.game.sel, piece: __pal.game.piece,
    build: __pal.cfg ? __pal.cfg.build : null, paused: __pal.game.paused, keys: document.getElementById('keys').textContent } });
  let g = await st(); out.start = g; assert.equal(g.phase, 'build', 'A on START starts the run'); assert.ok(/RT/.test(g.keys) && /fire/.test(g.keys) && !/MOUSE/.test(g.keys), 'key bar shows controller buttons');
  assert.equal((await S(p)).hint, false, 'no menu hint during play');
  await axes(p, [1, 0, 0, 0]); await p.waitForTimeout(700); await axes(p, [0, 0, 0, 0]);
  let g2 = await st(); out.moved = Math.hypot(g2.x - g.x, g2.y - g.y); assert.ok(out.moved > .8, 'left stick moves');
  await axes(p, [0, 0, 0, -1]); await p.waitForTimeout(150); g = await st(); out.aimUp = g.aim;
  await axes(p, [0, 0, 1, 0]); await p.waitForTimeout(150); g2 = await st(); out.aimRight = g2.aim;
  assert.ok(Math.abs(g.aim.x - g2.aim.x) + Math.abs(g.aim.y - g2.aim.y) > .5, 'right stick aims');
  await hold(p, 7, true); await p.waitForTimeout(150); g = await st(); await hold(p, 7, false); await axes(p, [0, 0, 0, 0]);
  assert.equal(g.fire, true, 'RT fires'); assert.equal(g.auto, false, 'the trigger works like a mouse button (one pull per press)');
  await p.waitForTimeout(80); assert.equal((await st()).fire, false, 'letting go stops');
  const sel0 = (await st()).sel; await press(p, 15); assert.equal((await st()).sel, (sel0 + 1) % 3, 'd-pad right: next material');
  await press(p, 14); assert.equal((await st()).sel, sel0, 'd-pad left: back');
  const pc0 = (await st()).piece; await press(p, 3); assert.notEqual((await st()).piece, pc0, 'Y: wall/door'); await press(p, 3);
  const nd = () => p.evaluate(() => { const q = __pal.player; return q.nades !== undefined ? q.nades : q.nd });
  const n0 = await nd(); await press(p, 6); await p.waitForTimeout(100); out.nades = [n0, await nd()]; assert.ok(out.nades[1] < n0 || out.nades[1] === undefined, 'LT throws a grenade');
  // pause with MENU: controller card, then B resumes
  await press(p, 9); g = await st(); assert.equal(g.paused, true, 'MENU pauses');
  out.card = await p.evaluate(() => ({ shown: !document.getElementById('padCard').hidden, text: document.getElementById('padCard').textContent }));
  assert.ok(out.card.shown && /RT/.test(out.card.text) && /GRENADE/.test(out.card.text), 'pause shows the controller card');
  assert.ok(await p.evaluate(() => document.getElementById('pause').contains(__pal.padFocus)), 'highlight is in the pause menu');
  await press(p, 1); assert.equal((await st()).paused, false, 'B resumes');
  // armory with X (the player starts at the stake in the build phase)
  await p.evaluate(([x, y]) => { __pal.player.x = x; __pal.player.y = y }, [out.start.x, out.start.y]);   // back to the stake the run started at
  await p.evaluate(() => { __pal.player.sal = 900 });
  await press(p, 2); await p.waitForTimeout(100); out.armory = await p.evaluate(() => !document.getElementById('armory').hidden);
  // buy two upgrades with A: the highlight stays on the same row after the screen redraws
  out.buy = await p.evaluate(() => ({ before: JSON.stringify(__pal.player.up), sal: __pal.player.sal, f: __pal.padFocus && __pal.padFocus.getAttribute('aria-label') }));
  await press(p, 0); await p.waitForTimeout(80); await press(p, 0); await p.waitForTimeout(80);
  Object.assign(out.buy, await p.evaluate(() => ({ after: JSON.stringify(__pal.player.up), sal2: __pal.player.sal, f2: __pal.padFocus && __pal.padFocus.getAttribute('aria-label'), inArm: document.getElementById('armory').contains(__pal.padFocus) })));
  assert.ok(out.buy.sal2 < out.buy.sal && out.buy.after !== out.buy.before, 'A buys an upgrade'); assert.ok(out.buy.inArm && out.buy.f2 && out.buy.f2.split(' level')[0] === out.buy.f.split(' level')[0], 'highlight stays on the row');
  assert.ok(out.armory, 'X opens the armory at the stake');
  { out.armHint = await p.textContent('#armory .armHint'); assert.ok(/X or B/.test(out.armHint)); await press(p, 1); assert.equal(await p.evaluate(() => document.getElementById('armory').hidden), true, 'B closes the armory') }
  // hand back: the mouse takes over, then the keyboard, then the controller again
  await p.mouse.move(300, 300); await p.mouse.move(700, 500, { steps: 4 }); s = await S(p); assert.equal(s.mode, false, 'moving the mouse hands back');
  g = await st(); assert.ok(/MOUSE/.test(g.keys), 'key bar back to keys');
  await axes(p, [0, 0, 1, 0]); await p.waitForTimeout(100); await axes(p, [0, 0, 0, 0]); assert.equal((await S(p)).mode, true, 'the controller takes over again');
  await p.keyboard.press('d'); assert.equal((await S(p)).mode, false, 'a key hands back');
  // unplugging
  await press(p, 0); await p.evaluate(() => { __padOn = false; dispatchEvent(new Event('gamepaddisconnected')) }); await p.waitForTimeout(100);
  out.unplugged = await S(p); assert.equal(out.unplugged.mode, false, 'unplugging hands back');
  await p.close();

  // 3. phone with a PlayStation controller: touch controls hide, touching the screen brings them back
  const m = await open({ width: 390, height: 844 }, true, 'DualSense Wireless Controller (STANDARD GAMEPAD Vendor: 054c Product: 0ce6)');
  assert.equal((await S(m)).touch, true);
  await press(m, 0); s = await S(m); out.phone = s; assert.equal(s.touch, false, 'the controller turns touch mode off'); assert.equal(s.mode, true);
  out.phoneHint = await m.textContent('#padHint'); assert.ok(/✕/.test(out.phoneHint) && /○/.test(out.phoneHint), 'PlayStation symbols');
  await m.touchscreen.tap(200, 400); s = await S(m); assert.equal(s.mode, false); assert.equal(s.touch, true, 'a touch brings touch mode back');
  await m.close();

  // 4. online: a guest on a controller. The host sees their aim and trigger; nothing new goes over the network.
  const H = await open({ width: 1280, height: 720 }, false, null, true), G = await open({ width: 1280, height: 720 });
  await H.click('[data-go=multi]'); await H.fill('#mName', 'Host'); await H.click('#hostBtn');
  await H.waitForSelector('#pg-lobby:not([hidden])', { timeout: 10000 }); const code = await H.textContent('#lCode');
  await G.click('[data-go=multi]'); await G.fill('#mName', 'Pad'); await G.fill('#mCode', code); await G.click('#joinBtn');
  await G.waitForSelector('#pg-lobby:not([hidden])', { timeout: 10000 }); await H.waitForTimeout(600);
  await H.evaluate(()=>__pal.lobbyReadyAll());await H.click('#lStart'); await G.waitForFunction(() => document.getElementById('menu').hidden, null, { timeout: 8000 }); await H.waitForTimeout(800);
  await G.evaluate(() => { const f = __pal.NET.toHost.bind(__pal.NET); window.__sent = []; __pal.NET.toHost = (m, c) => { if (m.t === 'i') window.__sent.push(Object.keys(m).sort().join(',') + '|a' + m.a + '|f' + m.f); return f(m, c) } });
  await press(G, 12); await axes(G, [0, 0, -1, 0]); await hold(G, 7, true); await G.waitForTimeout(600);
  out.online = await H.evaluate(() => { const g = [...__pal.players.values()].find(p => p.id !== __pal.player.id); return { fire: g.fireIn, aim: g.aim, auto: g.autoFire } });
  await hold(G, 7, false); await axes(G, [0, 0, 0, 0]);
  out.sent = await G.evaluate(() => [...new Set(window.__sent)].slice(-3));
  assert.equal(out.online.fire, true, 'the host sees the guest pulling the trigger'); assert.ok(out.online.aim.x < -.5, 'the host sees the guest aiming left');
  assert.ok(out.sent.some(x => x.startsWith('a,ax,ay,f,n,t,tp,x,y|a0|f1')), 'same message fields as before, trigger mode');
  await H.close(); await G.close();

  console.log(JSON.stringify(out, null, 1));
  console.log('errors:', errors.length ? errors : 'none');
  await b.close();
})().catch(e => { console.log('FAILED', e.message); process.exit(1) });
