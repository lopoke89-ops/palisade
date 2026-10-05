// End-to-end test of the v0.8 account flows against a stand-in Supabase (same endpoints and answers).
const { chromium } = require('playwright'), { ready, quiet } = require('./lib');
const O = __dirname + '/out';
const FREE = ['skin:std', 'hat:class', 'hat:cap', 'trail:std', 'fx:none'];
const B64 = o => Buffer.from(JSON.stringify(o)).toString('base64url');
const db = { users: {}, lockers: {}, names: {}, refresh: {}, calls: [], n: 0, offline: false, failRefresh: false };
function jwt(uid) { return B64({ alg: 'HS256' }) + '.' + B64({ sub: uid, role: 'authenticated' }) + '.sig'; }
function session(uid) { const rt = 'rt' + (++db.n); db.refresh[rt] = uid; return { access_token: jwt(uid), refresh_token: rt, expires_in: 3600, expires_at: Math.floor(Date.now() / 1000) + 3600, token_type: 'bearer', user: db.users[uid] }; }
function newUser(anon) { const id = 'u' + (++db.n) + '-0000-0000'; db.users[id] = { id, is_anonymous: anon, email: '', user_metadata: {} }; db.lockers[id] = { owned: FREE.slice(), eq: { skin: 'std', hat: 'class', trail: 'std', fx: 'none' }, cases: 1, bag: {}, shards: 0, prog: 0, st: { raids: 0, wins: 0, drops: 0, endless: 0, hardWins: 0, pvp: 0, pvpWins: 0 }, imported: false, rev: 0, updated_at: '' }; return id; }
function uidOf(h) { const a = (h.authorization || '').replace('Bearer ', ''); try { return JSON.parse(Buffer.from(a.split('.')[1], 'base64url').toString()).sub; } catch (e) { return null; } }
const J = (status, body) => ({ status, contentType: 'application/json', body: JSON.stringify(body) });
function handle(method, url, h, body) {
  const u = new URL(url), p = u.pathname, uid = uidOf(h);
  db.calls.push(method + ' ' + p + (p.includes('rpc') || p.includes('token') ? '' : u.search));
  if (p === '/auth/v1/signup') { const id = newUser(true); return J(200, session(id)); }
  if (p === '/auth/v1/token') {
    if (u.searchParams.get('grant_type') === 'refresh_token') { const id = db.refresh[body.refresh_token]; if (!id || db.failRefresh) return J(400, { error_code: 'refresh_token_not_found', msg: 'Invalid Refresh Token' }); delete db.refresh[body.refresh_token]; return J(200, session(id)); }
    const id = Object.keys(db.users).find(k => db.users[k].email === body.email);
    if (!id || db.users[id].password !== body.password) return J(400, { error_code: 'invalid_credentials', msg: 'Invalid login credentials' });
    return J(200, session(id));
  }
  if (p === '/auth/v1/user' && method === 'GET') return J(200, db.users[uid]);
  if (p === '/auth/v1/user' && method === 'PUT') {
    const us = db.users[uid];
    if (body.email) { if (Object.values(db.users).some(x => x.email === body.email)) return J(422, { error_code: 'email_exists', msg: 'A user with this email address has already been registered' }); us.pending = body.email; }
    if (body.password) { if (body.password.length < 8) return J(422, { error_code: 'weak_password', msg: 'Password should be at least 8 characters.' }); us.password = body.password; }
    if (body.data) us.user_metadata = { ...us.user_metadata, ...body.data };
    return J(200, us);
  }
  if (p === '/auth/v1/recover') return J(200, {});
  if (p === '/auth/v1/logout') return { status: 204, body: '' };
  if (p === '/rest/v1/profiles') return J(200, [{ username: db.names[uid] || null }]);
  if (p.startsWith('/rest/v1/rpc/')) {
    if (!uid || !db.users[uid]) return J(401, { message: 'JWT invalid' });
    const fn = p.slice(13), L = db.lockers[uid];
    const out = () => ({ ...L });
    switch (fn) {
      case 'get_my_locker': return J(200, out());
      case 'import_local_save': {
        if (L.imported) return J(400, { code: '22023', message: 'A local save was already brought into this account' });
        const s = body.p_save; L.owned = [...new Set([...L.owned, ...s.owned])]; L.cases = Math.min(L.cases + Math.min(s.cases | 0, 50), 60); L.shards += s.shards | 0;
        for (const k in L.st) L.st[k] = Math.max(L.st[k], (s.st || {})[k] | 0); L.imported = true; L.rev++; return J(200, out());
      }
      case 'buy_case': { if (body.p_case !== 'afterglow') return J(400, { code: '22023', message: "The supply case can't be bought with shards" }); if (L.shards < 10) return J(400, { code: '22023', message: 'That takes 10 shards' }); L.shards -= 10; L.bag.afterglow = (L.bag.afterglow | 0) + 1; return J(200, out()); }
      case 'open_case_v0935': case 'open_case_v094': { if (body.p_case === 'afterglow') { if ((L.bag.afterglow | 0) < 1) return J(400, { message: 'No afterglow cases to open' }); L.bag.afterglow--; const it = { id: 'hat:ghelm', cat: 'hat', key: 'ghelm', name: 'Gold Knight Helm', rarity: 'g' }; L.owned.push(it.id); return J(200, { case: 'afterglow', item: it, dup: false, locker: out() }) } }
      case 'open_case': { if (L.cases < 1) return J(400, { code: '22023', message: 'No supply cases to open' }); L.cases--; const it = { id: 'hat:crown', cat: 'hat', key: 'crown', name: 'Crown', rarity: 'l' }; const dup = L.owned.includes(it.id); if (dup) L.shards += 20; else L.owned.push(it.id); L.rev++; return J(200, { item: it, dup, locker: out() }); }
      case 'open_cases_v0962': case 'open_cases_v0964': {   // v0.9.6.2 batch openings (one or five); the same items as the single-case calls above
        const q = body.p_quantity | 0, id = body.p_case, have = id === 'supply' ? L.cases : (L.bag[id] | 0); if (![1, 5].includes(q) || have < q) return J(400, { code: '22023', message: 'Not enough cases for this opening' });
        const results = []; for (let n = 0; n < q; n++) { if (id === 'supply') L.cases--; else L.bag[id]--;
          const item = id === 'afterglow' ? { id: 'hat:ghelm', cat: 'hat', key: 'ghelm', name: 'Gold Knight Helm', rarity: 'g' } : { id: 'hat:crown', cat: 'hat', key: 'crown', name: 'Crown', rarity: 'l' };
          const dup = L.owned.includes(item.id), shards = dup ? 20 : 0; if (dup) L.shards += shards; else L.owned.push(item.id); results.push({ item, dup, shards }) }
        L.rev++; return J(200, { operation: body.p_operation, case: id, quantity: q, results, locker: out(), retry: false }) }
      case 'craft_case': { if (L.shards < 10) return J(400, { code: '22023', message: 'Crafting a case takes 10 shards' }); L.shards -= 10; L.cases++; return J(200, out()); }
      case 'equip': { const [cat, key] = body.p_item.split(':'); if (!L.owned.includes(body.p_item)) return J(403, { code: '42501', message: "You don't own that item" }); L.eq[cat] = key; L.rev++; return J(200, out()); }
      case 'set_username': { const n = body.p_name; if (Object.entries(db.names).some(([k, v]) => k !== uid && v.toLowerCase() === n.toLowerCase())) return J(409, { code: '23505', message: 'That username is taken' }); db.names[uid] = n; return J(200, { username: n }); }
      case 'claim_match_reward': { const c = body.p; db.lastClaim = c;
        if (c.kind === 'match') { const g = c.win ? 1 : 0; if (g) L.bag.afterglow = (L.bag.afterglow | 0) + 1; return J(200, { cases_granted: g, case_id: 'afterglow', capped: false, unlocked: [], locker: out() }) } if (c.duration_s < 20) return J(400, { code: '22023', message: "That match length doesn't add up" }); L.st.raids += c.held | 0; L.st.drops += c.kills | 0; if (c.win) L.st.wins++; L.prog += c.held | 0; const e = Math.floor(L.prog / 3) + (c.win ? 1 : 0); L.prog %= 3; L.cases += e; return J(200, { cases_granted: e, capped: false, unlocked: [], locker: out() }); }
    }
  }
  return J(404, { message: 'no route ' + p });
}
(async () => {
  const b = await chromium.launch({ executablePath:process.env.CHROMIUM||undefined });
  const ctx = await b.newContext({ viewport: { width: 430, height: 900 } });
  await ctx.route('https://puvjfhwxigxjpsvdwrwf.supabase.co/**', async route => {
    const r = route.request(); if (db.offline) return route.abort('internetdisconnected');
    let body = null; try { body = r.postDataJSON(); } catch (e) { }
    await route.fulfill(handle(r.method(), r.url(), r.headers(), body));
  });
  const p = await ctx.newPage();
  const errs = []; p.on('pageerror', e => errs.push(e.message + ' @ ' + (e.stack || '').split('\n').slice(1, 4).join(' / '))); p.on('console', m => { if (m.type() === 'error' && !/Failed to load resource|ERR_INTERNET/.test(m.text())) errs.push('console ' + m.text()); });
  const URL0 = 'http://localhost:8080/debug.html?debug=1&cloud=1';
  const P = f => p.evaluate(f), log = (...a) => console.log(...a), W = ms => p.waitForTimeout(ms);
  const state = () => P(() => ({ st: __pal.acct.state, guest: __pal.acct.s && __pal.acct.s.user && __pal.acct.s.user.is_anonymous, name: __pal.acct.name, msg: __pal.acct.msg, cases: __pal.locker.cases, shards: __pal.locker.shards, owned: __pal.locker.owned.length, cloud: __pal.locker.cloud, raids: __pal.locker.st.raids, claims: __pal.claims.length, btn: document.getElementById('identityState').textContent, lede: document.getElementById('aLede').textContent.slice(0, 60), status: document.getElementById('aStatus').textContent }));

  // 1. a player with a v0.7 save on this device opens v0.8
  await p.goto('http://localhost:8080/index.html');
  await P(() => localStorage.setItem('palisade.locker.v1', JSON.stringify({ owned: ['skin:std', 'hat:class', 'hat:cap', 'trail:std', 'fx:none', 'skin:gold', 'hat:future_thing'], eq: { skin: 'gold', hat: 'class', trail: 'std', fx: 'none' }, cases: 2, shards: 3, prog: 1, st: { raids: 7, wins: 1, drops: 60, endless: 0, hardWins: 0 } })));
  await p.goto(URL0); await ready(p);
  let s = await state(); log('1 boot with old save:', JSON.stringify(s));
  const u1 = s.cloud && s.cloud.id;
  log('  server locker got the old save:', JSON.stringify({ owned: db.lockers[u1].owned.length, cases: db.lockers[u1].cases, raids: db.lockers[u1].st.raids, imported: db.lockers[u1].imported, future: db.lockers[u1].owned.includes('hat:future_thing') }));

  // 2. account page as a guest; pick a username
  await p.click('#identityButton'); await quiet(p, 120);
  await p.screenshot({ path: O + '/a_guest.png', fullPage: false });
  await p.fill('#aUser', 'x'); await p.click('#aNameBox button'); await quiet(p, 120); log('2 bad name ->', (await state()).status);
  db.names['someone'] = 'Taken_Name'; await p.fill('#aUser', 'taken_name'); await p.click('#aNameBox button'); await quiet(p, 120); log('  taken name ->', (await state()).status);
  await p.fill('#aUser', 'BigU'); await p.click('#aNameBox button'); await quiet(p, 120); s = await state(); log('  name ->', s.status, '| btn:', s.btn, '| cfg name:', await P(() => document.getElementById('mName').value));

  // 3. open a case: the server rolls it
  await P(() => __pal.showPage('locker')); await quiet(p, 120);
  await p.click('[data-open=supply]'); await p.click('#caseIntro'); await quiet(p, 120); s = await state(); log('3 open case -> cases', s.cases, 'owns crown', await P(() => __pal.locker.owned.includes('hat:crown')), 'server cases', db.lockers[u1].cases);   // v0.9.6.2: the intro waits for a tap
  await p.waitForSelector('#caseResult:not([hidden])', { timeout: 15000 }); log('  reel shows:', await P(() => document.getElementById('caseName').textContent + ' / ' + document.getElementById('caseSub').textContent));
  await p.click('#caseEquip'); await quiet(p, 120); log('  equipped on server:', db.lockers[u1].eq.hat);

  // 4. offline: cases wait, a finished run is kept and sent later
  db.offline = true;
  await p.click('[data-open=supply]', { timeout: 1500 }).catch(() => { }); await quiet(p, 120);
  log('4 offline open ->', await P(() => document.getElementById('lockMsg').textContent), '| cases still', (await state()).cases);
  await P(() => { if (!document.getElementById('caseOv').hidden) __pal.closeCaseOpening(false) });   // v0.9.6.2 keeps an unconfirmed opening on screen (and saved) until dismissed
  await P(() => __pal.showPage('solo')); await p.click('#startBtn'); await quiet(p, 120);
  await P(() => { __pal.game.time = 400; __pal.game.won = true; __pal.game.wave = 6; __pal.player.kills = 40; __pal.showOver(); });
  await quiet(p, 120); s = await state(); log('  offline run: local cases', s.cases, 'queued claims', s.claims, 'server cases', db.lockers[u1].cases);
  db.offline = false; await P(() => { __pal.acct.t = 0; window.dispatchEvent(new Event('online')); }); await quiet(p, 120);
  log('  calls since offline:', db.calls.slice(-6).join(' | '), await P(() => JSON.stringify({ busy: __pal.acct.busy, st: __pal.acct.state, t: Date.now() - __pal.acct.t, booting: __pal.acct.booting })));
  s = await state(); log('  back online: claims', s.claims, 'server cases', db.lockers[u1].cases, 'local cases', s.cases, 'claim sent', JSON.stringify(db.lastClaim));

  // 4b. afterglow with an account: buy with shards on the server, open, PvP drop result arrives from the server
  await P(() => __pal.toMenu()); await P(() => __pal.showPage('locker'));
  // v0.9.6.2: the opening started offline in step 4 was saved and comes back now; finish it like a player would
  const vis = sel => p.locator(sel).isVisible();
  const lockerResume = p.locator('#caseBoxes button', { hasText: 'RESUME OPENING' });
  if (await lockerResume.count()) { await lockerResume.first().click(); await quiet(p, 120);
    if (await vis('#caseIntro')) await p.click('#caseIntro'); await quiet(p, 120); if (await vis('#caseSkip')) await p.click('#caseSkip');
    await p.waitForSelector('#caseResult:not([hidden])', { timeout: 15000 }); await quiet(p, 120);
    if (await vis('#caseDone')) await p.click('#caseDone'); else if (await vis('#caseEquip')) await p.click('#caseEquip'); await W(300) }
  log('  resumed offline opening: server cases', db.lockers[u1].cases, 'overlay', await P(() => document.getElementById('caseOv').hidden ? 'closed' : 'open'));
  db.lockers[u1].shards = 12; await P(() => __pal.syncLocker()); await quiet(p, 120);
  await p.click('[data-buy=afterglow]'); await quiet(p, 120);
  log('4b bought on server: shards', db.lockers[u1].shards, 'bag', JSON.stringify(db.lockers[u1].bag), '| game shows', await P(() => document.querySelector('.cbox:nth-child(2) b').textContent));
  await p.click('[data-open=afterglow]'); await p.click('#caseIntro'); await p.waitForSelector('#caseResult:not([hidden])', { timeout: 15000 });
  log('   opened:', await P(() => document.getElementById('caseEye').textContent + ' -> ' + document.getElementById('caseName').textContent + ' / ' + document.getElementById('caseSub').textContent), '| owns', await P(() => __pal.locker.owned.includes('hat:ghelm')));
  await p.screenshot({ path: __dirname + '/out/c_gold.png' });
  await p.click('#caseDone');
  await P(() => { __pal.showPage('solo') }); await p.click('#startBtn'); await quiet(p, 120);
  const pv = await P(async () => { const P = __pal; P.game.pvp = 'base'; P.game.time = 300; const txt = P.pvpReward(true, 4); await new Promise(r => setTimeout(r, 900)); return { txt, bag: P.locker.bag, toast: document.getElementById('toast').textContent } });
  log('   pvp win with account:', JSON.stringify(pv), '| claim sent', JSON.stringify(db.lastClaim));
  await P(() => { __pal.game.pvp = ''; __pal.toMenu() });
  // 5. guest adds an email, confirms from the email link, sets a password
  await P(() => __pal.toMenu()); await P(() => __pal.showPage('account')); await quiet(p, 120);
  await p.fill('#aLinkMail', 'nope'); await p.click('#aLinkBox button'); await quiet(p, 120); log('5 bad email ->', (await state()).status);
  await p.fill('#aLinkMail', 'bigu@example.com'); await p.click('#aLinkBox button'); await quiet(p, 120); log('  link ->', (await state()).status);
  const us = db.users[u1]; us.email = us.pending; us.is_anonymous = false; // the user clicks the email link
  const ss = session(u1);
  await p.goto('about:blank'); await p.goto(URL0 + `#access_token=${ss.access_token}&refresh_token=${ss.refresh_token}&expires_in=3600&token_type=bearer&type=email_change`); await ready(p);
  s = await state(); log('  after link:', s.st, s.status, '| url hash gone:', await P(() => location.hash === ''), '| pw box shown:', await P(() => !document.getElementById('aPwBox').hidden), '| page:', await P(() => !document.getElementById('pg-account').hidden));
  await p.screenshot({ path: O + '/a_setpw.png' });
  await p.fill('#aPwIn', 'short'); await p.click('#aPwBox button'); await quiet(p, 120); log('  short pw ->', (await state()).status);
  await p.fill('#aPwIn', 'correct horse'); await p.click('#aPwBox button'); await quiet(p, 120); s = await state();
  log('  pw ->', s.status, '| pw box hidden:', await P(() => document.getElementById('aPwBox').hidden), '| btn:', s.btn);
  await p.screenshot({ path: O + '/a_full.png' });

  // 6. sign out -> a fresh guest; then sign back in -> locker returns
  await p.click('#aOut'); await quiet(p, 120); s = await state(); log('6 signed out:', s.st, s.guest, 'cases', s.cases, 'owned', s.owned, '|', s.status);
  await p.fill('#aInMail', 'bigu@example.com'); await p.fill('#aInPw', 'wrong pass'); await p.click('#aInBox button[type=submit]'); await quiet(p, 120); log('  wrong pw ->', (await state()).status);
  await p.fill('#aInPw', 'correct horse'); await p.click('#aInBox button[type=submit]'); await quiet(p, 120); s = await state();
  log('  signed in:', s.st, s.name, 'cases', s.cases, 'owned', s.owned, 'crown', await P(() => __pal.locker.owned.includes('hat:crown')), '|', s.status, '| guest kept:', await P(() => !!localStorage.getItem('palisade.auth.guest')));

  // 7. forgot password needs an email typed
  await p.click('#aOut'); await quiet(p, 120);
  await p.fill('#aInMail', ''); await p.click('#aForgot'); await quiet(p, 120); log('7 forgot w/o email ->', (await state()).status);
  await p.fill('#aInMail', 'bigu@example.com'); await p.click('#aForgot'); await quiet(p, 120); log('  forgot ->', (await state()).status);

  // 8. a sign-in that has ended (revoked elsewhere) falls back cleanly
  await p.fill('#aInPw', 'correct horse'); await p.click('#aInBox button[type=submit]'); await quiet(p, 120);
  db.failRefresh = true; await P(() => { __pal.acct.s.expires_at = 0; __pal.acct.t = 0; }); await P(() => __pal.syncLocker()); await quiet(p, 120);
  s = await state(); log('8 revoked:', s.st, '|', s.msg, '| cases', s.cases);
  db.failRefresh = false;
  // 9. reload keeps the sign-in

  await p.goto(URL0); await ready(p); s = await state(); log('9 reload:', s.st, s.guest, 'btn', s.btn);
  // 10. not the hosted site and no ?cloud=1: accounts stay off, local play as before
  const p2 = await ctx.newPage(); await p2.goto('http://localhost:8080/debug.html?debug=1'); await ready(p2);
  log('10 local copy:', await p2.evaluate(() => ({ st: __pal.acct.state, btnHidden: document.getElementById('identityButton').hidden })));
  log('calls:', db.calls.length, 'errors:', errs.length ? errs : 'none');
  await b.close();
})();
