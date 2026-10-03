// v0.9.6.3 server polling: the friends check runs every 15 s only while the menus are in use. A hidden tab doesn't ask,
// a match or 5 idle minutes slows it to once a minute, the open Friends panel keeps the 15 s pace, and coming back to the
// tab asks straight away. The Open Games list doesn't refresh in a hidden tab. node poll_backoff.js
const { chromium } = require('playwright'), assert = require('node:assert/strict');
const A = 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa';
const user = { id: A, email: 'a@example.invalid', is_anonymous: false, user_metadata: { pw: true } };
const L = { owned: ['skin:std', 'hat:class', 'hat:cap', 'trail:std', 'fx:none'], eq: { skin: 'std', hat: 'class', trail: 'std', fx: 'none' }, cases: 0, bag: {}, shards: 0, prog: 0, st: { raids: 0, wins: 0, drops: 0, endless: 0, hardWins: 0 } };
const token = id => Buffer.from('{}').toString('base64url') + '.' + Buffer.from(JSON.stringify({ sub: id, is_anonymous: false })).toString('base64url') + '.test';
const session = id => ({ access_token: token(id), refresh_token: 'fixture', expires_at: Math.floor(Date.now() / 1000) + 3600, user });
let social = 0, lobbies = 0;
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), errors = [], out = {};
  const ctx = await b.newContext({ viewport: { width: 1400, height: 900 } });
  await ctx.route('https://puvjfhwxigxjpsvdwrwf.supabase.co/**', async route => {
    const url = new URL(route.request().url()), path = url.pathname; let data = {};
    if (path === '/auth/v1/user') data = user;
    else if (path === '/rest/v1/profiles') data = [{ id: A, username: 'Captain', cos: 'std|class|std|none' }];
    else if (path === '/rest/v1/lobbies') { lobbies++; data = [] }
    else if (path === '/rest/v1/rpc/social_state') { social++; data = { friends: [], incoming: [], outgoing: [], notes: [], unseen: 0, is_anonymous: false } }
    else if (path === '/rest/v1/rpc/get_my_locker') data = L;
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(data) }) });
  const p = await ctx.newPage(); p.on('pageerror', e => errors.push(e.message));
  await p.addInitScript(s => localStorage.setItem('palisade.auth.v1', JSON.stringify(s)), session(A));
  await p.goto('http://localhost:8080/debug.html?debug=1&cloud=1'); await p.waitForFunction(() => __pal.acct.state === 'full', null, { timeout: 15000 });
  await p.waitForFunction(() => !!__pal.FR.timer); await p.waitForTimeout(300);
  // one tick of the 15 s timer, with "now" moved by the given offsets for the last check and the last input
  const tick = (sinceCheck, sinceInput) => p.evaluate(([c, i]) => { const F = __pal.FR, n = Date.now(); F.last = n - c; F.act = n - i; return __pal.friendsTickRun() }, [sinceCheck, sinceInput]);
  const setHidden = h => p.evaluate(h => { Object.defineProperty(document, 'hidden', { configurable: true, get: () => h }); document.dispatchEvent(new Event('visibilitychange')) }, h);
  // menus in use: every tick asks
  out.active = await tick(15000, 2000); assert.equal(out.active, true, 'menus in use: checks every 15 s');
  // idle 5+ minutes: only once a minute
  out.idle = [await tick(15000, 400000), await tick(45000, 400000), await tick(61000, 400000)]; assert.deepEqual(out.idle, [false, false, true], 'idle: once a minute');
  // the Friends panel open: full pace even when idle
  await p.evaluate(() => document.getElementById('friendsBtn').click()); out.dropIdle = await tick(15000, 400000); assert.equal(out.dropIdle, true, 'panel open keeps 15 s');
  await p.keyboard.press('Escape');
  // hidden tab: never; coming back asks at once
  await setHidden(true); out.hidden = await tick(120000, 1000); assert.equal(out.hidden, false, 'hidden tab never checks');
  const before = social; await p.evaluate(() => { __pal.FR.last = Date.now() - 30000 }); await setHidden(false); await p.waitForTimeout(400);
  out.backAsks = social - before; assert.equal(out.backAsks, 1, 'returning to the tab checks straight away');
  // in a match: once a minute
  await p.evaluate(() => { __pal.showPage('solo'); document.getElementById('startBtn').click() }); await p.waitForTimeout(500);
  out.inRun = [await tick(15000, 1000), await tick(61000, 1000)]; assert.deepEqual(out.inRun, [false, true], 'in a match: once a minute');
  await p.evaluate(() => __pal.toMenu && __pal.toMenu()); await p.waitForTimeout(300);
  // the Open Games list: refreshes on MULTIPLAYER, not in a hidden tab
  await p.evaluate(() => __pal.showPage('multi')); await p.waitForTimeout(500); const l0 = lobbies;
  await setHidden(true); await p.waitForTimeout(6800); out.lobbyHidden = lobbies - l0; assert.equal(out.lobbyHidden, 0, 'no Open Games refresh in a hidden tab');
  await setHidden(false); await p.waitForTimeout(6800); out.lobbyShown = lobbies - l0; assert.ok(out.lobbyShown >= 1, 'refreshes again when shown');
  assert.deepEqual(errors, []); console.log(JSON.stringify(out)); console.log('errors: none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
