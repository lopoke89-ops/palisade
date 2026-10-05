// v0.9.2 rejoin: a guest with an account leaves a co-op run after raid 3 and comes back. The first claim covers raids
// 1-3 (marked as left early), the second only raids 4-5, both with the host's game id, and each boss is paid once.
// Also: a guest who comes in late only claims from the raid they came in on. node rejoin.js
const { chromium } = require('playwright'), assert = require('node:assert/strict'), { ready, frames, synced } = require('./lib');
const Q = 'peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1', PORT = process.env.PORT || 8080;
const A = 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa';
const token = id => Buffer.from('{}').toString('base64url') + '.' + Buffer.from(JSON.stringify({ sub: id, is_anonymous: false })).toString('base64url') + '.test';
const session = id => ({ access_token: token(id), refresh_token: 'fixture', expires_at: Math.floor(Date.now() / 1000) + 3600, user: { id, email: 'a@example.invalid', is_anonymous: false, user_metadata: { pw: true } } });
const L = { owned: ['skin:std', 'hat:class', 'hat:cap', 'trail:std', 'fx:none'], eq: { skin: 'std', hat: 'class', trail: 'std', fx: 'none' }, cases: 0, bag: {}, shards: 0, prog: 0, st: { raids: 0, wins: 0, drops: 0, endless: 0, hardWins: 0 }, imported: true, sp: 0, skills: {} };
const claims = [];
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--disable-features=WebRtcHideLocalIpsWithMdns'] });
  const errors = [], out = {}; process.on('exit', () => console.log('OUT', JSON.stringify(out)));
  const H = await b.newPage({ viewport: { width: 1100, height: 760 } }); H.on('pageerror', e => errors.push('H ' + e.message));
  await H.goto(`http://localhost:${PORT}/debug.html?${Q}`); await ready(H);
  const gctx = await b.newContext({ viewport: { width: 900, height: 700 } });
  await gctx.route('https://puvjfhwxigxjpsvdwrwf.supabase.co/**', async route => {
    const req = route.request(), path = new URL(req.url()).pathname; let data = {}, status = 200;
    if (path === '/auth/v1/user') data = session(A).user;
    else if (path === '/rest/v1/profiles') data = [{ id: A, username: 'Rejoiner', cos: '' }];
    else if (path === '/rest/v1/lobbies') data = [];
    else if (path === '/rest/v1/rpc/get_my_locker') data = L;
    else if (path === '/rest/v1/rpc/claim_match_reward') { claims.push(req.postDataJSON().p); data = { cases: { supply: 1 }, shards: 0, unlocked_ids: [], to_next: 2, skill_points: 0, locker: L } }
    else if (path === '/rest/v1/rpc/social_state') data = { friends: [], incoming: [], outgoing: [], notes: [], unseen: 0 };
    else { status = 404; data = { message: 'unhandled' } }
    await route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(data) }) });
  const G = await gctx.newPage(); G.on('pageerror', e => errors.push('G ' + e.message));
  await G.addInitScript(s => localStorage.setItem('palisade.auth.v1', JSON.stringify(s)), session(A));
  await G.goto(`http://localhost:${PORT}/debug.html?${Q}&cloud=1`); await G.waitForFunction(() => __pal.acct.state === 'full' && !!__pal.locker.cloud, null, { timeout: 15000 });
  await H.click('[data-nav=multi]'); await H.click('#hostBtn');
  await H.waitForFunction(() => /^[A-Z0-9]{4}$/.test(document.getElementById('lCode').textContent), null, { timeout: 15000 });
  const code = await H.textContent('#lCode');
  const join = async () => { await G.click('[data-nav=multi]'); await G.fill('#mCode', code); await G.click('#joinBtn'); await G.waitForFunction(() => __pal.NET.inGame || !document.getElementById('pg-lobby').hidden, null, { timeout: 15000 }) };
  await join(); await H.evaluate(()=>__pal.lobbyReadyAll());await H.click('#lStart'); await G.waitForFunction(() => document.getElementById('menu').hidden, null, { timeout: 8000 }); await synced(H, G);
  await H.evaluate(() => { const P = __pal; window.holdIt = setInterval(() => { for (const q of P.players.values()) { q.max = 1e9; q.hp = 1e9 } P.core.max = 1e9; P.core.hp = 1e9; P.qm.hp = 1e9 }, 50) });
  const gid = await H.evaluate(() => __pal.game.gid);
  // on the way: the guest's soldier fires a rocket; the host runs it and the count comes back
  await G.evaluate(() => { const P = __pal; P.setMouse(700, 300, false); P.localAbility() }); await H.waitForTimeout(500);
  out.rocket = { host: await H.evaluate(() => { const p = [...__pal.players.values()].find(p => p.id !== 'host'); return [p.rk, p.cls] }), guestHud: await G.evaluate(() => [__pal.player.ab, document.getElementById('abN').textContent]) };
  assert.deepEqual(out.rocket.host, [4, 'soldier']); assert.deepEqual(out.rocket.guestHud, [4, '4']);
  // raids 1-3 are held (the host jumps ahead), then the guest walks out during the build phase
  await H.evaluate(() => { const P = __pal; P.game.wave = 3; P.game.phase = 'build'; P.game.timer = 999; P.game.time = 400 }); await H.waitForTimeout(700);
  out.guestBase1 = await G.evaluate(() => [__pal.game.joinHeld, __pal.game.gid]);
  await G.evaluate(() => { const b = document.getElementById('quitBtn'); b.click() });
  await G.waitForFunction(() => __pal.NET.mode === 'solo', null, { timeout: 5000 });
  await G.waitForFunction(() => __pal.claims.length === 0, null, { timeout: 8000 }); await G.waitForTimeout(300);
  assert.equal(claims.length, 1, 'leaving claims once');
  // raid 4 starts while they're gone; they come back during it
  await H.evaluate(() => { const P = __pal; P.game.timer = .1 }); await H.waitForTimeout(600);
  await join(); await G.waitForFunction(() => __pal.NET.inGame && __pal.game.joinHeld != null, null, { timeout: 10000 });
  out.guestBase2 = await G.evaluate(() => [__pal.game.joinHeld, __pal.game.gid, __pal.game.wave, __pal.game.phase]);
  // raid 5 with its boss, then the win
  await H.evaluate(() => { const P = __pal; P.game.queue = []; for (const e of P.enemies) e.dead = true; P.game.wave = 4; P.game.phase = 'build'; P.startRaid(); P.game.queue = [];
    const e = P.enemies.find(e => e.type === 'boss') || (P.spawnBoss('demolisher'), P.enemies.find(e => e.type === 'boss')); P.hurtEnemyHook(e, 1e8, P.player.id); P.game.time = 800 });
  await H.waitForTimeout(700);
  await H.evaluate(() => { const P = __pal; P.game.queue = []; for (const e of P.enemies) e.dead = true });
  await G.waitForFunction(() => __pal.game.phase === 'over', null, { timeout: 10000 });
  await G.waitForFunction(() => __pal.claims.length === 0, null, { timeout: 8000 }); await G.waitForTimeout(300);
  assert.equal(claims.length, 2);
  const pick = c => ({ gid: c.game_id === gid, from: c.raid_from, to: c.raid_to, held: c.held, left: c.left, win: c.win, bosses: c.boss_keys, dur: c.duration_s > 0 });
  out.first = pick(claims[0]); out.second = pick(claims[1]);
  assert.deepEqual(out.guestBase1, [0, gid]);
  assert.equal(out.guestBase2[0], 3); assert.equal(out.guestBase2[1], gid);
  assert.deepEqual(out.first, { gid: true, from: 0, to: 3, held: 3, left: true, win: false, bosses: [], dur: true });
  assert.deepEqual(out.second, { gid: true, from: 3, to: 5, held: 2, left: false, win: true, bosses: ['demolisher'], dur: true });
  out.upgrades = claims[0].upgrades; assert.match(out.upgrades, /^\d{5}:\d$/);
  // v0.9.3: every claim says which class the player ended as and which map it was (the milestone counters need both)
  out.clsMap = claims.map(c => c.cls + '@' + c.map); for (const c of claims) { assert.ok(['soldier', 'sniper', 'grenadier', 'quartermaster'].includes(c.cls)); assert.ok(['yard', 'river', 'quarry'].includes(c.map)) }
  await G.screenshot({ path: __dirname + '/out/rejoin_over.png' });
  console.log(JSON.stringify(out)); console.log('errors:', errors.length ? errors : 'none'); assert.equal(errors.length, 0); await b.close();
})().catch(e => { console.log('Error:', e.message, (e.stack || '').split('\n').find(l => /rejoin.js/.test(l))); process.exit(1) });
