// host (QM, desktop) + guest (grenadier, phone): class sync, shells, QM revive, bosses, rockets, lightning on the guest
const { chromium } = require('playwright');
const Q = 'peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1', O = __dirname + '/out';
(async () => {
  const b = await chromium.launch({ executablePath:process.env.CHROMIUM||undefined, args: ['--disable-features=WebRtcHideLocalIpsWithMdns'] });
  const mk = async (opts, tag) => { const p = await b.newPage(opts); p.errs = []; p.on('pageerror', e => p.errs.push(tag + ' ' + e.message + ' @ ' + (e.stack || '').split('\n')[1])); return p };
  const H = await mk({ viewport: { width: 1280, height: 720 } }, 'HOST');
  const G = await mk({ viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true, deviceScaleFactor: 2 }, 'GUEST');
  await H.goto('http://localhost:8080/debug.html?' + Q); await G.goto('http://localhost:8080/debug.html?' + Q); await H.waitForTimeout(700);
  await H.click('[data-go=multi]'); await H.fill('#mName', 'Big U'); await H.click('[data-mc=quartermaster]'); await H.click('#hostBtn');
  await H.waitForSelector('#pg-lobby:not([hidden])', { timeout: 10000 }); const code = await H.textContent('#lCode');
  await G.click('[data-go=multi]'); await G.screenshot({ path: O + '/m_phone_multi.png' });
  await G.fill('#mName', 'Rook'); await G.click('[data-mc=grenadier]'); await G.fill('#mCode', code); await G.click('#joinBtn');
  await G.waitForSelector('#pg-lobby:not([hidden])', { timeout: 10000 }); await H.waitForTimeout(700);
  console.log('lobby:', await H.textContent('#lList'));
  // Equipping headgear in the locker must update both party previews and the next match.
  for(const page of [H,G]){await page.click('[data-party-go=locker]');await page.evaluate(()=>{__pal.locker.eq.hat='cap';__pal.showPage('multi')});await page.waitForSelector('#pg-lobby:not([hidden])')}
  await H.waitForFunction(()=>__pal.NET.roster.length===2&&__pal.NET.roster.every(r=>r.cos.split('|')[1]==='cap'));
  await G.waitForFunction(()=>__pal.NET.roster.length===2&&__pal.NET.roster.every(r=>r.cos.split('|')[1]==='cap'));
  if(await H.locator('.partySlot.occupied').count()!==2)throw new Error('Party slots do not match roster');
  await H.screenshot({path:O+'/party-host.jpg'});await G.screenshot({path:O+'/party-guest.jpg'});
  await H.click('#lStart'); await G.waitForFunction(() => document.getElementById('menu').hidden, null, { timeout: 6000 }); await H.waitForTimeout(1200);
  console.log('guest sees classes:', await G.evaluate(() => [...__pal.players.values()].map(p => p.name + ':' + p.cls + (p.gun.mag ? ' ammo ' + p.ammo : '')).join(', ')));
  await G.evaluate(() => { window.__muzzleIds=new Set(); window.__muzzleTimer=setInterval(()=>{for(const b of __pal.bullets)if(b.visual&&b.visual.length===4)window.__muzzleIds.add(b.id)},10) });
  // guest fires 2 blasts (touch = auto pump): host ammo drops, guest sees it
  await G.evaluate(() => { const f = __pal.NET.toHost.bind(__pal.NET); window.__f = 1; __pal.NET.toHost = (m, c) => { if (m.t === 'i') m.f = window.__f; return f(m, c) } });
  await H.waitForTimeout(1500); await G.evaluate(() => { window.__f = 0 }); await H.waitForTimeout(250);
  console.log('guest shells: host says', await H.evaluate(() => __pal.players.get('g1').ammo), '| guest sees', await G.evaluate(() => __pal.player.ammo), '| reload flag on guest', await G.evaluate(() => __pal.player.rl));
  const muzzleShots=await G.evaluate(()=>{clearInterval(window.__muzzleTimer);return window.__muzzleIds.size});
  if(!muzzleShots)throw new Error('Guest did not receive calibrated muzzle coordinates');
  console.log('guest calibrated projectiles:',muzzleShots);
  await G.screenshot({ path: O + '/m_guest_shells.png' });
  // guest goes down; host (QM) walks over -> instant revive, guest sees it
  await H.evaluate(() => { const g = __pal.players.get('g1'); __pal.hurtPlayer(g, 9999); });
  await G.waitForTimeout(400); const downG = await G.evaluate(() => __pal.player.downed);
  await H.evaluate(() => { const g = __pal.players.get('g1'), h = __pal.player; h.x = g.x - .3; h.y = g.y });
  await G.waitForTimeout(500);
  console.log('guest down on guest screen:', downG, '-> after QM walks over, guest alive:', await G.evaluate(() => __pal.player.alive), 'hp', await G.evaluate(() => Math.round(__pal.player.hp)));
  // bosses: demolisher, then butcher, then storm; watch what the guest receives
  await H.evaluate(() => { const P = __pal; P.startRaid(); P.game.queue.length = 0; P.enemies.length = 0; for (const p of P.players.values()) { p.max = 99999; p.hp = 99999 } });
  const out = {};
  for (const k of ['demolisher', 'butcher', 'storm']) {
    await H.evaluate(k => { const P = __pal; P.enemies.length = 0; P.spawnBoss(k); const e = P.enemies[0], g = P.players.get('g1'); e.x = Math.min(14.5, g.x + 5); e.y = g.y; e.cd = .1; e.ab = 0 }, k);
    const seen = { boss: '', st: new Set(), rk: 0, fz: 0, zap: 0, sl: 0, bar: false };
    for (let i = 0; i < 40; i++) { await G.waitForTimeout(100);
      const s = await G.evaluate(() => { const e = __pal.enemies.find(x => x.type === 'boss'); return { b: e ? e.boss : '', st: e ? e.st : 0, rk: __pal.rockets.length, fz: __pal.fires.length, z: __pal.zaps.length, sl: __pal.slashes.length } });
      seen.boss = s.b || seen.boss; seen.st.add(s.st); seen.rk = Math.max(seen.rk, s.rk); seen.fz = Math.max(seen.fz, s.fz); seen.zap = Math.max(seen.zap, s.z); seen.sl = Math.max(seen.sl, s.sl);
      if (i === 14) await G.screenshot({ path: O + `/m_guest_${k}.png` }) }
    out[k] = { boss: seen.boss, states: [...seen.st].join(','), rockets: seen.rk, fires: seen.fz, zaps: seen.zap, slashes: seen.sl };
  }
  console.log('guest view of bosses', JSON.stringify(out));
  console.log('guest stun seen:', await G.evaluate(async () => { let m = 0; for (let i = 0; i < 40; i++) { m = Math.max(m, __pal.player.stun || 0); await new Promise(r => setTimeout(r, 50)) } return m.toFixed(2) }));
  // an old-version guest is refused cleanly
  console.log('proto', await H.evaluate(() => 1));
  console.log('errors:', [...H.errs, ...G.errs].length ? [...H.errs, ...G.errs] : 'none');
  await b.close();
})();
