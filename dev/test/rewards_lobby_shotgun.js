const { chromium } = require('playwright');
const B64 = o => Buffer.from(JSON.stringify(o)).toString('base64url');
const db = { users: {}, lockers: {}, lobbies: {}, n: 0, refuse: false, claims: [] };
const jwt = uid => B64({ alg: 'HS256' }) + '.' + B64({ sub: uid }) + '.s';
function newUser() { const id = 'u' + (++db.n); db.users[id] = { id, is_anonymous: true, user_metadata: {} }; db.lockers[id] = { owned: ['skin:std', 'hat:class', 'hat:cap', 'trail:std', 'fx:none'], eq: { skin: 'std', hat: 'class', trail: 'std', fx: 'none' }, cases: 1, bag: {}, shards: 0, prog: 0, st: {}, imported: false, rev: 0 }; return id }
const sess = id => ({ access_token: jwt(id), refresh_token: 'r' + id, expires_in: 3600, user: db.users[id] });
const uidOf = h => { try { return JSON.parse(Buffer.from((h.authorization || '').split('.')[1], 'base64url')).sub } catch (e) { return null } };
const J = (s, b) => ({ status: s, contentType: 'application/json', body: JSON.stringify(b) });
function handle(m, url, h, body) {
  const u = new URL(url), p = u.pathname, uid = uidOf(h);
  if (p === '/auth/v1/signup') return J(200, sess(newUser()));
  if (p === '/auth/v1/user') return J(200, db.users[uid]);
  if (p === '/rest/v1/profiles') return J(200, [{ username: null }]);
  if (p === '/rest/v1/lobbies') {
    if (m === 'GET') return J(200, Object.values(db.lobbies).filter(g => g.proto === u.searchParams.get('proto').slice(3)).map(({ host_id, proto, ...g }) => g));
    if (m === 'POST') { db.lobbies[body.host_id] = body; db.lastLobby = body; return { status: 201, body: '' } }
    if (m === 'DELETE') { delete db.lobbies[u.searchParams.get('host_id').slice(3)]; return { status: 204, body: '' } }
  }
  const L = db.lockers[uid], out = () => ({ ...L });
  if (p === '/rest/v1/rpc/get_my_locker') return J(200, out());
  if (p === '/rest/v1/rpc/claim_match_reward') {
    const c = body.p; db.claims.push(c);
    if (db.later) return J(400, { code: '22023', message: 'More play time than real time so far; this result will be saved later' });
    if (db.refuse) return J(400, { code: '22023', message: "That raid count doesn't add up" });
    L.prog += c.held | 0; const g = Math.floor(L.prog / 3) + (c.win ? 2 : 0); L.prog %= 3; L.cases += g;
    const bn = Math.min(c.bosses | 0, Math.floor(((c.held | 0) + 1) / 5)); L.bag.afterglow = (L.bag.afterglow | 0) + bn;
    return J(200, { cases_granted: g, case_id: 'supply', bonus: { case: 'afterglow', n: bn }, unlocked: [], locker: out() });
  }
  return J(404, {});
}
(async () => {
  const b = await chromium.launch({ executablePath:process.env.CHROMIUM||undefined });
  const ctx = await b.newContext({ viewport: { width: 1200, height: 800 } });
  await ctx.route('https://puvjfhwxigxjpsvdwrwf.supabase.co/**', async r => { const q = r.request(); let body = null; try { body = q.postDataJSON() } catch (e) { } await r.fulfill(handle(q.method(), q.url(), q.headers(), body)) });
  const p = await ctx.newPage(); const errs = []; p.on('pageerror', e => errs.push(e.message + ' @ ' + (e.stack || '').split('\n')[1]));
  const P = (f, a) => p.evaluate(f, a), W = ms => p.waitForTimeout(ms), log = (...a) => console.log(...a);
  await p.goto('http://localhost:8080/index.html?debug=1&cloud=1'); await W(1500); await p.mouse.move(600, 400);
  log('account:', await P(() => __pal.acct.state));
  // 1. shotgun: fast clicks vs holding
  await P(() => __pal.showPage('solo')); await p.click('[data-c=grenadier]'); await p.click('#startBtn'); await W(300);
  log('gun', await P(() => { const g = __pal.player.gun; return { dmg: g.dmg, cd: g.cd, clickCd: g.clickCd, per: g.dmg * g.pellets } }));
  const count = () => P(() => window.__sh || 0);
  await P(() => { window.__sh = 0; const pl = __pal.player; let a = pl.ammo; setInterval(() => { if (pl.ammo < a) window.__sh += a - pl.ammo; a = pl.ammo }, 4) });
  await P(() => { __pal.player.ammo = 6 }); await W(50); await P(() => { window.__sh = 0 });
  for (let k = 0; k < 5; k++) { await p.mouse.down(); await W(20); await p.mouse.up(); await W(130) }
  log('5 clicks in ~0.75 s ->', await count(), 'shots');
  await P(() => { __pal.player.ammo = 6; __pal.player.rl = 0 }); await W(1300); await P(() => { window.__sh = 0; __pal.player.ammo = 6 });
  await p.mouse.down(); await W(1600); await p.mouse.up();
  log('holding 1.6 s ->', await count(), 'shots (expect 4: at 0, 0.5, 1.0, 1.5)');
  // 2. a run with a boss: server answer replaces the text
  const r1 = await P(async () => { const P = __pal; P.game.time = 300; P.game.wave = 5; P.game.bosses = 1; P.game.won = false; P.game.phase = 'over'; P.showOver(); const t0 = document.getElementById('overLoot').textContent;
    await new Promise(r => setTimeout(r, 1500)); return { first: t0, after: document.getElementById('overLoot').textContent, locker: { cases: P.locker.cases, bag: P.locker.bag } } });
  log('run end, first text:', r1.first); log('  after server:', r1.after, JSON.stringify(r1.locker)); log('  claim sent:', JSON.stringify(db.claims.at(-1)));
  await p.screenshot({ path: __dirname + '/out/over.png' });
  // 3. refused result says so
  db.refuse = true; await P(() => __pal.toMenu()); await P(() => __pal.showPage('solo')); await p.click('#startBtn'); await W(300);
  const r2 = await P(async () => { const P = __pal; P.game.time = 90; P.game.wave = 6; P.game.won = true; P.game.phase = 'over'; P.showOver(); await new Promise(r => setTimeout(r, 1500)); return document.getElementById('overLoot').textContent });
  log('refused:', r2); db.refuse = false;
  db.later = true; await P(() => __pal.toMenu()); await P(() => __pal.showPage('solo')); await p.click('#startBtn'); await W(300); await W(21000);
  const r3 = await P(async () => { const P = __pal; P.game.time = 90; P.game.wave = 3; P.game.won = false; P.game.phase = 'over'; P.showOver(); await new Promise(r => setTimeout(r, 1500)); return { txt: document.getElementById('overLoot').textContent, queued: JSON.parse(localStorage.getItem('palisade.claims.v1') || '{}') } });
  log('deferred:', r3.txt, '| still queued:', JSON.stringify(r3.queued).length > 20); db.later = false;
  // 4. leaving a run early banks the raids held
  await P(() => __pal.toMenu()); await P(() => __pal.showPage('solo')); await p.click('#startBtn'); await W(300);
  await P(() => { const P = __pal; P.game.time = 200; P.game.wave = 4; P.game.phase = 'build'; });
  await W(21500);   // server keeps a 20 s gap between claims
  const before = db.claims.length; await P(() => __pal.toMenu()); await W(1500);
  log('left during build after raid 4:', JSON.stringify(db.claims.slice(before)), '| toast:', await P(() => document.getElementById('toast').textContent));
  // 5. open games list
  db.lobbies.x = { host_id: 'x', code: 'QW12', name: "Rook's game", mode: 'coop', length: '10', diff: 'hard', players: 3, in_game: true, proto: 'yard-8' };
  db.lobbies.y = { host_id: 'y', code: 'ZZ99', name: 'Old version', mode: 'ffa', players: 2, in_game: false, proto: 'yard-7' };
  db.lobbies.z = { host_id: 'z', code: 'FU11', name: 'Full house', mode: 'base', players: 6, in_game: true, proto: 'yard-8' };
  await P(() => __pal.showPage('multi')); await W(900);
  log('list:', await P(() => [...document.querySelectorAll('#lobList .lob')].map(b => b.textContent + (b.disabled ? ' [full]' : '')).join(' | ') || document.getElementById('lobList').textContent));
  await p.screenshot({ path: __dirname + '/out/list.png', fullPage: true });
  // hosting publishes, leaving removes it (PeerJS needs the local peer server)
  await p.goto('http://localhost:8080/index.html?debug=1&cloud=1&peerhost=127.0.0.1&peerport=9000&peerpath=/'); await W(1500);
  await P(() => __pal.showPage('multi')); await p.click('#hostBtn'); await p.waitForSelector('#pg-lobby:not([hidden])', { timeout: 10000 }); await W(800);
  log('host listed:', JSON.stringify(db.lastLobby));
  await p.click('#lLeave'); await W(600);
  log('after leaving, listed rooms:', Object.keys(db.lobbies).filter(k => !['x', 'y', 'z'].includes(k)).length);
  log('errors:', errs.length ? errs : 'none'); await b.close();
})();
