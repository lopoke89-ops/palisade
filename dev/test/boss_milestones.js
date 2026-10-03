// v0.9.3.8: every boss kill counts toward boss milestones for everyone in the match: a guest who never hit the bosses
// still gets the regular boss and the in-between (Boss Rush) boss named in their claim; a no-account solo run adds
// the in-between boss to the local milestone counter too. node boss_milestones.js
const { chromium } = require('playwright'), assert = require('node:assert/strict'), fs = require('node:fs');
const Q = 'peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1', PORT = process.env.PORT || 8080, A = 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa';
const token = id => Buffer.from('{}').toString('base64url') + '.' + Buffer.from(JSON.stringify({ sub: id, is_anonymous: false })).toString('base64url') + '.test';
const session = id => ({ access_token: token(id), refresh_token: 'fixture', expires_at: Math.floor(Date.now() / 1000) + 3600, user: { id, email: 'a@example.invalid', is_anonymous: false, user_metadata: { pw: true } } });
const L = { owned: ['skin:std', 'hat:class', 'hat:cap', 'trail:std', 'fx:none'], eq: { skin: 'std', hat: 'class', trail: 'std', fx: 'none' }, cases: 0, bag: {}, shards: 0, prog: 0, st: { raids: 0, wins: 0, drops: 0, endless: 0, hardWins: 0 }, imported: true, sp: 0, skills: {} };
const claims = [];
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--disable-features=WebRtcHideLocalIpsWithMdns'] }), errors = [], out = {};
  const H = await b.newPage({ viewport: { width: 1000, height: 700 } }); H.on('pageerror', e => errors.push('H ' + e.message));
  await H.addInitScript(() => localStorage.setItem('palisade.cfg.v1', JSON.stringify({ mods: { coop: ['bossrush'] } })));
  await H.goto(`http://localhost:${PORT}/debug.html?${Q}`); await H.waitForFunction(() => window.__pal);
  const gctx = await b.newContext({ viewport: { width: 900, height: 700 } });
  await gctx.route('https://puvjfhwxigxjpsvdwrwf.supabase.co/**', async route => {
    const req = route.request(), path = new URL(req.url()).pathname; let data = {}, status = 200;
    if (path === '/auth/v1/user') data = session(A).user; else if (path === '/rest/v1/profiles') data = [{ id: A, username: 'Guest', cos: '' }];
    else if (path === '/rest/v1/lobbies') data = []; else if (path === '/rest/v1/rpc/get_my_locker') data = L;
    else if (path === '/rest/v1/rpc/claim_match_reward') { claims.push(req.postDataJSON().p); data = { cases: { supply: 1 }, shards: 0, unlocked_ids: [], to_next: 2, skill_points: 0, locker: L } }
    else if (path === '/rest/v1/rpc/social_state') data = { friends: [], incoming: [], outgoing: [], notes: [], unseen: 0 };
    else { status = 404; data = { message: 'unhandled' } }
    await route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(data) }) });
  const G = await gctx.newPage(); G.on('pageerror', e => errors.push('G ' + e.message));
  await G.addInitScript(s => localStorage.setItem('palisade.auth.v1', JSON.stringify(s)), session(A));
  await G.goto(`http://localhost:${PORT}/debug.html?${Q}&cloud=1`); await G.waitForFunction(() => __pal.acct.state === 'full' && !!__pal.locker.cloud, null, { timeout: 15000 });
  await H.click('[data-nav=multi]'); await H.click('#hostBtn'); await H.waitForFunction(() => /^[A-Z0-9]{4}$/.test(document.getElementById('lCode').textContent), null, { timeout: 15000 });
  const code = await H.textContent('#lCode'); await G.click('[data-nav=multi]'); await G.fill('#mCode', code); await G.click('#joinBtn');
  await G.waitForSelector('#pg-lobby:not([hidden])', { timeout: 15000 }); await H.click('#lStart'); await G.waitForFunction(() => __pal.NET.inGame && document.getElementById('menu').hidden, null, { timeout: 10000 }); await H.waitForTimeout(700);
  out.mods = await H.evaluate(() => __pal.game.mods);
  // the host kills a regular boss (raid 5) and a Boss Rush boss (raid 2 style, sb) with its own shots; the guest never fires
  await H.evaluate(() => { const P = __pal; setInterval(() => { for (const q of P.players.values()) { q.max = 1e9; q.hp = 1e9 } P.core.max = 1e9; P.core.hp = 1e9 }, 50);
    P.game.oct = false;   // in October the Butcher is the pumpkin variant ('butcher_oct'); pinned so this passes all year
    P.game.wave = 5; P.game.phase = 'raid'; P.game.queue = []; P.game.time = 600;
    P.spawnBoss('butcher'); P.spawnBoss('demolisher', true); for (const e of P.enemies.filter(e => e.type === 'boss')) P.hurtEnemyHook(e, 1e9, 'host');
    P.game.phase = 'build'; P.game.timer = 999 });
  await G.waitForFunction(() => (__pal.game.sbLog || []).length === 1 && __pal.game.bossLog.length === 1, null, { timeout: 8000 });
  out.guestLogs = await G.evaluate(() => ({ bossLog: __pal.game.bossLog, sbLog: __pal.game.sbLog, sbN: __pal.game.sbN, joinSB: __pal.game.joinSB }));
  await G.click('#pauseBtn').catch(() => {}); await G.evaluate(() => document.getElementById('quitBtn').click());
  await G.waitForFunction(() => __pal.claims.length === 0, null, { timeout: 10000 }); await G.waitForTimeout(200);
  assert.equal(claims.length, 1); out.claim = { boss_keys: claims[0].boss_keys, sb_keys: claims[0].sb_keys, shard_bosses: claims[0].shard_bosses };
  assert.deepEqual(out.claim, { boss_keys: ['butcher'], sb_keys: ['demolisher'], shard_bosses: 1 });
  // no-account solo: the in-between boss adds to the local milestone counter
  const S = await b.newPage({ viewport: { width: 900, height: 700 } }); S.on('pageerror', e => errors.push('S ' + e.message));
  await S.goto(`http://localhost:${PORT}/debug.html?debug=1`); await S.waitForFunction(() => window.__pal);
  out.solo = await S.evaluate(() => { const P = __pal; P.demo = false; P.newGame(null, '', { mods: ['bossrush'] }); P.enterGameHook(); const before = P.locker.st.boss_storm | 0;
    P.game.wave = 2; P.game.phase = 'raid'; P.game.time = 200; P.spawnBoss('storm', true); P.hurtEnemyHook(P.enemies.find(e => e.type === 'boss'), 1e9, P.player.id);
    P.game.phase = 'build'; P.leaveRun(); return { gained: (P.locker.st.boss_storm | 0) - before, sbLog: P.game.sbLog } });
  assert.equal(out.solo.gained, 1);
  fs.writeFileSync(__dirname + '/out/boss_milestones.json', JSON.stringify({ out, errors }, null, 2)); assert.deepEqual(errors, []);
  console.log(JSON.stringify(out)); console.log('errors: none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
