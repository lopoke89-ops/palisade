// v0.9.3.6: a guest with an account whose page reloads mid-run (no clean leave) is still paid for raids 1-3 on the
// next start, and on rejoining the same game the host restores their armory, salvage and kills.
// A no-account solo run that reloads is paid into this browser's locker. node rejoin_drop.js
const { chromium } = require('playwright'), assert = require('node:assert/strict'), fs = require('node:fs');
const Q = 'peerhost=127.0.0.1&peerport=9000&peerpath=/&debug=1', PORT = process.env.PORT || 8080;
const A = 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa';
const token = id => Buffer.from('{}').toString('base64url') + '.' + Buffer.from(JSON.stringify({ sub: id, is_anonymous: false })).toString('base64url') + '.test';
const session = id => ({ access_token: token(id), refresh_token: 'fixture', expires_at: Math.floor(Date.now() / 1000) + 3600, user: { id, email: 'a@example.invalid', is_anonymous: false, user_metadata: { pw: true } } });
const L = { owned: ['skin:std', 'hat:class', 'hat:cap', 'trail:std', 'fx:none'], eq: { skin: 'std', hat: 'class', trail: 'std', fx: 'none' }, cases: 0, bag: {}, shards: 0, prog: 0, st: { raids: 0, wins: 0, drops: 0, endless: 0, hardWins: 0 }, imported: true, sp: 0, skills: {} };
const claims = [];
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined, args: ['--disable-features=WebRtcHideLocalIpsWithMdns'] });
  const errors = [], out = {};
  const H = await b.newPage({ viewport: { width: 1100, height: 760 } }); H.on('pageerror', e => errors.push('H ' + e.message));
  await H.goto(`http://localhost:${PORT}/debug.html?${Q}`); await H.waitForTimeout(800);
  const gctx = await b.newContext({ viewport: { width: 900, height: 700 } });
  await gctx.route('https://puvjfhwxigxjpsvdwrwf.supabase.co/**', async route => {
    const req = route.request(), path = new URL(req.url()).pathname; let data = {}, status = 200;
    if (path === '/auth/v1/user') data = session(A).user;
    else if (path === '/rest/v1/profiles') data = [{ id: A, username: 'Dropper', cos: '' }];
    else if (path === '/rest/v1/lobbies') data = [];
    else if (path === '/rest/v1/rpc/get_my_locker') data = L;
    else if (path === '/rest/v1/rpc/claim_match_reward') { claims.push(req.postDataJSON().p); data = { cases: { supply: 1 }, shards: 0, unlocked_ids: [], to_next: 2, skill_points: 0, locker: L } }
    else if (path === '/rest/v1/rpc/social_state') data = { friends: [], incoming: [], outgoing: [], notes: [], unseen: 0 };
    else { status = 404; data = { message: 'unhandled' } }
    await route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(data) }) });
  const G = await gctx.newPage(); G.on('pageerror', e => errors.push('G ' + e.message));
  await G.addInitScript(s => { if (!localStorage.getItem('palisade.auth.v1')) localStorage.setItem('palisade.auth.v1', JSON.stringify(s)) }, session(A));
  const boot = async () => { await G.goto(`http://localhost:${PORT}/debug.html?${Q}&cloud=1`); await G.waitForFunction(() => __pal.acct.state === 'full' && !!__pal.locker.cloud, null, { timeout: 15000 }) };
  await boot();
  await H.click('[data-nav=multi]'); await H.click('#hostBtn');
  await H.waitForFunction(() => /^[A-Z0-9]{4}$/.test(document.getElementById('lCode').textContent), null, { timeout: 15000 });
  const code = await H.textContent('#lCode');
  const join = async () => { await G.click('[data-nav=multi]'); await G.fill('#mCode', code); await G.click('#joinBtn'); await G.waitForFunction(() => __pal.NET.inGame || !document.getElementById('pg-lobby').hidden, null, { timeout: 15000 }) };
  await join(); await H.evaluate(()=>__pal.lobbyReadyAll());await H.click('#lStart'); await G.waitForFunction(() => document.getElementById('menu').hidden, null, { timeout: 8000 }); await H.waitForTimeout(700);
  await H.evaluate(() => { const P = __pal; window.holdIt = setInterval(() => { for (const q of P.players.values()) { q.max = 1e9; q.hp = 1e9 } P.core.max = 1e9; P.core.hp = 1e9; P.qm.hp = 1e9 }, 50) });
  const gid = await H.evaluate(() => __pal.game.gid);
  // raids 1-3 held; the host gives the guest armory upgrades, salvage and kills
  await H.evaluate(() => { const P = __pal; P.game.wave = 3; P.game.phase = 'build'; P.game.timer = 999; P.game.time = 400;
    const g = [...P.players.values()].find(p => p.id !== 'host'); g.sal = 500; P.buyUpgrade(g, 'd'); P.buyUpgrade(g, 'd'); P.buyUpgrade(g, 'a'); g.kills = 17 });
  const before = await H.evaluate(() => { const g = [...__pal.players.values()].find(p => p.id !== 'host'); return { upS: g.upS, sal: g.sal, kills: g.kills } });
  await G.waitForFunction(() => __pal.game.wave === 3 && __pal.game.phase === 'build', null, { timeout: 5000 });
  await G.waitForFunction(() => !!localStorage.getItem('palisade.runDraft.v1'), null, { timeout: 8000 });   // the periodic save, no page event needed
  const draft = await G.evaluate(() => JSON.parse(localStorage.getItem('palisade.runDraft.v1')));
  assert.deepEqual([draft.claim.raid_from, draft.claim.raid_to, draft.claim.left, draft.claim.game_id], [0, 3, true, gid]);
  // the page reloads with no leave message (same tab, so the room session survives)
  await G.reload(); await G.waitForFunction(() => __pal.acct.state === 'full' && !!__pal.locker.cloud, null, { timeout: 15000 });
  await G.waitForFunction(() => __pal.claims.length === 0, null, { timeout: 10000 });
  assert.equal(claims.length, 1, 'the dropped run was claimed after the reload');
  out.drop = { from: claims[0].raid_from, to: claims[0].raid_to, left: claims[0].left, gid: claims[0].game_id === gid };
  assert.deepEqual(out.drop, { from: 0, to: 3, left: true, gid: true });
  assert.equal(await G.evaluate(() => localStorage.getItem('palisade.runDraft.v1')), null, 'draft consumed once');
  // the host saw the drop; rejoining restores the armory
  await H.waitForFunction(() => __pal.players.size === 1, null, { timeout: 15000 });
  await join(); await G.waitForFunction(() => __pal.NET.inGame && __pal.game.joinHeld != null, null, { timeout: 10000 });
  await H.waitForFunction(() => __pal.players.size === 2, null, { timeout: 5000 });
  const after = await H.evaluate(() => { const g = [...__pal.players.values()].find(p => p.id !== 'host'); return { upS: g.upS, sal: g.sal, kills: g.kills } });
  out.armory = { before, after }; assert.deepEqual(after, before, 'armory, salvage and kills restored');
  await G.waitForFunction(u => __pal.player && __pal.player.upS === u, before.upS, { timeout: 5000 });
  // a second, fresh browser session is a new player (no restore)
  // finish: the rejoin claim starts where the guest came back
  await H.evaluate(() => { const P = __pal; P.game.queue = []; for (const e of P.enemies) e.dead = true; P.game.wave = 4; P.game.phase = 'build'; P.startRaid(); P.game.queue = []; P.game.time = 800 });
  await H.waitForTimeout(700); await H.evaluate(() => { const P = __pal; P.game.queue = []; for (const e of P.enemies) e.dead = true });
  await G.waitForFunction(() => __pal.game.phase === 'over', null, { timeout: 15000 });
  await G.waitForFunction(() => __pal.claims.length === 0, null, { timeout: 30000 }); await G.waitForTimeout(300);
  assert.equal(claims.length, 2); out.rejoin = { from: claims[1].raid_from, to: claims[1].raid_to, left: claims[1].left };
  assert.ok(claims[1].raid_from >= 3 && claims[1].raid_to === 5 && !claims[1].left, JSON.stringify(out.rejoin));
  // no-account solo: a reload mid-run pays this browser's locker
  const S = await b.newPage({ viewport: { width: 900, height: 700 } }); S.on('pageerror', e => errors.push('S ' + e.message));
  await S.goto(`http://localhost:${PORT}/debug.html?debug=1`); await S.waitForFunction(() => window.__pal);
  await S.click('[data-go=solo]'); await S.click('#startBtn'); await S.waitForTimeout(500);
  const raids0 = await S.evaluate(() => __pal.locker.st.raids | 0);
  await S.evaluate(() => { const P = __pal; P.game.wave = 4; P.game.phase = 'build'; P.game.time = 300; P.saveRunDraft() });
  await S.reload(); await S.waitForFunction(() => window.__pal);
  out.solo = await S.evaluate(() => ({ raids: __pal.locker.st.raids | 0, toast: document.getElementById('toast').textContent, draft: localStorage.getItem('palisade.runDraft.v1') }));
  assert.equal(out.solo.raids - raids0, 4); assert.equal(out.solo.draft, null); assert.match(out.solo.toast, /RUN SAVED/);
  fs.mkdirSync(__dirname + '/out', { recursive: true }); fs.writeFileSync(__dirname + '/out/rejoin_drop.json', JSON.stringify({ out, errors }, null, 2));
  assert.deepEqual(errors, []); console.log(JSON.stringify(out)); console.log('errors: none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
