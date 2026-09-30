// v0.9.3.9: 3 skill points -> 1 Supply Case from the Locker. Account (mocked RPC): tap twice to spend, repeat
// purchases (no cap), too few points disables it, offline keeps points. No account: same trade on the local locker,
// persists across reload, and no-account runs now earn skill points. node sp_cases.js
const { chromium } = require('playwright'), assert = require('node:assert/strict'), fs = require('node:fs');
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined }), errors = [], out = {}, calls = [];
  let online = true, L = { owned: ['skin:std', 'hat:class', 'hat:cap', 'trail:std', 'fx:none'], eq: { skin: 'std', hat: 'class', trail: 'std', fx: 'none' }, cases: 0, bag: {}, shards: 0, prog: 0, st: {}, rev: 1, imported: true, sp: 7, sp_prog: 0, sp_total: 7, skills: {} };
  const p = await b.newPage({ viewport: { width: 390, height: 844 } }); p.on('pageerror', e => errors.push(e.message));
  await p.route('https://puvjfhwxigxjpsvdwrwf.supabase.co/**', async route => { const name = new URL(route.request().url()).pathname.split('/').pop(); calls.push(name);
    if (!online) return route.abort(); let data = {}, status = 200;
    if (name === 'buy_case_sp') { if (L.sp < 3) { status = 400; data = { code: '22023', message: 'A Supply Case takes 3 skill points' } } else { L = { ...L, sp: L.sp - 3, cases: L.cases + 1, rev: L.rev + 1 }; data = L } }
    else if (name === 'get_my_locker') data = L;
    await route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(data) }) });
  await p.goto(`http://localhost:${process.env.PORT || 8080}/debug.html?debug=1`); await p.waitForFunction(() => window.__pal);
  await p.evaluate(L => { const P = __pal; P.acct.s = { access_token: 'mock-test-only', refresh_token: 'mock', expires_at: Math.floor(Date.now() / 1000) + 3600, user: { id: '11111111-1111-4111-8111-111111111111', is_anonymous: true } }; P.acct.state = 'guest'; P.takeLocker(L); P.showPage('locker') }, L);
  const btn = () => p.locator('[data-spbuy]');
  out.label = await btn().textContent(); assert.match(out.label, /3 SKILL POINTS \(7\)/);
  await btn().click(); assert.match(await btn().textContent(), /TAP AGAIN/); assert.equal(calls.filter(c => c === 'buy_case_sp').length, 0, 'first tap only arms');
  await btn().click(); await p.waitForFunction(() => __pal.locker.cases === 1);
  await btn().click(); await btn().click(); await p.waitForFunction(() => __pal.locker.cases === 2);
  out.account = await p.evaluate(() => ({ sp: __pal.locker.sp, cases: __pal.locker.cases })); assert.deepEqual(out.account, { sp: 1, cases: 2 });
  assert.equal(await btn().isDisabled(), true, 'disabled below 3 points'); out.title = await btn().getAttribute('title'); assert.match(out.title, /You have 1 skill point/);
  // offline: points stay, message shown
  await p.evaluate(() => { __pal.locker.sp = 4; __pal.renderLocker() }); online = false; await btn().click(); await btn().click();
  await p.waitForFunction(() => /needs a connection/.test(document.getElementById('lockMsg').textContent), null, { timeout: 8000 });
  out.offline = await p.evaluate(() => ({ sp: __pal.locker.sp, cases: __pal.locker.cases })); assert.deepEqual(out.offline, { sp: 4, cases: 2 });
  await p.close();
  // no account
  const q = await b.newPage({ viewport: { width: 1280, height: 800 } }); q.on('pageerror', e => errors.push('q ' + e.message));
  await q.goto(`http://localhost:${process.env.PORT || 8080}/debug.html?debug=1`); await q.waitForFunction(() => window.__pal);
  out.earn = await q.evaluate(() => { const P = __pal; P.demo = false; P.newGame(null, '', {}); P.enterGameHook(); const sp0 = P.locker.sp | 0;
    P.game.wave = 6; P.game.phase = 'build'; P.game.time = 900; P.game.bossLog.push('butcher'); P.leaveRun(); return { gained: (P.locker.sp | 0) - sp0, total: P.locker.spTotal | 0 } });
  assert.equal(out.earn.gained, 2, 'a 6-raid run with a boss earns 1 + 1 skill points');
  await q.evaluate(() => { const P = __pal; P.locker.sp = 6; P.toMenu(); P.showPage('locker') });
  const c0 = await q.evaluate(() => __pal.locker.cases);
  await q.locator('[data-spbuy]').click(); await q.locator('[data-spbuy]').click(); await q.locator('[data-spbuy]').click(); await q.locator('[data-spbuy]').click();
  out.local = await q.evaluate(() => ({ sp: __pal.locker.sp })); out.local.cases = await q.evaluate(() => __pal.locker.cases) - c0;
  assert.deepEqual(out.local, { sp: 0, cases: 2 });
  await q.reload(); await q.waitForFunction(() => window.__pal);
  out.afterReload = await q.evaluate(() => ({ sp: __pal.locker.sp })); out.afterReload.cases = await q.evaluate(() => __pal.locker.cases) - c0;
  assert.deepEqual(out.afterReload, { sp: 0, cases: 2 });
  fs.writeFileSync(__dirname + '/out/sp_cases.json', JSON.stringify({ out, calls: [...new Set(calls)], errors }, null, 2)); assert.deepEqual(errors, []);
  console.log(JSON.stringify(out)); console.log('errors: none'); await b.close();
})().catch(e => { console.error(e); process.exit(1) });
